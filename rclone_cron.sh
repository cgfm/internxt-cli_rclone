#!/bin/bash

set -e

RCLONE_LOG_FILE="/logs/rclone.log"
CRON_LOG_FILE="/logs/cron.log"
WORKING_JSON="/working/config.json"
LOG_MAX_LOG_SIZE="10485760"
schedule_index="$1"
stats_log_level="NOTICE"

# Function to return debug messages based on the debug level
log_debug() {
    local level="$1"
    local message="$2"

    # Check if LOG_LEVEL
    if [ "$LOG_LEVEL" = "debug" ] && [ "$level" = "debug" ]; then
        message="[FINE]: $message"
    elif ([ "$LOG_LEVEL" = "debug" ] || [ "$LOG_LEVEL" = "info" ]) && [ "$level" = "info" ]; then
        message="[DEBUG]: $message"
    elif ([ "$LOG_LEVEL" = "debug" ] || [ "$LOG_LEVEL" = "info" ] || [ "$LOG_LEVEL" = "notice" ])  && [ "$level" = "notice" ]; then
        message="[NOTICE]: $message"
    elif ([ "$LOG_LEVEL" = "debug" ] || [ "$LOG_LEVEL" = "info" ] || [ "$LOG_LEVEL" = "notice" ] || [ "$LOG_LEVEL" = "error" ]) && [ "$level" = "error" ]; then
        message="[ERROR]: $message"
    fi
    # Log to file
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $message" | tee "$CRON_LOG_FILE"
}

if [ -f "$WORKING_JSON" ]; then
    # Extract LOG_LEVEL
    if [ -z "$LOG_LEVEL" ]; then
        LOG_LEVEL=$(jq -r '.settings.log.level' "$WORKING_JSON")
        log_debug "info" "Loaded LOG_LEVEL: $LOG_LEVEL"
        # Set stats log level for rClone stats
        stats_log_level=$(echo "$LOG_LEVEL" | tr '[:lower:]' '[:upper:]')
    fi
    
    # Extract RCLONE_CONFIG
    if [ -z "$RCLONE_CONFIG" ]; then
        RCLONE_CONFIG=$(jq -r '.settings.rclone.config' "$WORKING_JSON")
        log_debug "info" "Loaded RCLONE_CONFIG: $RCLONE_CONFIG"
    fi

    if [ -z "$LOG_MAX_LOG_SIZE" ]; then
        LOG_MAX_LOG_SIZE=$(jq -r '.settings.log.max_log_size' "$WORKING_JSON")
        log_debug "info" "Loaded LOG_MAX_LOG_SIZE: $LOG_MAX_LOG_SIZE"
    fi
fi

# Set LOG_LEVEL if not set
if [ -z "$LOG_LEVEL" ] || [ "$LOG_LEVEL" == "null" ]; then
    LOG_LEVEL="notice"
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
    log_debug "debug" "Commands for schedule index $schedule_index:\n$(echo "$commands" | jq --indent 2 .)"
    # Check if commands are found
    if [ -z "$commands" ]; then
        log_debug "error" "No commands found for schedule index $schedule_index."
        exit 1
    fi

    log_debug "notice" "Running commands for schedule $schedule."

    # Process each command
    echo "$commands" | while IFS= read -r command_obj; do
        # Extract command, command flags, local_path, and remote_path
        command=$(echo "$command_obj" | jq -r '.command // empty')
        command_flags=$(echo "$command_obj" | jq -r '.command_flags // empty')
        local_path=$(echo "$command_obj" | jq -r '.local_path // empty')
        remote_path=$(echo "$command_obj" | jq -r '.remote_path // empty')

        # Assuming command_flags is already defined earlier in your script
        # Remove -v and --verbose from the beginning or with leading space
        command_flags=$(echo "$command_flags" | sed 's/^\(-v\|-vv\|--verbose\)\s*//; s/\s*\(-v\|-vv\|--verbose\)\s*/ /g')

        # Trim any extra spaces that may have been left after removals
        command_flags=$(echo "$command_flags" | sed 's/^\s*//; s/\s*$//')

        if [[ "$command" == "rclone"* ]]; then
            command_flags+=" --log-file=$RCLONE_LOG_FILE --log-level=$stats_log_level --log-format=date,time,UTC --config=$RCLONE_CONFIG --stats=1m0s --stats-log-level=INFO --stats-one-line"
        fi

        # If local path and remote path are set, include them
        if [[ -n "$local_path" && -n "$remote_path" ]]; then
            log_debug "notice" "Running command: $command $local_path $remote_path $command_flags"
            eval "$command $local_path $remote_path $command_flags"
        elif [[ -n "$command" ]]; then
            # If only command is present, run it with flags
            log_debug "notice"  "Running command: $command $command_flags"
            eval "$command $command_flags"
        fi
    done
else
    log_debug "error" "Configuration file $WORKING_JSON not found."
    exit 1
fi