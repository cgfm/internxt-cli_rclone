#!/bin/bash

set -e

if [ "$STOPATSTART" = "true" ]; then
    tail -f /dev/null
else

# Ensure required environment variables are set
if [ -z "$INTERNXT_EMAIL" ] || [ -z "$INTERNXT_PASSWORD" ]; then
    echo "Error: INTERNXT_EMAIL and INTERNXT_PASSWORD must be set."
    exit 1
fi

# Create log directory if it doesn't exist
LOG_DIR="/config/log"
mkdir -p "$LOG_DIR"

# Determine the protocol based on the INTERNXT_HTTPS variable
if [ "$INTERNXT_HTTPS" = "true" ]; then
    PROTOCOL="https"
else
    PROTOCOL="http"
fi

# Configure rclone to use the Internxt WebDAV server
echo "Configuring rclone internxt webdav remote with $PROTOCOL..."
if rclone config create Internxt webdav \
    url="${PROTOCOL}://localhost:$INTERNXT_WEB_PORT/" \
    vendor="other" \
    user="$INTERNXT_EMAIL" \
    pass="$INTERNXT_PASSWORD" >/dev/null 2>&1; then
    echo "Successfully configured rclone internxt webdav remote."
else
    echo "Failed to configure rclone internxt webdav remote."
    exit 1
fi
# Configure rclone webgui
echo "Configuring rclone webgui..."
rclone rcd --rc-web-gui-no-open-browser \
    --rc-web-gui-update \
    --rc-no-auth \
    --rc-user ${RCLONE_GUI_USER:-rclone_user} \
    --rc-pass ${RCLONE_GUI_PASS:-rclone_password} \
    --rc-addr :$RCLONE_WEB_GUI_PORT \
    --log-file $LOG_DIR/rclone.log \
    --log-format date,time,UTC \
    ${RCLONE_CONFIG:+--config $RCLONE_CONFIG} \
    ${RCLONE_SSL_CERT:+--rc-cert $RCLONE_SSL_CERT} \
    ${RCLONE_SSL_KEY:+--rc-key $RCLONE_SSL_KEY} &
    
# Handle TOTP for two-factor authentication
if [ -n "$INTERNXT_TOTP" ]; then
    echo "Generating TOTP..."
    TOTP=$(totp "$INTERNXT_TOTP")
    echo "Logging into Internxt with TOTP..."
    internxt login --email="$INTERNXT_EMAIL" --password="$INTERNXT_PASSWORD" --twofactor="$TOTP" --non-interactive
else
    echo "Logging into Internxt without TOTP..."
    internxt login --email="$INTERNXT_EMAIL" --password="$INTERNXT_PASSWORD" --non-interactive
fi

# Enable WebDAV
echo "Enabling WebDAV..."
if [ "$INTERNXT_HTTPS" = "true" ]; then
    internxt webdav-config --https --port="$INTERNXT_WEB_PORT"
else
    internxt webdav-config --http --port="$INTERNXT_WEB_PORT"
fi
internxt webdav enable

# Check if CRON_SCHEDULE is set, default to every 15 minutes if not
if [ -z "$CRON_SCHEDULE" ]; then
    CRON_SCHEDULE="*/15 * * * *"  # Default to every 15 minutes
    echo "No CRON_SCHEDULE provided. Using default: $CRON_SCHEDULE"
else
    echo "Cron schedule is set to: $CRON_SCHEDULE"
fi

# Prepare the CRON_COMMAND
if [ -n "$CRON_COMMAND" ]; then
    echo "Using provided CRON_COMMAND: $CRON_COMMAND"
else
    CRON_COMMAND="rclone sync --create-empty-src-dirs --retries 5 --differ --verbose"
    echo "Using default command $CRON_COMMAND"
fi

full_cron_command=""

# Loop to append remote and local paths to the CRON_COMMAND
for i in {1..20}; do
    remote_var="REMOTE_PATH_$i"
    local_var="LOCAL_PATH_$i"

    if [ ! -z "${!remote_var}" ] && [ ! -z "${!local_var}" ]; then
        if [ -z "$full_cron_command" ]; then
            full_cron_command="${CRON_COMMAND} ${!remote_var} ${!local_var} --log-file=$LOG_DIR/rclone.log --log-format=date,time,UTC"
        else
            full_cron_command="${full_cron_command} && ${CRON_COMMAND} ${!remote_var} ${!local_var} --log-file=$LOG_DIR/rclone.log --log-format=date,time,UTC"
        fi
    fi
done

# Add command to user-specific crontab with flock to prevent concurrent runs
echo "$CRON_SCHEDULE root flock -n /tmp/cron.lock $full_cron_command" >> /etc/crontab
# echo "Complete cron command: $full_cron_command"

service cron start
echo "Cron service started."

# Start log monitoring for rclone and Internxt
echo " "
echo " "
echo "--------------------------------------------------"
echo "Starting log monitoring for rclone and Internxt..."
echo "--------------------------------------------------"
echo " "

RCLONE_LOG="$LOG_DIR/rclone.log"

# Monitor all Internxt log files dynamically
INTERNXT_LOG_FILES=$(find "/root/.internxt-cli/logs" -type f)
# Use tail to follow both logs
{
    tail -f "$RCLONE_LOG" &  # Run rclone log monitoring in the background
    for log_file in $INTERNXT_LOG_FILES; do
        tail -f "$log_file" &  # Run each Internxt log monitoring in the background
    done
    wait  # Wait for all background processes to finish
} | while read -r line; do
    # Enhanced logic to differentiate between rclone and internxt logs
    if echo "$line" | jq empty >/dev/null 2>&1; then
        # If the line is JSON, parse it and extract the desired fields
        timestamp=$(echo "$line" | jq -r '.timestamp')
        level=$(echo "$line" | jq -r '.level' | tr '[:lower:]' '[:upper:]')
        service=$(echo "$line" | jq -r '.service')
        message=$(echo "$line" | jq -r '.message')
        echo "[internxt] $timestamp $level $service $message"
    else
        # If the line is not JSON, it is from rclone
        echo "[rclone] $line"
    fi
done &
