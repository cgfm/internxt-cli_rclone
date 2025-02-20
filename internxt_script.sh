#!/bin/bash

set -e

rclone_logging_options="-v --log-file /config/log/rclone.log --log-format date,time,UTC"

# Ensure required environment variables are set
if [ -z "$INTERNXT_EMAIL" ] || [ -z "$INTERNXT_PASSWORD" ]; then
    echo "Error: INTERNXT_EMAIL and INTERNXT_PASSWORD must be set."
    exit 1
fi

# Configure rclone to use the Internxt WebDAV server
echo "Configuring rclone internxt webdav remote..."
rclone config create internxt webdav \
    url="http://localhost:$INTERNXT_WEB_PORT/" \
    vendor="other" \
    user="$INTERNXT_EMAIL" \
    pass="$INTERNXT_PASSWORD"

echo "Configuring rclone webgui..."
rclone rcd --rc-web-gui \
    --rc-user="${RCLONE_GUI_USER:-rclone_user}" \
    --rc-pass="${RCLONE_GUI_PASS:-rclone_password}" \
    --rc-addr="0.0.0.0:$RCLONE_WEB_GUI_PORT" \
    "${rclone_logging_options}" \
    ${RCLONE_CONFIG:+--config="$RCLONE_CONFIG"} \
    ${RCLONE_SSL_CERT:+--rc-cert="$RCLONE_SSL_CERT"} \
    ${RCLONE_SSL_KEY:+--rc-key="$RCLONE_SSL_KEY"} &

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
# Configure HTTPS if required
if [ "$INTERNXT_HTTPS" = "true" ]; then
    internxt webdav-config --https --port="$INTERNXT_WEB_PORT"
else
    internxt webdav-config --http --port="$INTERNXT_WEB_PORT"
fi

# Enable WebDAV
internxt webdav enable

# Check if CRON_SCHEDULE is set
if [ -n "$CRON_SCHEDULE" ]; then
    echo "Cron schedule is set to: $CRON_SCHEDULE"

    # Prepare the CRON_COMMAND
    if [ -n "$CRON_COMMAND" ]; then
        echo "Using provided CRON_COMMAND: $CRON_COMMAND"
    else
        echo "No CRON_COMMAND provided. Using default rclone sync command."
        CRON_COMMAND="rclone sync --create-empty-src-dirs --retries 5 --differ --verbose"
    fi

    full_cron_command = ""

    # Loop to append remote and local paths to the CRON_COMMAND
    for i in {1..20}; do
        remote_var="REMOTE_PATH_$i"
        local_var="LOCAL_PATH_$i"

        if [ ! -z "${!remote_var}" ] && [ ! -z "${!local_var}" ]; then
            full_cron_command="${full_cron_command} && ${CRON_COMMAND} ${rclone_logging_options} ${!remote_var} ${!local_var}"
        fi
    done

    # Add command to user-specific crontab with flock to prevent concurrent runs
    echo "$CRON_SCHEDULE root flock -n /tmp/cron.lock $full_cron_command" >> /etc/crontab

    echo "Complete cron command: $full_cron_command"

    service cron start
    echo "Cron service started."
else
    echo "No CRON_SCHEDULE provided. No cron jobs will be set and cron service not started."
fi

# Start WebDAV status monitoring, allowing for long-running commands
echo "Starting log monitoring for rclone and Internxt..."
RCLONE_LOG="/config/log/rclone.log"
INTERNXT_LOG_DIR=$(internxt logs | grep -oP '(?<=Logs directory: ).*')

# Monitor all Internxt log files dynamically
INTERNXT_LOG_FILES=$(find "$INTERNXT_LOG_DIR" -type f)

# Use tail to follow both logs
{
    tail -f "$RCLONE_LOG" &  # Run rclone log monitoring in the background
    for log_file in $INTERNXT_LOG_FILES; do
        tail -f "$log_file" &  # Run each internxt log monitoring in the background
    done
    wait  # Wait for all background processes to finish
} | while read -r line; do
    # Check if the line is coming from the Rclone log
    if [[ "$line" == *"rclone"* ]]; then
        echo "[rclone] $line"
    else
        # If it's from an Internxt log file
        echo "[intnxt] $line"
    fi
done
