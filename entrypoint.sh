#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Check if the initialization has been done
if [ ! -f /data/init_done ]; then
    echo "First run: copying contents from /root/.internxt-cli to /data..."

    # Copy contents from /root/.internxt-cli to /data
    cp -r /root/.internxt-cli/* /data/
    rm -r /root/.internxt-cli
    mv /data/logs /config/log/internxt
    
    # Create a symbolic link for /root/.internxt-cli to /data
    ln -s /config/log/internxt /data/logs
    
    # Create the init_done file to mark that initialization is complete
    touch /data/init_done
else
    if [ "$DEBUG" = "true" ]; then
        echo "Initialization already done. Skipping copy from /root/.internxt-cli to /data."
    fi
fi
# Create a symbolic link for /root/.internxt-cli to /data
[ -d "/root/.internxt-cli" ] &&  rm -r /root/.internxt-cli
ln -s /data /root/.internxt-cli


# Check if STOPATSTART mode is enabled
if [ "$STOPATSTART" = "true" ]; then
    echo "STOPATSTART mode is enabled."
    tail -f /dev/null  # Keep the script running indefinitely
fi

# If no CONFIG_FILE is provided, check for the default location
if [ -z "$CONFIG_FILE" ] && [ -f "/config/config.json" ]; then
    CONFIG_FILE="/config/config.json"
fi

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
    ["ROOT_CA"]="root_ca"
    ["TZ"]="timezone"
)

# Load the JSON file to check if the keys are defined
if [ -f "$CONFIG_FILE" ]; then
    # Iterate over the environment variable map
    for env_var in "${!env_var_map[@]}"; do
        json_key=${env_var_map[$env_var]}
        
        # Check if the JSON key exists in the CONFIG_FILE
        if jq -e ".settings | has(\"${json_key#*.}\")" "$CONFIG_FILE" > /dev/null; then
            # If the environment variable is not set, set it from the JSON value
            if [ -z "${!env_var}" ]; then
                value=$(jq -r ".settings.${json_key#*.}" "$CONFIG_FILE")
                
                # Check if the value is not empty before exporting
                if [ -n "$value" ]; then
                    export "$env_var=$value"
                    if [ "$DEBUG" = "true" ]; then
                        echo "Set environment variable: $env_var with value: $value"
                    fi
                else
                    if [ "$DEBUG" = "true" ]; then
                        echo "Value for $json_key is empty; not setting variable."
                    fi
                fi
            fi
        fi
    done
fi

# Ensure required environment variables are set
if [ -z "$INTERNXT_EMAIL" ] || [ -z "$INTERNXT_PASSWORD" ]; then
    echo "Error: INTERNXT_EMAIL and INTERNXT_PASSWORD must be set."
    exit 1  # Exit if required variables are not set
fi

# Debug message for environment variables check
if [ "$DEBUG" = "true" ]; then
    echo "INTERNXT_EMAIL and INTERNXT_PASSWORD are set."
fi

# Check if INTERNXT_SSL_CERT and INTERNXT_SSL_KEY are set and not empty
if [ -n "$INTERNXT_SSL_CERT" ] && [ -n "$INTERNXT_SSL_KEY" ]; then
    # Check if the SSL certificate file exists
    if [ -f "$INTERNXT_SSL_CERT" ]; then
        # Create a symbolic link for the SSL certificate if it does not point to the default location
        if [ "$INTERNXT_SSL_CERT" != "/root/.internxt-cli/certs/cert.crt" ] && [ "$INTERNXT_SSL_CERT" != "/config/internxt/certs/cert.crt" ]; then
            ln -sf "$INTERNXT_SSL_CERT" /root/.internxt-cli/certs/cert.crt
            if [ "$DEBUG" = "true" ]; then
                echo "Linked SSL certificate: $INTERNXT_SSL_CERT"
            fi
        fi
    else
        # Print an error message if the SSL certificate file does not exist
        echo "Error: SSL certificate file $INTERNXT_SSL_CERT does not exist."
    fi

    # Check if the SSL key file exists
    if [ -f "$INTERNXT_SSL_KEY" ]; then
        # Create a symbolic link for the SSL key if it does not point to the default location
        if [ "$INTERNXT_SSL_KEY" != "/root/.internxt-cli/certs/priv.key" ] && [ "$INTERNXT_SSL_KEY" != "/config/internxt/certs/priv.key" ]; then
            ln -sf "$INTERNXT_SSL_KEY" /root/.internxt-cli/certs/priv.key
            if [ "$DEBUG" = "true" ]; then
                echo "Linked SSL key: $INTERNXT_SSL_KEY"
            fi
        fi
    else
        # Print an error message if the SSL key file does not exist
        echo "Error: SSL key file $INTERNXT_SSL_KEY does not exist."
    fi
fi

# Check if a root CA was provided
if [ -n "$ROOT_CA" ]; then
    # Check if the new certificate file exists
    if [[ -f "$ROOT_CA" ]]; then
        # Append the new CA certificate to the ca-certificates.crt file
        cat "$ROOT_CA" >> "/etc/ssl/certs/ca-certificates.crt"
        echo "Root CA added: $ROOT_CA"
        if [ "$DEBUG" = "true" ]; then
            echo "Successfully appended $ROOT_CA to /etc/ssl/certs/ca-certificates.crt"
        fi
    else
        # Print an error message if the root CA file does not exist
        echo "Error: $ROOT_CA does not exist."
    fi
fi

# Create log directory if it doesn't exist
mkdir -p "/config/log/"

# Set RCLONE_CONFIG if not set
if [ -z "$RCLONE_CONFIG" ]; then
    RCLONE_CONFIG="/config/rclone.conf"
fi

# Debug message for RCLONE_CONFIG
if [ "$DEBUG" = "true" ]; then
    echo "Using RCLONE_CONFIG: $RCLONE_CONFIG"
fi

# Determine the protocol based on the INTERNXT_HTTPS variable
if [ "$INTERNXT_HTTPS" = "true" ]; then
    PROTOCOL="https"  # Use HTTPS if the variable is set to true
else
    PROTOCOL="http"   # Use HTTP otherwise
fi

# Debug message for protocol
if [ "$DEBUG" = "true" ]; then
    echo "Using protocol: $PROTOCOL"
fi

# Function to rotate logs
rotate_logs() {
    if [ "$LOG_KEEP_LOGFILES" != "true" ]; then
        # Array of log files to rotate
        LOCAL_LOG_FILES=(
            "/config/log/rclone.log"
            "/config/log/internxt/internxt-cli-error.log"
            "/config/log/internxt/internxt-webdav-error.log"
            "/config/log/internxt/internxt-cli-combined.log"
            "/config/log/internxt/internxt-webdav-combined.log"
        )

        # Determine the maximum number of log files to keep
        if [ -n "$LOG_LOGFILE_COUNT" ]; then
            MAX_LOG_FILES="$LOG_LOGFILE_COUNT"
        else
            MAX_LOG_FILES=3  # Default log file count
        fi

        # Rotate logs
        for log_file in "${LOCAL_LOG_FILES[@]}"; do
            if [ -f "$log_file" ]; then
                for ((i=MAX_LOG_FILES; i>0; i--)); do
                    if [ $i -eq $MAX_LOG_FILES ]; then
                        # Rename the current log to log.1
                        mv "$log_file" "$log_file.$i" 2>/dev/null || true
                    elif [ -f "$log_file.$i" ]; then
                        # Rename older logs
                        mv "$log_file.$i" "$log_file.$((i+1))" 2>/dev/null || true
                    fi
                done
                # Create a new log file
                touch "$log_file"
            fi
        done

        if [ "$DEBUG" = "true" ]; then
            echo "Log files rotated. New log files created."
        fi
    fi
}

# Call the log rotation function
rotate_logs

# Configure rclone to use the Internxt WebDAV server
echo "Configuring rclone internxt webdav remote with $PROTOCOL..."
if rclone config create Internxt webdav \
    url "${PROTOCOL}://${INTERNXT_HOST:-0.0.0.0}:$INTERNXT_WEB_PORT/" \
    vendor "other" \
    user "$INTERNXT_EMAIL" \
    pass "$INTERNXT_PASSWORD" \
    --config "${RCLONE_CONFIG}" >/dev/null 2>&1; then
    echo "Successfully configured rclone internxt webdav remote."
    
    if [ "$DEBUG" = "true" ]; then
        # Print the rclone configuration if debugging is enabled
        echo "Rclone config:"
        cat $RCLONE_CONFIG
    fi
else
    # Exit if the configuration fails
    echo "Failed to configure rclone internxt webdav remote."
    exit 1
fi

# Configure rclone webgui only if RCLONE_WEB_GUI is true
if [ "${RCLONE_WEB_GUI_SERVE:-true}" = "true" ]; then
    echo "Configuring rclone webgui..."
    
    rclone_command="rclone rcd"  # Start the rclone daemon command

    # Add --rc-user and --rc-pass only if both are set
    if [ -n "$RCLONE_WEB_GUI_SSL_CERT" ] && [ -n "$RCLONE_WEB_GUI_SSL_KEY" ]; then
        rclone_command+=" --rc-cert $RCLONE_WEB_GUI_SSL_CERT --rc-key $RCLONE_WEB_GUI_SSL_KEY"
        if [ "$DEBUG" = "true" ]; then
            echo "Using SSL for rclone webgui with cert: $RCLONE_WEB_GUI_SSL_CERT"
        fi
    fi

    # Add --rc-user and --rc-pass only if both are set
    if [ -n "$RCLONE_WEB_GUI_USER" ] && [ -n "$RCLONE_WEB_GUI_PASS" ]; then
        rclone_command+=" --rc-user $RCLONE_WEB_GUI_USER --rc-pass $RCLONE_WEB_GUI_PASS"
        if [ "$DEBUG" = "true" ]; then
            echo "Using authentication for rclone webgui."
        fi
    else
        rclone_command+=" --rc-no-auth"  # Disable authentication if user/pass not provided
        if [ "$DEBUG" = "true" ]; then
            echo "No authentication for rclone webgui."
        fi
    fi

    # Add additional parameters for the rclone webgui
    rclone_command+=" --rc-web-gui \
        --rc-web-gui-no-open-browser \
        --rc-web-gui-update \
        --rc-addr :$RCLONE_WEB_GUI_PORT \
        --config $RCLONE_CONFIG \
        --log-file /config/log/rclone.log \
        --log-format date,time,UTC \
        $RCLONE_WEB_GUI_EXTRA_PARAMS"
    
    if [ "$DEBUG" = "true" ]; then
        echo "Starting rclone with command:"
        echo $rclone_command  # Print the command for debugging
    fi
    eval "$rclone_command &"  # Execute the rclone command in the background
fi

# Handle TOTP for two-factor authentication
if [ -n "$INTERNXT_TOTP" ]; then
    echo "Generating TOTP..."
    TOTP=$(totp "$INTERNXT_TOTP")  # Generate the TOTP
    echo "Logging into Internxt with TOTP..."
    internxt login --email="$INTERNXT_EMAIL" --password="$INTERNXT_PASSWORD" --twofactor="$TOTP" --non-interactive
else
    echo "Logging into Internxt without TOTP..."
    internxt login --email="$INTERNXT_EMAIL" --password="$INTERNXT_PASSWORD" --non-interactive
fi

# Write the WebDAV configuration to the config file
WEBDAV_CONFIG_PATH="/data/config.webdav.inxt"

if [ "$DEBUG" = "true" ]; then
    echo "Writing WebDAV configuration to $WEBDAV_CONFIG_PATH..."
fi
mkdir -p "$(dirname "$WEBDAV_CONFIG_PATH")"  # Ensure the directory exists

# Create JSON configuration for WebDAV
if [ "$INTERNXT_HTTPS" = "true" ]; then
    echo "{\"port\":\"$INTERNXT_WEB_PORT\",\"protocol\":\"https\"}" > "$WEBDAV_CONFIG_PATH"
else
    echo "{\"port\":\"$INTERNXT_WEB_PORT\",\"protocol\":\"http\"}" > "$WEBDAV_CONFIG_PATH"
fi

if [ "$DEBUG" = "true" ]; then
    echo "WebDAV configuration written successfully."
fi

# Enable WebDAV
echo "Enabling WebDAV..."
internxt webdav enable

# Check if CRON_SCHEDULE is set, default to every 15 minutes if not
if [ -z "$CRON_SCHEDULE" ]; then
    CRON_SCHEDULE="*/15 * * * *"  # Default to every 15 minutes
    echo "No CRON_SCHEDULE provided. Using default: $CRON_SCHEDULE"
