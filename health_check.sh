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
    if [ -n "$RCLONE_WEB_GUI_SSL_CERT" ] && [ -n "$RCLONE_WEB_GUI_SSL_KEY" ]; then
        WEB_GUI_URL="https://0.0.0.0:$RCLONE_WEB_GUI_PORT"
    else
        WEB_GUI_URL="http://0.0.0.0:$RCLONE_WEB_GUI_PORT"
    fi

    # Check if the rclone Web GUI is running and accessible if both user and pass are set check with credentials 
    if [ -n "$RCLONE_WEB_GUI_USER" ] && [ -n "$RCLONE_WEB_GUI_PASS" ]; then
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --insecure --connect-timeout 5 --head --user "$RCLONE_WEB_GUI_USER:$RCLONE_WEB_GUI_PASS" "$WEB_GUI_URL")
    else
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --insecure --connect-timeout 5 --head "$WEB_GUI_URL")
    fi

    # Check the response code
    if [ "$RESPONSE" -ne 200 ]; then
        error_exit "rclone Web GUI is not accessible. Response: $RESPONSE"
    fi
fi

WORKING_JSON="/working/rclone_cron.json"

# Check if the WORKING_JSON file exists
if [ ! -f "$WORKING_JSON" ]; then
    error_exit "Working JSON configuration file '$WORKING_JSON' does not exist."
fi

# Check the number of cron jobs defined in the JSON file
total_jobs=$(jq '.cron_jobs | length' "$WORKING_JSON")

# If there are cron jobs defined in the JSON file, proceed with the checks
if [ "$total_jobs" -gt 0 ]; then

    # Check if the cron service is running
    if ! pgrep cron > /dev/null; then
        error_exit "Cron service is not running."
    fi

    # Verify that the cron jobs are registered in crontab
    for ((i=0; i<total_jobs; i++)); do
        # Extract the schedule for the current job
        schedule=$(jq -r ".cron_jobs[$i].schedule" "$WORKING_JSON")
        
        # Check if the schedule exists in crontab
        if ! crontab -l | grep -q "$schedule"; then
            error_exit "Cron job $i with schedule '$schedule' is not found in crontab."
        fi
    done
fi
# If all checks pass
echo "Health check passed."
exit 0
