#!/bin/bash

# Function to output error messages and exit
error_exit() {
    echo "$1"
    exit 1
}

# Define expected environment variables and their corresponding JSON keys
declare -A env_var_map=(
    ["INTERNXT_EMAIL"]="internxt.email"
    ["INTERNXT_PASSWORD"]="internxt.password"
    ["INTERNXT_HTTPS"]="internxt.https"
    ["INTERNXT_SSL_CERT"]="internxt.ssl_cert"
    ["INTERNXT_SSL_KEY"]="internxt.ssl_key"
    ["INTERNXT_TOTP"]="internxt.totp"
    ["INTERNXT_HOST"]="internxt.host"
    ["INTERNXT_WEB_PORT"]="internxt.web_port"
    ["RCLONE_CONFIG"]="rclone.config"
    ["RCLONE_WEB_GUI_SERVE"]="rclone.webgui_serve"
    ["RCLONE_WEB_GUI_PORT"]="rclone.webgui_port"
    ["RCLONE_WEB_GUI_USER"]="rclone.webgui_user"
    ["RCLONE_WEB_GUI_PASS"]="rclone.webgui_pass"
    ["RCLONE_WEB_GUI_SSL_CERT"]="rclone.webgui_ssl_cert"
    ["RCLONE_WEB_GUI_SSL_KEY"]="rclone.webgui_ssl_key"
    ["RCLONE_WEB_GUI_EXTRA_PARAMS"]="rclone.webgui_extra_params"
    ["CRON_COMMAND"]="cron.command"
    ["CRON_COMMAND_FLAGS"]="cron.command_flags"
    ["CRON_SCHEDULE"]="cron.schedule"
    ["LOG_FILE_COUNT"]="log.file_count"
    ["LOG_LEVEL"]="log.level"
    ["ROOT_CA"]="root_ca"
    ["TZ"]="timezone"
)

# If no CONFIG_FILE is provided, check for the default location
if [ -z "$CONFIG_FILE" ] && [ -f "/config/config.json" ]; then
    CONFIG_FILE="/config/config.json"
fi

# Load the JSON file to check if the keys are defined
if [ -f "$CONFIG_FILE" ]; then
    # Iterate over the environment variable map
    for env_var in "${!env_var_map[@]}"; do
        json_key=${env_var_map[$env_var]}
        # Check if the JSON key exists in the CONFIG_FILE
        if jq -e ".settings | .${json_key} != null" "$CONFIG_FILE" > /dev/null; then
            # If the environment variable is not set, set it from the JSON value
            if [ -z "${!env_var}" ]; then
                value=$(jq -r ".settings.${json_key}" "$CONFIG_FILE")
                # Check if the value is not empty before exporting
                if [ -n "$value" ]; then
                    export "$env_var=$value"
                fi
            fi
        fi
    done
fi

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

WORKING_JSON="/working/config.json"

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
        if jq -e ".cron_jobs[$i].schedule | type == \"array\"" "$WORKING_JSON" > /dev/null; then
            schedules_array=$(jq -r ".cron_jobs[$i].schedule[]" "$WORKING_JSON")
            while IFS= read -r schedule; do
                # Check if the schedule exists in crontab
                if ! crontab -l | grep -q "$schedule"; then
                    error_exit "Cron job $i with schedule '$schedule' is not found in crontab."
                fi
            done <<< "$schedules_array"
        else
            schedule=$(jq -r ".cron_jobs[$i].schedule" "$WORKING_JSON")
        
            # Check if the schedule exists in crontab
            if ! crontab -l | grep -q "$schedule"; then
                error_exit "Cron job $i with schedule '$schedule' is not found in crontab."
            fi
        fi
    done
fi
# If all checks pass
# Initialize an empty variable to hold all contents
all_contents=""

# Loop through each file that matches the pattern and concatenate the contents
for lock_file in /tmp/cron.*.lock; do
    if [ -f "$lock_file" ]; then  # Check if the file exists
        # If contents are empty, just assign the file contents to it, otherwise concatenate with a separator
        if [ -z "$all_contents" ]; then
            all_contents=$(cat "$lock_file")  # Concatenate contents
        else
            all_contents+="; " 
            all_contents+=$(cat "$lock_file")  # Concatenate contents
        fi
    fi
done

# Output the concatenated contents (you can change this to save to a file if needed)
echo "Health check passed. $all_contents"
exit 0