else
    echo "Cron schedule is set to: $CRON_SCHEDULE"
fi

# Set default values for CRON_COMMAND and CRON_COMMAND_FLAGS if not provided
if [ -z "$CRON_COMMAND" ]; then
    CRON_COMMAND="rclone copy"  # Default command
fi

if [ -z "$CRON_COMMAND_FLAGS" ]; then
    CRON_COMMAND_FLAGS="--create-empty-src-dirs --retries 5 --verbose"  # Default flags
fi

# Create a working copy of the JSON configuration if CONFIG_FILE is set
WORKING_JSON="/working/config.json"
mkdir -p /working  # Create the working directory

# Check if a configuration file is provided
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    # Remove existing copy if it exists
    [ -f "$WORKING_JSON" ] && rm "$WORKING_JSON"

    # Create a copy of the given JSON configuration
    cp "$CONFIG_FILE" "$WORKING_JSON"
    if [ "$DEBUG" = "true" ]; then
        echo "Copied configuration from $CONFIG_FILE to $WORKING_JSON"
    fi
else
    echo "Initialize with an empty JSON structure. No config file is provided"
    echo "{\"cron_jobs\": []}" > "$WORKING_JSON"  # Initialize with an empty structure
fi

# Check if cron_jobs key exists and initialize it if not
if ! jq -e '.cron_jobs' "$WORKING_JSON" > /dev/null; then
    echo "Initializing cron_jobs in $WORKING_JSON."
    jq '. + { cron_jobs: [] }' "$WORKING_JSON" > tmp.$$.json && mv tmp.$$.json "$WORKING_JSON"
