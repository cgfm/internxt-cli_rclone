#!/bin/bash

set -e

# Log directory
LOG_DIR="/config/log"

# Set RCLONE_CONFIG if not set
if [ -z "$RCLONE_CONFIG" ]; then
    RCLONE_CONFIG="/config/rclone.conf"
fi

# Check if the schedule key is provided as an argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <schedule_key>"
    exit 1
fi

WORKING_JSON="/working/rclone_cron.json"
schedule_key="$1"

# Read the JSON file and execute commands for the specified schedule key
if [ -f "$WORKING_JSON" ]; then
    # Iterate over commands in the specified schedule
    commands=$(jq -c ".cron_jobs[] | select(.schedule == \"$schedule_key\") | .commands[]" "$WORKING_JSON")

    # Process each command
    echo "$commands" | while IFS= read -r command_obj; do
        # Extract command, command flags, local_path, and remote_path
        command=$(echo "$command_obj" | jq -r '.command // empty')
        command_flags=$(echo "$command_obj" | jq -r '.command_flags // empty')
        local_path=$(echo "$command_obj" | jq -r '.local_path // empty')
        remote_path=$(echo "$command_obj" | jq -r '.remote_path // empty')

        # Prepare the final command
        final_command="$command"

        # If local path and remote path are set, include them
        if [[ -n "$local_path" && -n "$remote_path" ]]; then
            echo "$(date -u +"%Y-%m-%d %H:%M:%S"): Running command: $final_command $local_path $remote_path $command_flags" >> "/config/log/rclone.log"
            eval "$final_command $local_path $remote_path $command_flags --log-file=/config/log/rclone.log --log-format=date,time,UTC"
        elif [[ -n "$command" ]]; then
            # If only command is present, run it with flags
            echo "$(date -u +"%Y-%m-%d %H:%M:%S"): Running command: $final_command $command_flags" >> "/config/log/rclone.log"
            eval "$final_command $command_flags"
        fi
    done
else
    echo "Error: Configuration file $WORKING_JSON not found."
    exit 1
fi