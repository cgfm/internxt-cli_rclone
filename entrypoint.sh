#!/bin/bash

set -e

if [ "$STOPATSTART" = "true" ]; then
    echo "STOPATSTART mode is enabled."
    tail -f /dev/null
fi

# Ensure required environment variables are set
if [ -z "$INTERNXT_EMAIL" ] || [ -z "$INTERNXT_PASSWORD" ]; then
    echo "Error: INTERNXT_EMAIL and INTERNXT_PASSWORD must be set."
    exit 1
fi

# Check if the new certificate file exists
if [[ -f "$ROOT_CA" ]]; then
    # Append the new CA certificate to the ca-certificates.crt file
    cat "$ROOT_CA" >> "/etc/ssl/certs/ca-certificates.crt"
    echo "Successfully appended $ROOT_CA to /etc/ssl/certs/ca-certificates.crt"
else
    echo "Error: $ROOT_CA does not exist."
fi

# Create log directory if it doesn't exist
LOG_DIR="/config/log"
mkdir -p "$LOG_DIR"

# Set RCLONE_CONFIG if not set
if [ -z "$RCLONE_CONFIG" ]; then
    RCLONE_CONFIG = "/config/rclone.conf"
fi

# Determine the protocol based on the INTERNXT_HTTPS variable
if [ "$INTERNXT_HTTPS" = "true" ]; then
    PROTOCOL="https"
else
    PROTOCOL="http"
fi

# Function to rotate rClone logs
rotate_logs() {
    if [ "$RCLONE_KEEP_LOGFILES" != "true" ]; then
        LOCAL_LOG_FILES=("$LOG_DIR/rclone.log")
        if [ -n "$RCLONE_LOGFILE_COUNT" ]; then
            MAX_LOG_FILES="$RCLONE_LOGFILE_COUNT"
        else
            MAX_LOG_FILES=3  # Default log file count
        fi

        # Rotate logs
        for ((i=MAX_LOG_FILES; i>0; i--)); do
            if [ $i -eq $MAX_LOG_FILES ]; then
                # Rename the current log to log.1
                mv "$LOG_DIR/rclone.log" "$LOG_DIR/rclone.log.$i" 2>/dev/null || true
            else
                # Rename older logs
                mv "$LOG_DIR/rclone.log.$i" "$LOG_DIR/rclone.log.$((i+1))" 2>/dev/null || true
            fi
        done
        touch $LOG_DIR/rclone.log
    fi
}

# Call the log rotation function
rotate_logs

# Configure rclone to use the Internxt WebDAV server
echo "Configuring rclone internxt webdav remote with $PROTOCOL..."
if rclone config create Internxt webdav \
    url "${PROTOCOL}://${INTERNXT_HOST:-0.0.0.0}:$INTERNXT_WEB_PORT/" \
    vendor "other" \
    user "$INTERNXT_EMAIL" \
    pass "$INTERNXT_PASSWORD" \
    --config "${RCLONE_CONFIG}" >/dev/null 2>&1; then
    echo "Successfully configured rclone internxt webdav remote."
    
    if [ "$DEBUG" = "true" ]; then
        echo "Rclone config:"
        cat $RCLONE_CONFIG
    fi
else
    echo "Failed to configure rclone internxt webdav remote."
    exit 1
fi

# Configure rclone webgui only if RCLONE_WEB_GUI is true
if [ "${RCLONE_WEB_GUI_SERVE:-true}" = "true" ]; then
    echo "Configuring rclone webgui..."
    
    rclone_command="rclone rcd"

    # Add --rc-user and --rc-pass only if both are set
    if [ -n "$RCLONE_WEB_GUI_SSL_CERT" ] && [ -n "$RCLONE_WEB_GUI_SSL_KEY" ]; then
        rclone_command+=" --rc-cert $RCLONE_WEB_GUI_SSL_CERT --rc-key $RCLONE_WEB_GUI_SSL_KEY"
    fi

    # Add --rc-user and --rc-pass only if both are set
    if [ -n "$RCLONE_WEB_GUI_USER" ] && [ -n "$RCLONE_WEB_GUI_PASS" ]; then
        rclone_command+=" --rc-user $RCLONE_WEB_GUI_USER --rc-pass $RCLONE_WEB_GUI_PASS"
    else
        rclone_command+=" --rc-no-auth"
    fi

    rclone_command+=" --rc-web-gui \
        --rc-web-gui-no-open-browser \
        --rc-web-gui-update \
        --rc-addr :$RCLONE_WEB_GUI_PORT \
        --config $RCLONE_CONFIG \
        --log-file $LOG_DIR/rclone.log \
        --log-format date,time,UTC \
        $RCLONE_WEB_GUI_EXTRA_PARAMS"
    if [ "$DEBUG" = "true" ]; then
        echo "Starting rclone with command:"
        echo $rclone_command
    fi
    eval "$rclone_command &"