fi

# Add the environment variables to the JSON file
for i in {1..20}; do
    cron_command_var="CRON_COMMAND_$i"  # Environment variable for command
    cron_command=""

    cron_command_flags_var="CRON_COMMAND_FLAGS_$i"  # Environment variable for command flags
    cron_command_flags=""
    
    local_path_var="LOCAL_PATH_$i"  # Environment variable for local path
    local_path="${!local_path_var}"  # Get the value of LOCAL_PATH

    remote_path_var="REMOTE_PATH_$i"  # Environment variable for remote path
    remote_path="${!remote_path_var}"  # Get the value of REMOTE_PATH

    schedule_var="CRON_SCHEDULE_$i"  # Environment variable for cron schedule
    schedule="${!schedule_var:-$CRON_SCHEDULE}"  # Get the schedule or default

    # Determine the command to use
    if [ -n "${!cron_command_var}" ]; then
        # Use user-defined command if provided
        cron_command="${!cron_command_var}"
        if [ "$DEBUG" = "true" ]; then
            echo "Using user-defined command for index $i: $cron_command"
        fi
    elif [ -n "$local_path" ] && [ -n "$remote_path" ]; then
        # Use default command only if both paths are set
        cron_command="$CRON_COMMAND"
        if [ "$DEBUG" = "true" ]; then
            echo "Using default command for index $i: $cron_command"
        fi
    else
        # Skip entry if no valid command can be determined
        if [ "$DEBUG" = "true" ]; then
            echo "No valid command for index $i. Skipping."
        fi
        continue
    fi
    
    # Determine the command flags to use
    if [ -n "${!cron_command_flags_var}" ]; then
        # Use user-defined command flags if provided
        cron_command_flags="${!cron_command_flags_var}"
        if [ "$DEBUG" = "true" ]; then
            echo "Using user-defined command flags for index $i: $cron_command_flags"
        fi
    elif [ -n "$local_path" ] && [ -n "$remote_path" ]; then
        # Use default command flags only if both paths are set
        cron_command_flags="$CRON_COMMAND_FLAGS"
        if [ "$DEBUG" = "true" ]; then
            echo "Using default command flags for index $i: $cron_command_flags"
        fi
    fi
    
    # Check if the schedule is not empty
    if [ -n "$schedule" ]; then
        # Prepare the command entry
        command_entry=$(jq -n \
            --arg cmd "$cron_command" \
            --arg cmd_flags "$cron_command_flags" \
            --arg loc_path "$local_path" \
            --arg rem_path "$remote_path" \
            '{command: $cmd, command_flags: $cmd_flags, local_path: $loc_path, remote_path: $rem_path}')
    
        # Check if the schedule exists, if not, add it
        if ! jq -e ".cron_jobs[] | select(.schedule == \"$schedule\")" "$WORKING_JSON" > /dev/null; then
            echo "Adding new schedule '$schedule' to $WORKING_JSON."
            jq --arg schedule "$schedule" '.cron_jobs += [{"schedule": $schedule, "commands": []}]' "$WORKING_JSON" > tmp.$$.json && mv tmp.$$.json "$WORKING_JSON"
        fi

        # Add the command entry to the appropriate schedule
        jq --arg schedule "$schedule" \
        --argjson command_entry "$command_entry" \
        '(.cron_jobs[] | select(.schedule == $schedule) | .commands) += [$command_entry]' \
        "$WORKING_JSON" > tmp.$$.json && mv tmp.$$.json "$WORKING_JSON"
    else
        echo "No Schedule provided for command '$command' No. $i."
    fi
