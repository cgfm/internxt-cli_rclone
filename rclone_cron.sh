#!/bin/bash

set -e

RCLONE_LOG_FILE="/logs/rclone.log"
CRON_LOG_FILE="/logs/cron.log"
WORKING_JSON="/working/config.json"
schedule_index="$1"

# Function to return debug messages based on the debug level
log_debug() {
    local level="$1"
    local message="$2"

    # Check if LOG_LEVEL
    if [ "$LOG_LEVEL" = "fine" ] && [ "$level" = "fine" ]; then
        message="[FINE]: $message"
    elif ([ "$LOG_LEVEL" = "fine" ] || [ "$LOG_LEVEL" = "debug" ]) && [ "$level" = "debug" ]; then
        message="[DEBUG]: $message"
    elif ([ "$LOG_LEVEL" = "fine" ] || [ "$LOG_LEVEL" = "debug" ] || [ "$LOG_LEVEL" = "info" ])  && [ "$level" = "info" ]; then
        message="[INFO]: $message"
    elif ([ "$LOG_LEVEL" = "fine" ] || [ "$LOG_LEVEL" = "debug" ] || [ "$LOG_LEVEL" = "info" ] || [ "$LOG_LEVEL" = "error" ]) && [ "$level" = "error" ]; then
        message="[ERROR]: $message"
    fi
    # Log to file
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $message" | tee "$CRON_LOG_FILE"
}

if [ -f "$WORKING_JSON" ]; then
    # Extract log level
    LOG_LEVEL=$(jq -r '.settings.log.level' "$WORKING_JSON")
    log_debug "debug" "Loaded LOG_LEVEL: $LOG_LEVEL"
    RCLONE_CONFIG=$(jq -r '.settings.rclone.config' "$WORKING_JSON")
    log_debug "debug" "Loaded RCLONE_CONFIG: $RCLONE_CONFIG"
fi

if [ -z "$LOG_LEVEL" ] || [ "$LOG_LEVEL" == "null" ]; then
    LOG_LEVEL="info"
fi

# Set RCLONE_CONFIG if not set
if [ -z "$RCLONE_CONFIG" ] || [ "$RCLONE_CONFIG" == "null" ]; then
    RCLONE_CONFIG="/config/rclone.conf"
fi

# Check if the schedule index is provided as an argument
if [ $# -ne 1 ]; then
    log_debug "error" "Wrong Usage: $0 <schedule_index>"
    exit 1
fi

# Read the JSON file and execute commands for the specified schedule index
if [ -f "$WORKING_JSON" ]; then
    # Extract the commands for the specified schedule index
    schedule=$(jq -c ".cron_jobs[$schedule_index].schedule" "$WORKING_JSON" 2>/dev/null)
    commands=$(jq -c ".cron_jobs[$schedule_index].commands[]" "$WORKING_JSON" 2>/dev/null)
    log_debug "fine" "Commands for schedule index $schedule_index:\n$(echo "$commands" | jq --indent 2 .)"
    # Check if commands are found
    if [ -z "$commands" ]; then
        log_debug "error" "No commands found for schedule index $schedule_index."
        exit 1
    fi

    log_debug "info" "Running commands for schedule $schedule."

    # Process each command
    echo "$commands" | while IFS= read -r command_obj; do
        # Extract command, command flags, local_path, and remote_path
        command=$(echo "$command_obj" | jq -r '.command // empty')
        command_flags=$(echo "$command_obj" | jq -r '.command_flags // empty')
        local_path=$(echo "$command_obj" | jq -r '.local_path // empty')
        remote_path=$(echo "$command_obj" | jq -r '.remote_path // empty')

        if [[ "$command" == "rclone"* ]]; then
            command_flags+=" --log-file=$RCLONE_LOG_FILE --log-format=date,time,UTC --config=$RCLONE_CONFIG"
        fi

        # If local path and remote path are set, include them
        if [[ -n "$local_path" && -n "$remote_path" ]]; then
            log_debug "info" "Running command: $command $local_path $remote_path $command_flags"
            eval "$command $local_path $remote_path $command_flags"
        elif [[ -n "$command" ]]; then
            # If only command is present, run it with flags
            log_debug "info"  "Running command: $command $command_flags"
            eval "$command $command_flags"
        fi
    done
else
    log_debug "error" "Configuration file $WORKING_JSON not found."
    exit 1
fi