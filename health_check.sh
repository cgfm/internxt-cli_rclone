#!/bin/bash

# Function to output error messages and exit
error_exit() {
    echo "$1"
    exit 1
}

# Check if Internxt is running
if ! pgrep -f "internxt" > /dev/null; then
    error_exit "Internxt is not running."
fi

# Determine whether to use HTTP or HTTPS for rclone Web GUI
if [ -n "$RCLONE_SSL_CERT" ] && [ -n "$RCLONE_SSL_KEY" ]; then
    echo "SSL certificates provided. Checking rclone Web GUI via HTTPS..."
    WEB_GUI_URL="https://localhost:$RCLONE_WEB_GUI_PORT"
else
    echo "No SSL certificates provided. Checking rclone Web GUI via HTTP..."
    WEB_GUI_URL="http://localhost:$RCLONE_WEB_GUI_PORT"
fi

# Check if the rclone Web GUI is running and accessible
if ! curl --connect-timeout 5 -s --head --user "$RCLONE_GUI_USER:$RCLONE_GUI_PASS" "$WEB_GUI_URL" | grep -q "200 OK"; then
    error_exit "rclone Web GUI is not accessible."
fi

# Check if cron jobs are enabled and running only if CRON_SCHEDULE is not empty
if [ -n "$CRON_SCHEDULE" ]; then
    if ! pgrep cron > /dev/null; then
        error_exit "Cron service is not running."
    fi

    # Check if cron jobs are set correctly
    if ! crontab -l | grep -q "$CRON_SCHEDULE"; then
        error_exit "No cron jobs found for the specified schedule."
    fi
else
    echo "CRON_SCHEDULE is empty. Skipping cron job checks."
fi

# If all checks pass
echo "Health check passed."
exit 0