done

if [ "$DEBUG" = "true" ]; then
    echo "Working JSON created:"
    cat "$WORKING_JSON"
fi

if [ -f "$WORKING_JSON" ]; then
    # Iterate over each job in the JSON file
    total_jobs=$(jq '.cron_jobs | length' "$WORKING_JSON")
    # Start cron jobs based on the schedules in the JSON file
    if [ "$total_jobs" -gt 0 ]; then
        # Initialize crontab if it doesn't exist
        touch /var/spool/cron/root

        # Iterate over each job in the JSON file
        for ((i=0; i<total_jobs; i++)); do
            # Extract the schedule for the current job
            schedule=$(jq -r ".cron_jobs[$i].schedule" "$WORKING_JSON")
            # Register the cron job in crontab
            echo "$schedule root flock -n /tmp/cron.$i.lock /usr/local/bin/rclone_cron.sh \"$i\"" >> /var/spool/cron/root
            if [ "$DEBUG" = "true" ]; then
                echo "Added cron job for schedule '$schedule' at index $i."
            fi
        done

        /usr/bin/crontab /var/spool/cron/root  # Load the new crontab
        service cron start  # Start the cron service
        echo "Cron service started."
        
        if [ "$DEBUG" = "true" ]; then
            echo "Cron jobs created created:"
            cat /var/spool/cron/root
        fi
    fi
