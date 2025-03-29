#!/bin/bash

set -e

# Additional flags for rclone
additional_flags="--log-file /path/to/logfile.log --log-format date,time,UTC"  # Adjust this variable as needed

# Input commands
commands=(
    "rm -f /data/src_audiobooks && rclone lsf --files-only -R /media/audiobookshelf/audiobooks | sort > /data/src_audiobooks"
    "[ ! -f /data/dst_audiobooks ] || [ ! -s /data/dst_audiobooks ] && rclone lsf --files-only -R Internxt:Audiobooks | sort > /data/dst_audiobooks"
    "comm -23 /data/src_audiobooks /data/dst_audiobooks > /data/need-to-transfer"
)

# Iterating over each command
for command in "${commands[@]}"; do
    updated_command=""
    original_delimiters=""
    
    # Split the command into parts by the delimiters "&&", "||", "|", retaining the delimiters
    while [[ "$command" =~ ^(.*?)(&&|\|\||\||>)(.*)$ ]]; do
        part="${BASH_REMATCH[1]}"  # Command part before the delimiter
        delimiter="${BASH_REMATCH[2]}"  # The delimiter itself
        command="${BASH_REMATCH[4]}"  # Remaining command

        part=$(echo "$part" | xargs)  # Trim whitespace

        # Check if the part starts with 'rclone'
        if [[ $part == rclone* ]]; then
            # Append additional flags to the rclone command
            updated_command+="$part $additional_flags"
        else
            updated_command+="$part"
        fi

        # Append the delimiter to the updated command
        updated_command+="$delimiter"
    done

    # Append the last remaining part, if anything
    if [[ -n "$command" ]]; then
        part=$(echo "$command" | xargs)  # Trim whitespace
        if [[ $part == rclone* ]]; then
            updated_command+="$part $additional_flags"
        else
            updated_command+="$part"
        fi
    fi

    # Output the updated command
    echo "$updated_command"
done
