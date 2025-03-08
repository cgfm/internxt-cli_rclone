#!/bin/bash

set -e

# Log directory
LOG_DIR="/config/log"

# Set RCLONE_CONFIG if not set
if [ -z "$RCLONE_CONFIG" ]; then
    RCLONE_CONFIG="/config/rclone.conf"
fi

# Set RCLONE_COMMAND_FLAGS if not set
if [ -z "$CRON_COMMAND_FLAGS" ]; then
    CRON_COMMAND_FLAGS="--create-empty-src-dirs --retries 5 --verbose --config ${RCLONE_CONFIG}"
fi

# Check if the schedule key is provided as an argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <schedule_key>"
    exit 1
fi

WORKING_YAML="/working/rclone_cron.yaml"
schedule_key="$1"

# Read the YAML file and execute commands for the specified schedule key
if [ -f "$WORKING_YAML" ]; then
    # Iterate over commands in the specified schedule
    commands=$(yq e ".cron_jobs[] | select(.schedule == \"$schedule_key\") | .commands[]" "$WORKING_YAML")

    # Process each command
    echo "$commands" | while IFS= read -r command_obj; do
        # Extract command, command flags, local_path, and remote_path
        command=$(echo "$command_obj" | yq e '.command // empty' -)
        command_flags=$(echo "$command_obj" | yq e '.command_flags // empty' -)
        local_path=$(echo "$command_obj" | yq e '.local_path // empty' -)
        remote_path=$(echo "$command_obj" | yq e '.remote_path // empty' -)

        # Prepare the final command
        final_command="$command"

        # If local path and remote path are set, include them
        if [[ -n "$local_path" && -n "$remote_path" ]]; then
            echo "$(date -u +"%Y-%m-%d %H:%M:%S"): Running command: $final_command $local_path $remote_path $command_flags" >> "$LOG_DIR/rclone.log"
            eval "$final_command $local_path $remote_path $command_flags --log-file=$LOG_DIR/rclone.log --log-format=date,time,UTC"
        elif [[ -n "$command" ]]; then
            # If only command is present, run it with flags
            echo "$(date -u +"%Y-%m-%d %H:%M:%S"): Running command: $final_command $command_flags" >> "$LOG_DIR/rclone.log"
            eval "$final_command $command_flags"
        fi
    done
else
    echo "Error: Configuration file $WORKING_YAML not found."
    exit 1
fi