fi

# Start log monitoring for rclone and Internxt
echo "--------------------------------------------------"
echo "Starting log monitoring for rclone and Internxt..."
echo "--------------------------------------------------"

# Use tail to follow the logs
{
    tail -f "/config/log/rclone.log" &  # Run rclone log monitoring in the background
    # Run internxt log monitoring in the background
    tail -f "/config/log/internxt/internxt-cli-error.log" &
    tail -f "/config/log/internxt/internxt-webdav-error.log" &
    if [ "$DEBUG" = "true" ]; then
        tail -f "/config/log/internxt/internxt-cli-combined.log" &
        tail -f "/config/log/internxt/internxt-webdav-combined.log" &
    fi    
    wait  # Wait for all background processes to finish
} | while read -r line; do
    # Enhanced logic to differentiate between rclone and internxt logs
    if echo "$line" | jq empty >/dev/null 2>&1; then
        # If the line is JSON, parse it and extract the desired fields
        timestamp=$(echo "$line" | jq -r '.timestamp')
        level=$(echo "$line" | jq -r '.level' | tr '[:lower:]' '[:upper:]')
        service=$(echo "$line" | jq -r '.service')
        message=$(echo "$line" | jq -r '.message')
        echo "[internxt] $timestamp $level $service $message"
    else
        # If the line is not JSON, it is from rclone
        echo "[rclone] $line"
    fi
done

# Wait indefinitely to keep the script running
wait