fi

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

# Write the WebDAV configuration to the config file
WEBDAV_CONFIG_PATH="$HOME/.internxt-cli/config.webdav.inxt"

if [ "$DEBUG" = "true" ]; then
    echo "Writing WebDAV configuration to $WEBDAV_CONFIG_PATH..."
fi
mkdir -p "$(dirname "$WEBDAV_CONFIG_PATH")"  # Ensure the directory exists

# Create JSON configuration
if [ "$INTERNXT_HTTPS" = "true" ]; then
    echo "{\"port\":\"$INTERNXT_WEB_PORT\",\"protocol\":\"https\"}" > "$WEBDAV_CONFIG_PATH"
else
    echo "{\"port\":\"$INTERNXT_WEB_PORT\",\"protocol\":\"http\"}" > "$WEBDAV_CONFIG_PATH"
fi


if [ "$DEBUG" = "true" ]; then
    echo "WebDAV configuration written successfully."
fi

# Enable WebDAV
echo "Enabling WebDAV..."
internxt webdav enable

# Check if CRON_SCHEDULE is set, default to every 15 minutes if not
if [ -z "$CRON_SCHEDULE" ]; then
    CRON_SCHEDULE="*/15 * * * *"  # Default to every 15 minutes
    echo "No CRON_SCHEDULE provided. Using default: $CRON_SCHEDULE"
else
    echo "Cron schedule is set to: $CRON_SCHEDULE"
fi

# Create a working copy of the YAML configuration if RCLON_CRON_CONF is set
WORKING_YAML="/working/rclone_cron.yaml"
mkdir -p /working

if [ -n "$RCLON_CRON_CONF" ]; then
    # Remove existing copy if it exists
    [ -f "$WORKING_YAML" ] && rm "$WORKING_YAML"

    # Create a copy of the given YAML configuration
    cp "$RCLON_CRON_CONF" "$WORKING_YAML"
else
    touch "$WORKING_YAML"
fi

# Add the environment variables to the YAML file
for i in {1..20}; do
    command_var="CRON_COMMAND_$i"
    command="${!command_var:-$CRON_COMMAND}"
    command_flags_var="CRON_COMMAND_FLAGS_$i"
    command_flags="${!command_flags_var:-$COMMAND_FLAGS}"
    local_path_var="LOCAL_PATH_$i"
    local_path="${!local_path_var}"
    remote_path_var="REMOTE_PATH_$i"
    remote_path="${!remote_path_var}"
    schedule_var="CRON_SCHEDULE_$i"
    schedule="${!schedule_var:-$CRON_SCHEDULE}"
    
    if [ ! -z "${!local_path_var}" ] && [ ! -z "${!remote_path_var}" ]; then
        yq e -i ".${schedule} += [{command: \"${command}\", command_flags: \"${command_flags}\", local_path: \"${local_path}\", remote_path: \"${remote_path}\"}]" "$WORKING_YAML"
    else
        yq e -i ".${schedule} += [{command: \"${command}\", command_flags: \"${command_flags}\"}]" "$WORKING_YAML"
    fi
done

# Start cron jobs based on the schedules in the YAML file
if [ -n "$CRON_SCHEDULE" ]; then
    # Initialize crontab if it doesn't exist
    touch /var/spool/cron/root
    if [ -f "$WORKING_YAML" ]; then
        # Iterate over each top-level key (cron schedule) in the YAML file
        for schedule in $(yq e 'keys | .[]' "$WORKING_YAML"); do
            # Register the cron job in crontab
            echo "$schedule root flock -n /tmp/cron.lock /usr/local/bin/rclone_cron.sh \"$schedule\"" >> /var/spool/cron/root
        done
    fi
    /usr/bin/crontab /var/spool/cron/root
    service cron start
    echo "Cron service started."
fi

# Start log monitoring for rclone and Internxt
echo "--------------------------------------------------"
echo "Starting log monitoring for rclone and Internxt..."
echo "--------------------------------------------------"

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
done

# Wait indefinitely to keep the script running
wait
