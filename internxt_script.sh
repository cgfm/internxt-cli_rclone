#!/bin/bash

set -e

# Set default config directory
INTERNXT_CONFIG_DIR="/config"
RCLONE_CONFIG_FILE="$RCLONE_CONFIG"

# Ensure required environment variables are set
if [ -z "$INTERNXT_EMAIL" ] || [ -z "$INTERNXT_PASSWORD" ]; then
    echo "Error: INTERNXT_EMAIL and INTERNXT_PASSWORD must be set."
    exit 1
fi

# Check if the rclone config file exists
if [ ! -f "$RCLONE_CONFIG_FILE" ]; then
    echo "Warning: rclone config file not found at $RCLONE_CONFIG_FILE. Ignoring rclone configuration."
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
        --config="$RCLONE_CONFIG_FILE" \
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
internxt webdav-config --port="$INTERNXT_WEB_PORT" --config-dir="$INTERNXT_CONFIG_DIR"

# Configure HTTPS if required
if [ "$INTERNXT_HTTPS" = "true" ]; then
    if [ -z "$INTERNXT_SSL_CERT" ] || [ -z "$INTERNXT_SSL_KEY" ]; then
        echo "Error: INTERNXT_SSL_CERT and INTERNXT_SSL_KEY must be set for HTTPS."
        exit 1
    fi
    internxt webdav-config --https --ssl-cert="$INTERNXT_SSL_CERT" --ssl-key="$INTERNXT_SSL_KEY"
else
    internxt webdav-config --http
fi

# Enable WebDAV
internxt webdav enable

# Set default cron schedule if not specified
CRON_SCHEDULE="${CRON_SCHEDULE:-*/15 * * * *}"  # Default to every 15 minutes

# Set up cron job if CRON_COMMAND is specified
if [ -n "$CRON_COMMAND" ]; then
    echo "Setting up cron job..."
    echo "$CRON_SCHEDULE root flock -n /tmp/cron.lock $CRON_COMMAND" >> /etc/crontab
    # Start the cron service
    service cron start
    echo "Cron service started."
fi

# Function to run the CRON_COMMAND directly for the health check
run_cron_command() {
    echo "Running cron command with lock..."
    {
        flock -n 200 || { echo "Cron command is already running"; exit 1; }
        eval "$CRON_COMMAND"
    } 200>/tmp/cron.lock
}

# Start WebDAV status monitoring, allowing for long-running commands
echo "Starting WebDAV status monitoring..."
while true; do
    internxt --version
    internxt webdav status
    sleep 600  # Wait for 10 minutes (600 seconds) before checking again
done
