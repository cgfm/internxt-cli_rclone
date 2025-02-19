#!/bin/bash

# Check if Internxt is running
if ! pgrep -f "internxt" > /dev/null; then
    echo "Internxt is not running."
    exit 1
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
if ! curl -s --head --user "$RCLONE_GUI_USER:$RCLONE_GUI_PASS" "$WEB_GUI_URL" | grep "200 OK" > /dev/null; then
    echo "rclone Web GUI is not accessible."
    exit 1
fi

# Check if cron jobs are enabled and running
if ! pgrep cron > /dev/null; then
    echo "Cron service is not running."
    exit 1
fi

# Check if cron jobs are set correctly
if ! crontab -l | grep -q "$CRON_SCHEDULE"; then
    echo "No cron jobs found for the specified schedule."
    exit 1
fi

# If all checks pass
echo "Health check passed."
exit 0
