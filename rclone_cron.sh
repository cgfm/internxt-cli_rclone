#!/bin/bash

set -e

CRON_LOG_FILE="/logs/cron.log"
WORKING_JSON="/working/config.json"
LOG_MAX_LOG_SIZE="10485760"
schedule_index="$1"
stats_log_level="NOTICE"
log_level_cron="info"

# Function to return debug messages based on the debug level
log_debug() {
    local level="$1"
    local message="$2"

    # Check if log_level_cron
    if [ "$log_level_cron" = "debug" ] && [ "$level" = "debug" ]; then
        message="[DEBUG]: $message"
    elif ([ "$log_level_cron" = "debug" ] || [ "$log_level_cron" = "info" ]) && [ "$level" = "info" ]; then
        message="[INFO]: $message"
    elif ([ "$log_level_cron" = "debug" ] || [ "$log_level_cron" = "info" ] || [ "$log_level_cron" = "notice" ])  && [ "$level" = "notice" ]; then
        message="[NOTICE]: $message"
    elif ([ "$log_level_cron" = "debug" ] || [ "$log_level_cron" = "info" ] || [ "$log_level_cron" = "notice" ] || [ "$log_level_cron" = "error" ]) && [ "$level" = "error" ]; then
        message="[ERROR]: $message"
    fi
    # Log to file
    echo -e "[cron_$schedule_index]$(date '+%Y-%m-%d %H:%M:%S') $message" | tee "$CRON_LOG_FILE"
}

if [ -f "$WORKING_JSON" ]; then
    # Extract log_level_cron
    if [ -z "$LOG_LEVEL" ]; then
        log_level_cron=$(jq -r '.settings.log.level' "$WORKING_JSON")
        log_debug "info" "Loaded log_level_cron: $log_level_cron"
        # Set stats log level for rClone stats
        stats_log_level=$(echo "$log_level_cron" | tr '[:lower:]' '[:upper:]')
    else
        log_level_cron=$LOG_LEVEL
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

# Record the start time
start_time=$(date '+%Y-%m-%d %H:%M:%S')
log_debug "info" "Starting rclone cron job for schedule index $schedule_index. Execution started at: $start_time"


# Set log_level_cron if not set
if [ -z "$log_level_cron" ] || [ "$log_level_cron" == "null" ]; then
    log_level_cron="notice"
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

    # Processing each command
    echo "$commands" | while IFS= read -r command_obj; do
        # Extract command details
        command=$(echo "$command_obj" | jq -r '.command // empty')
        command_flags=$(echo "$command_obj" | jq -r '.command_flags // empty')
        local_path=$(echo "$command_obj" | jq -r '.local_path // empty')
        remote_path=$(echo "$command_obj" | jq -r '.remote_path // empty')

        # Prepare command_flags with necessary modifications (if applicable)
        command_flags=$(echo "$command_flags" | sed 's/^\(-v\|-vv\|--verbose\)\s*//; s/\s*\(-v\|-vv\|--verbose\)\s*/ /g')

        # If the command is an rclone command
        if [[ "$command" == *rclone* ]]; then
            command_flags+=" --log-file=$RCLONE_LOG_FILE --log-level=$stats_log_level --log-format=date,time,UTC --config=$RCLONE_CONFIG --stats=1m0s --stats-log-level=INFO --stats-one-line"
        fi

        # Split the command into two parts by the first pipe "|"
        IFS='|' read -ra parts <<< "$command"
        
        # Trim any whitespace from the first part
        first_part="${parts[0]}"
        first_part=$(echo "$first_part" | xargs)  # Trim leading/trailing spaces

        # Combine the first part with command_flags
        first_part_with_flags="$first_part $command_flags"

        # Recombine back with the second part if it exists
        if [[ ${#parts[@]} -gt 1 ]]; then
            second_part="${parts[1]}"
            second_part=$(echo "$second_part" | xargs)  # Trim leading/trailing spaces
            command="$first_part_with_flags | $second_part"
        else
            # No second part, just use the first part with flags
            command="$first_part_with_flags"
        fi
        
        # If local path and remote path are set, include them
        if [[ -n "$local_path" && -n "$remote_path" ]]; then
            echo "[$(date '+%H:%M')] Schedule #$schedule_index $schedule running $command for $local_path and $remote_path" > "/tmp/cron.$schedule_index.lock"
            log_debug "notice" "Running command: $command $local_path $remote_path"
            eval "$command $local_path $remote_path"
        elif [[ -n "$command" ]]; then
            # If only command is present, run it with flags
            echo "[$(date '+%H:%M')] Schedule #$schedule_index $schedule running$command" > "/tmp/cron.$schedule_index.lock"
            log_debug "notice"  "Running command: $command"
            eval "$command"
        fi
        
        # Prepare to run or pending execution...
        echo "Prepared command: $command"
    done
else
    log_debug "error" "Configuration file $WORKING_JSON not found."
    exit 1
fi

# Record the finish time
finish_time=$(date '+%Y-%m-%d %H:%M:%S')

# Convert both date-time strings into Unix timestamps
start_timestamp=$(date -d "$start_time" +%s)
finish_timestamp=$(date -d "$finish_time" +%s)

# Calculate the time difference in seconds
time_difference=$((finish_timestamp - start_timestamp))

# Convert seconds into a human-readable format (e.g., HH:MM:SS)
hours=$((time_difference / 3600))
minutes=$(( (time_difference % 3600) / 60 ))
seconds=$((time_difference % 60))

# Display the time difference
duration=$(printf "%02d:%02d:%02d\n" $hours $minutes $seconds)

log_debug "notice" "Finished rclone cron job for schedule index $schedule_index after $duration."
log_debug "info" "Execution finished at: $finish_time"

rm "/tmp/cron.$schedule_index.lock"