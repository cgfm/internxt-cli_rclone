#!/bin/bash

# Function to output error messages and exit
error_exit() {
    echo "$1"
    exit 1
}

# Check the status of the Internxt WebDAV server
WEBDAV_STATUS=$(internxt webdav status)

# Verify if the WebDAV server is online
if [[ "$WEBDAV_STATUS" != *"online"* ]]; then
    error_exit "Internxt WebDAV server is not running. Status: $WEBDAV_STATUS"
fi

# check rClone webgui if it should be served 
if [ "${RCLONE_WEB_GUI_SERVE:-true}" = "true" ]; then
   
    # Determine whether to use HTTP or HTTPS for rclone Web GUI
    if [ -n "$RCLONE_SSL_CERT" ] && [ -n "$RCLONE_SSL_KEY" ]; then
        WEB_GUI_URL="https://localhost:$RCLONE_WEB_GUI_PORT"
    else
        WEB_GUI_URL="http://localhost:$RCLONE_WEB_GUI_PORT"
    fi

    # Check if the rclone Web GUI is running and accessible if both user and pass are set check with credentials 
    if [ -n "$RCLONE_WEB_GUI_USER" ] && [ -n "$RCLONE_WEB_GUI_PASS" ]; then
        if ! curl --connect-timeout 5 -s --head --user "$RCLONE_GUI_USER:$RCLONE_GUI_PASS" "$WEB_GUI_URL" | grep -q "200 OK"; then
            error_exit "rclone Web GUI is not accessible."
        fi
    else
        if ! curl --connect-timeout 5 -s --head "$WEB_GUI_URL" | grep -q "200 OK"; then
            error_exit "rclone Web GUI is not accessible."
        fi
    fi
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
fi

# If all checks pass
echo "Health check passed."
exit 0
