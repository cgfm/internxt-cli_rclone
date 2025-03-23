#!/bin/bash

set -e

CRON_LOG_FILE="/logs/cron.log"
WORKING_JSON="/working/config.json"
LOG_MAX_LOG_SIZE="10485760"
stats_log_level="NOTICE"
log_level_cron="info"
DEBUG=false

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
    echo -e "[cron_$schedule_index]$(date '+%Y-%m-%d %H:%M:%S') $message" | tee -a "$CRON_LOG_FILE"
}

# Check if the schedule index is provided as an argument
if [ $# -eq 0 ]; then
    log_debug "error" "Wrong Usage: $0 <schedule_index> [--debug]"
    exit 1
fi

schedule_index="$1"

while [[ "$1" != "" ]]; do
    case $1 in
        --debug )        DEBUG=true
                         LOG_LEVEL="debug"
                         ;;
    esac
    shift
done


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
        log_debug "debug" "Command: $command"
        log_debug "debug" "Command Flags: $command_flags"
        log_debug "debug" "Local Path: $local_path"
        log_debug "debug" "Remote Path: $remote_path"

        # Prepare command_flags with necessary modifications (if applicable)
        command_flags=$(echo "$command_flags" | sed 's/^\(-v\|-vv\|--verbose\)\s*//; s/\s*\(-v\|-vv\|--verbose\)\s*/ /g')

        rclone_cron_log_file="/logs/rclone/rclone_$schedule_index.log"
        rclone_command_flags=" --log-file=$rclone_cron_log_file --log-level=$stats_log_level --log-format=date,time,UTC --config=$RCLONE_CONFIG --stats=1m0s --stats-log-level=INFO --stats-one-line"

        final_command=""
        logical_parts=()
        while IFS= read -r line; do
            logical_parts+=("$line")
        done < <(echo "$command" | awk -F '&&' '{ for(i=1; i<=NF; i++) print $i }')

        # Process each logical part
        for j in "${!logical_parts[@]}"; do
            part="${logical_parts[j]}"
            part="${part#"${part%%[![:space:]]*}"}"
            part="${part%"${part##*[![:space:]]}"}"

            # Split the command into two parts by the first pipe "|"
            pipe_parts=()
            IFS='|' read -ra pipe_parts <<< "$part"

            # Loop over each part and add command_flags to any rclone command part
            for i in "${!pipe_parts[@]}"; do
                pipe_part="${pipe_parts[i]}"
                pipe_part="${pipe_part#"${pipe_part%%[![:space:]]*}"}"
                pipe_part="${pipe_part%"${pipe_part##*[![:space:]]}"}"

                # Check if the current part contains 'rclone'
                if [[ "$pipe_part" == "rclone "* ]]; then
                    # Append command_flags to the rclone command part
                    pipe_parts[i]="$pipe_part $rclone_command_flags"
                else
                    pipe_parts[i]="$pipe_part"
                fi
            done

            part=""
            for i in "${!pipe_parts[@]}"; do
                if [[ $i -gt 0 ]]; then
                    part+=" | "
                fi
                part+="${pipe_parts[i]}"
            done
            logical_parts[j]="$part"
        done

        # Recombine the logical parts without losing whitespace
        command=""
        for j in "${!logical_parts[@]}"; do
            if [[ $j -gt 0 ]]; then
                command+=" && "
            fi
            command+="${logical_parts[j]}"
        done

        # append the provided flags to the command
        command+=" $command_flags"

        # If local path and remote path are set, include them
        if [[ -n "$local_path" && -n "$remote_path" ]]; then
            echo "[$(date '+%H:%M')] Schedule #$schedule_index $schedule running $command for $local_path and $remote_path" > "/tmp/cron.$schedule_index.lock"
            log_debug "notice" "Running command: $command $local_path $remote_path"
            if [ "$DEBUG" = false ]; then
                eval "$command $local_path $remote_path"
            fi
        elif [[ -n "$command" ]]; then
            # If only command is present, run it with flags
            echo "[$(date '+%H:%M')] Schedule #$schedule_index $schedule running$command" > "/tmp/cron.$schedule_index.lock"
            log_debug "notice"  "Running command: $command"
            if [ "$DEBUG" = false ]; then
                eval "$command"
            fi
        fi
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

# Remove the lock file since flock semms to sometimes didn't remove it
rm "/tmp/cron.$schedule_index.lock"