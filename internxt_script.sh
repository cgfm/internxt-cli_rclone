#!/bin/bash

set -e

# Ensure required environment variables are set
if [ -z "$INTERNXT_EMAIL" ] || [ -z "$INTERNXT_PASSWORD" ]; then
    echo "Error: INTERNXT_EMAIL and INTERNXT_PASSWORD must be set."
    exit 1
fi

# Check if the rclone config file exists
if [ ! -f "$RCLONE_CONFIG" ]; then
    echo "Warning: rclone config file not found at $RCLONE_CONFIG. Ignoring rclone configuration."
else
    # Configure rclone to use the Internxt WebDAV server
    echo "Configuring rclone remote..."
    rclone config create internxt webdav \
        url="http://localhost:$INTERNXT_WEB_PORT/" \
        vendor="other" \
        user="$INTERNXT_EMAIL" \
        pass="$INTERNXT_PASSWORD"

    # Start rclone Web GUI using provided environment variables for authentication
    echo "Starting rclone Web GUI..."
    rclone rcd --rc-web-gui --rc-web-gui-auth="basic" \
        --rc-user="${RCLONE_GUI_USER:-rclone_user}" \
        --rc-pass="${RCLONE_GUI_PASS:-rclone_password}" \
        --rc-addr="0.0.0.0:$RCLONE_WEB_GUI_PORT" \
        --config="$RCLONE_CONFIG" \
        --no-auth \
        ${RCLONE_SSL_CERT:+--rc-cert="$RCLONE_SSL_CERT"} \
        ${RCLONE_SSL_KEY:+--rc-key="$RCLONE_SSL_KEY"} &
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

# Enable WebDAV
echo "Enabling WebDAV..."
internxt webdav-config --port="$INTERNXT_WEB_PORT"

# Configure HTTPS if required
if [ "$INTERNXT_HTTPS" = "true" ]; then
    if [ -z "$INTERNXT_SSL_CERT" ] || [ -z "$INTERNXT_SSL_KEY" ]; then
        echo "Warning: INTERNXT_SSL_CERT and INTERNXT_SSL_KEY should be set for HTTPS."
    fi
    internxt webdav-config --https
else
    internxt webdav-config --http
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

    # Loop to append remote and local paths to the CRON_COMMAND
    for i in {1..20}; do
        remote_var="REMOTE_PATH_$i"
        local_var="LOCAL_PATH_$i"
        
        if [ ! -z "${!local_var}" ] && [ ! -z "${!remote_var}" ]; then
            CRON_COMMAND="${CRON_COMMAND} ${!local_var} ${!remote_var}"
        fi
    done
    
    # Add command to crontab
    echo "$CRON_SCHEDULE root flock -n /tmp/cron.lock $CRON_COMMAND" >> /etc/crontab
else
    echo "No CRON_SCHEDULE provided. No cron jobs will be set."
fi

# Start the cron service
service cron start
echo "Cron service started."