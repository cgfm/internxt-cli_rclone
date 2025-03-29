#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Function to return debug messages based on the debug level
log_debug() {
    local level="$1"
    local message="$2"

    # Check if LOG_LEVEL
    if [ "$LOG_LEVEL" = "debug" ] && [ "$level" = "debug" ]; then
        message="[DEBUG]: $message"
    elif ([ "$LOG_LEVEL" = "debug" ] || [ "$LOG_LEVEL" = "info" ]) && [ "$level" = "info" ]; then
        message="[INFO]: $message"
    elif ([ "$LOG_LEVEL" = "debug" ] || [ "$LOG_LEVEL" = "info" ] || [ "$LOG_LEVEL" = "notice" ])  && [ "$level" = "notice" ]; then
        message="[NOTICE]: $message"
    elif ([ "$LOG_LEVEL" = "debug" ] || [ "$LOG_LEVEL" = "info" ] || [ "$LOG_LEVEL" = "notice" ] || [ "$LOG_LEVEL" = "error" ]) && [ "$level" = "error" ]; then
        message="[ERROR]: $message"
    fi
    # Log to file
    echo -e "[main] $(date '+%Y-%m-%d %H:%M:%S') $message"
}

# Rotate logs to prevent them from growing indefinitely
rotate_logs() {
    log_file="$1"
    log_debug "debug" "Rotating log file: $log_file"
    if [ -f "$log_file" ]; then
        max_log_files=${LOG_FILE_COUNT:-3} # Default to 3 if LOG_FILE_COUNT is not set
        
        if [ "$max_log_files" -lt 0 ]; then
            # Find the highest appended number
            max_log_files=0
            for existing_log in "$log_file."*; do
                if [[ "$existing_log" =~ \.$([0-9]+)$ ]]; then
                    number=${BASH_REMATCH[1]}  # Extract the number from the filename
                    if (( number > max_log_files )); then
                        max_log_files=$number  # Update highest number found
                    fi
                fi
            done
            max_log_files+=1  # Increment to get the next log file number
        fi
        # Increment all existing log numbers starting from the highest
        for ((i=max_log_files-1; i>0; i--)); do
            if [ -f "$log_file.$i" ]; then
                mv "$log_file.$i" "$log_file.$((i + 1))" 2>/dev/null || true
            fi
        done

        # Rename the current log file to log.1
        mv "$log_file" "$log_file.1" 2>/dev/null || true
        # Create a new log file
    fi
    touch "$log_file"
}

# Write the WebDAV configuration to the config file
WEBDAV_CONFIG_PATH="/data/internxt/config.webdav.inxt"

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
    ["RCLONE_WEB_GUI_HTPASSWD_PATH"]="rclone.web_htpasswd_path"
    ["RCLONE_WEB_GUI_SSL_CERT"]="rclone.webgui_ssl_cert"
    ["RCLONE_WEB_GUI_SSL_KEY"]="rclone.webgui_ssl_key"
    ["RCLONE_WEB_GUI_EXTRA_PARAMS"]="rclone.webgui_extra_params"
    ["CRON_COMMAND"]="cron.command"
    ["CRON_COMMAND_FLAGS"]="cron.command_flags"
    ["CRON_SCHEDULE"]="cron.schedule"
    ["LOG_FILE_COUNT"]="log.file_count"
    ["LOG_LEVEL"]="log.level"
    ["LOG_MAX_LOG_SIZE"]="log.max_log_size"
    ["LOG_ROTATE_AT_START"]="log.rotate_at_start"
    ["ROOT_CA"]="root_ca"
)

# If no CONFIG_FILE is provided, check for the default location
if [ -z "$CONFIG_FILE" ] && [ -f "/config/config.json" ]; then
    CONFIG_FILE="/config/config.json"
fi

# Create a working pathes for the JSON and .htaccess files to avoid overwriting the original
WORKING_JSON="/working/config.json"
WORKING_HTPASSWD="/working/.htpasswd"

# Create directories if they do not exist
mkdir -p /data/internxt/certs /data/rclone /logs/internxt /logs/rclone /working
mkdir -p "$(dirname "$WEBDAV_CONFIG_PATH")"  # Ensure the directory exists

# Array of log files to rotate
LOCAL_LOG_FILES=(
    "/logs/cron.log"
    "/logs/rclone/rclone.log"
    "/logs/internxt/internxt-cli-error.log"
    "/logs/internxt/internxt-webdav-error.log"
    "/logs/internxt/internxt-cli-combined.log"
    "/logs/internxt/internxt-webdav-combined.log"
)

touch /logs/cron.log /logs/rclone/rclone.log


# Check if the initialization has been done
if [ ! -f /data/init_done ]; then
    log_debug "notice" "First run: copying contents from /root/.internxt-cli to /data/internxt and /logs/internxt..."

    # Copy contents from /root/.internxt-cli to /data
    cp -r /root/.internxt-cli/* /data/internxt
    mv /data/internxt/logs /logs/internxt
    
    ln -s /logs/internxt /data/internxt/logs
    
    # Create the init_done file to mark that initialization is complete
    touch /data/init_done
else
    log_debug "info" "Initialization already done. Skipping copy from /root/.internxt-cli to /data/internxt and /root/.cache/rclone to /data/rclone."
fi

# Create a symbolic link for /root/.internxt-cli to /data/internxt
rm -rf /root/.internxt-cli
ln -sf /data/internxt /root/.internxt-cli
# Create a symbolic link for /root/.cache/rclone to /data/rclone
rm -rf /root/.cache/rclone
ln -sf /data/rclone /root/.cache/rclone

# Check if STOPATSTART mode is enabled
if [ "$STOPATSTART" = "true" ]; then
    log_debug "notice" "STOPATSTART mode is enabled."
    tail -f /dev/null  # Keep the script running indefinitely
fi

max_log_size=${LOG_MAX_LOG_SIZE:-10485760}

# Check the size of the log file only if LOG_MAX_LOG_SIZE is set
if [ "$max_log_size" -le 0 ] || [ "${LOG_ROTATE_AT_START:-false}" = "true" ]; then
    # Rotate logs
    for log_file in "${LOCAL_LOG_FILES[@]}"; do
        rotate_logs "$log_file"
    done
    log_debug "info" "Log files rotated. New log files created."
fi

# Check if a configuration file is provided
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    # Remove existing copy if it exists
    [ -f "$WORKING_JSON" ] && rm "$WORKING_JSON"

    # Create a copy of the given JSON configuration
    cp "$CONFIG_FILE" "$WORKING_JSON"
    log_debug "notice" "Copied configuration from $CONFIG_FILE to $WORKING_JSON"
else
    log_debug "notice" "Initialize with an empty JSON structure. No config file is provided"
    echo "{\"cron_jobs\": [], \"settings\": {}}" > "$WORKING_JSON"  # Initialize with an empty structure
fi

# Check if a configuration file is provided
if [ -n "$RCLONE_WEB_GUI_HTPASSWD_PATH" ] && [ -f "$RCLONE_WEB_GUI_HTPASSWD_PATH" ]; then
    # Remove existing copy if it exists
    [ -f "$WORKING_HTPASSWD" ] && rm "$WORKING_HTPASSWD"

    # Create a copy of the given .htaccess configuration
    cp "$RCLONE_WEB_GUI_HTPASSWD_PATH" "$WORKING_HTPASSWD"
    # Remove any carriage return characters from the file
    sed -i 's/\r$//' "$WORKING_HTPASSWD"

    log_debug "notice" "Load .htpasswd from $RCLONE_WEB_GUI_HTPASSWD_PATH to $WORKING_HTPASSWD"

    if [ -n "$RCLONE_WEB_GUI_USER" ] && [ -n "$RCLONE_WEB_GUI_PASS" ]; then
        # Check if the user already exists in the .htpasswd file
        if grep -q "^$RCLONE_WEB_GUI_USER:" "$WORKING_HTPASSWD"; then
            log_debug "notice" "User $RCLONE_WEB_GUI_USER already exists in .htpasswd."
            # Verify the user and password
            if ! htpasswd -v -b "$WORKING_HTPASSWD" "$RCLONE_WEB_GUI_USER" "$RCLONE_WEB_GUI_PASS"; then
                htpasswd -D "$WORKING_HTPASSWD" "$RCLONE_WEB_GUI_USER"
                htpasswd -B -b "$WORKING_HTPASSWD" "$RCLONE_WEB_GUI_USER"
                log_debug "notice" "Password for user $RCLONE_WEB_GUI_USER differs from the one in .htpasswd. Updated password in .htpasswd."
            fi
        else
            log_debug "debug" "Add user $RCLONE_WEB_GUI_USER to .htpasswd"
            # Add the user to the .htpasswd file
            htpasswd -B -b "$WORKING_HTPASSWD" "$RCLONE_WEB_GUI_USER" "$RCLONE_WEB_GUI_PASS"
            log_debug "notice" "User $RCLONE_WEB_GUI_USER added to .htpasswd"
        fi
    fi
fi

add_to_json() {
    local json_key=$1
    local env_var=$2
    
    # If the environment variable is set, add it to the WORKING_JSON
    existing_value="${!env_var}"
    if [[ "$json_key" == *.* ]]; then
        # Split the json_key into main_key and sub_key
        main_key=$(echo "$json_key" | cut -d '.' -f 1)
        json_key=$(echo "$json_key" | cut -d '.' -f 2-)

        # Use jq to set the nested keys
        jq --arg main_key "$main_key" --arg json_key "$json_key" --arg value "$existing_value" \
            '.settings[$main_key][$json_key] = $value' "$WORKING_JSON" > tmp.$$.json && mv tmp.$$.json "$WORKING_JSON"
    else
        # Use jq to set the nested keys
        jq --arg --arg json_key "$json_key" --arg value "$existing_value" \
            '.settings[$json_key] = $value' "$WORKING_JSON" > tmp.$$.json && mv tmp.$$.json "$WORKING_JSON"
    fi                
    log_debug "info" "Added existing environment variable to JSON: $env_var"

}

# Load the JSON file to check if the keys are defined
if [ -f "$WORKING_JSON" ]; then
    log_debug "debug" "Found config file at $WORKING_JSON."
    # Iterate over the environment variable map
    for env_var in "${!env_var_map[@]}"; do
        json_key=${env_var_map[$env_var]}
        
        # Check if the JSON key exists in the WORKING_JSON
        if jq -e ".settings | .${json_key} != null" "$WORKING_JSON" > /dev/null; then
            log_debug "debug" "Searching for $json_key."

            # If the environment variable is not set, set it from the JSON value
            if [ -z "${!env_var}" ]; then
                value=$(jq -r ".settings.${json_key}" "$WORKING_JSON")
                
                log_debug "debug" "$json_key with value '$value' found in $WORKING_JSON."
                # Check if the value is not empty before exporting
                if [ -n "$value" ]; then
                    export "$env_var=$value"
                    log_debug "info" "Set environment variable: $env_var with value: $value"
                else
                    log_debug "debug" "Value for $json_key is empty; not setting variable."
                fi
            else
                log_debug "info" "$env_var already set. Ignoring $json_key."
                add_to_json "$json_key" "$env_var"
            fi
        else
            # If the JSON key is not found, set it from the environment variable
            if [ -n "${!env_var}" ]; then
                log_debug "debug" "$json_key not found in $WORKING_JSON."
                add_to_json "$json_key" "$env_var"
            else
                log_debug "debug" "Nither $env_var nor $json_key were provided."
            fi
        fi
    done
    log_debug "notice" "Config file \"$WORKING_JSON\" processed."
else
    log_debug "info" "Config file not found at $WORKING_JSON."
fi

export PHP_TZ="$TZ"

# Ensure required environment variables are set
if [ -z "$INTERNXT_EMAIL" ] || [ -z "$INTERNXT_PASSWORD" ]; then
    log_debug "error" "INTERNXT_EMAIL and INTERNXT_PASSWORD must be set."
    exit 1  # Exit if required variables are not set
else
    log_debug "debug" "INTERNXT_EMAIL and INTERNXT_PASSWORD are set."
fi

# Check if INTERNXT_SSL_CERT and INTERNXT_SSL_KEY are set and not empty
if [ -n "$INTERNXT_SSL_CERT" ] && [ -n "$INTERNXT_SSL_KEY" ]; then
    # Check if the SSL certificate file exists
    if [ -f "$INTERNXT_SSL_CERT" ]; then
        # Create a symbolic link for the SSL certificate if it does not point to the default location
        if [ "$INTERNXT_SSL_CERT" != "/root/.internxt-cli/certs/cert.crt" ] && [ "$INTERNXT_SSL_CERT" != "/config/internxt/certs/cert.crt" ]; then
            ln -sf "$INTERNXT_SSL_CERT" /data/internxt/certs/cert.crt
            log_debug "info" "Linked SSL certificate: $INTERNXT_SSL_CERT"
        fi
    else
        log_debug "error" "SSL certificate file $INTERNXT_SSL_CERT does not exist."
    fi

    # Check if the SSL key file exists
    if [ -f "$INTERNXT_SSL_KEY" ]; then
        # Create a symbolic link for the SSL key if it does not point to the default location
        if [ "$INTERNXT_SSL_KEY" != "/root/.internxt-cli/certs/priv.key" ] && [ "$INTERNXT_SSL_KEY" != "/config/internxt/certs/priv.key" ]; then
            ln -sf "$INTERNXT_SSL_KEY" /data/internxt/certs/priv.key
            log_debug "info" "Linked SSL key: $INTERNXT_SSL_KEY"
        fi
    else
        log_debug "error" "SSL key file $INTERNXT_SSL_KEY does not exist."
    fi
fi

# Check if a root CA was provided
if [ -n "$ROOT_CA" ]; then
    # Check if the new certificate file exists
    if [[ -f "$ROOT_CA" ]]; then
        # Append the new CA certificate to the ca-certificates.crt file
        cat "$ROOT_CA" >> "/etc/ssl/certs/ca-certificates.crt"
        log_debug "notice" "Root CA added: $ROOT_CA"
        log_debug "info" "Successfully appended $ROOT_CA to /etc/ssl/certs/ca-certificates.crt"
    else
        log_debug "error" "$ROOT_CA does not exist."
    fi
fi

# Set RCLONE_CONFIG if not set
if [ -z "$RCLONE_CONFIG" ]; then
    RCLONE_CONFIG="/config/rclone.conf"
    log_debug "debug" "RCLONE_CONFIG not set, defaulting to $RCLONE_CONFIG"
fi

# Debug message for RCLONE_CONFIG
log_debug "info" "Using RCLONE_CONFIG: $RCLONE_CONFIG"

# Determine the protocol based on the INTERNXT_HTTPS variable
if [ "$INTERNXT_HTTPS" = "true" ]; then
    PROTOCOL="https"  # Use HTTPS if the variable is set to true
else
    PROTOCOL="http"   # Use HTTP otherwise
fi

# Debug message for protocol
log_debug "info" "Using protocol: $PROTOCOL"

# Configure rclone to use the Internxt WebDAV server
log_debug "info" "Configuring rclone internxt webdav remote with $PROTOCOL..."
if rclone config create Internxt webdav \
    url "${PROTOCOL}://${INTERNXT_HOST:-0.0.0.0}:$INTERNXT_WEB_PORT/" \
    vendor "other" \
    user "$INTERNXT_EMAIL" \
    pass "$INTERNXT_PASSWORD" \
    --config "${RCLONE_CONFIG}" >/dev/null 2>&1; then
    log_debug "notice" "Configured rclone internxt webdav remote."
    
    log_debug "debug" "Rclone config:\n$(< $RCLONE_CONFIG)"
else
    # Exit if the configuration fails
    log_debug "error" "Failed to configure rclone internxt webdav remote."
    exit 1
fi

OUTPUT=""

# Configure rclone webgui only if RCLONE_WEB_GUI is true
if [ "${RCLONE_WEB_GUI_SERVE:-true}" = "true" ]; then
    log_debug "notice" "Configuring rclone webgui..."
    
    rclone_command="rclone rcd"  # Start the rclone daemon command

    # Add --rc-user and --rc-pass only if both are set
    if [ -n "$RCLONE_WEB_GUI_SSL_CERT" ] && [ -n "$RCLONE_WEB_GUI_SSL_KEY" ]; then
        rclone_command+=" --rc-cert $RCLONE_WEB_GUI_SSL_CERT --rc-key $RCLONE_WEB_GUI_SSL_KEY"
        log_debug "info" "Using SSL for rclone webgui with cert: $RCLONE_WEB_GUI_SSL_CERT"
    fi

    if [ -n "$RCLONE_WEB_GUI_HTPASSWD_PATH" ]; then
        rclone_command+=" --rc-htpasswd $RCLONE_WEB_GUI_HTPASSWD_PATH"
        log_debug "info" "Using .httpasswd for rclone webgui."
    else
        # Add --rc-user and --rc-pass only if both are set
        if [ -n "$RCLONE_WEB_GUI_USER" ] && [ -n "$RCLONE_WEB_GUI_PASS" ]; then
            rclone_command+=" --rc-user $RCLONE_WEB_GUI_USER --rc-pass $RCLONE_WEB_GUI_PASS"
            log_debug "info" "Using authentication for rclone webgui."
        else
            rclone_command+=" --rc-no-auth"  # Disable authentication if user/pass not provided
            log_debug "info" "No authentication for rclone webgui."
        fi
    fi

    # Add additional parameters for the rclone webgui
    rclone_command+=" --rc-web-gui \
        --rc-web-gui-no-open-browser \
        --rc-web-gui-update \
        --rc-addr :$RCLONE_WEB_GUI_PORT \
        --config $RCLONE_CONFIG \
        --log-file /logs/rclone/rclone.log \
        --log-format date,time,UTC \
        $RCLONE_WEB_GUI_EXTRA_PARAMS"
    
    log_debug "info" "Starting rclone with command:\n$rclone_command"
    OUTPUT=$(eval "$rclone_command &" 2>&1)  # Execute the rclone command in the background
    log_debug "debug" "$OUTPUT"
fi

# Handle TOTP for two-factor authentication
if [ -n "$INTERNXT_TOTP" ]; then
    echo "Generating TOTP..."
    TOTP=$(totp "$INTERNXT_TOTP")  # Generate the TOTP
    log_debug "notice" "Logging into Internxt with TOTP..."
    OUTPUT=$(internxt login --email="$INTERNXT_EMAIL" --password="$INTERNXT_PASSWORD" --twofactor="$TOTP" --non-interactive 2>&1)
else
    log_debug "notice" "Logging into Internxt without TOTP..."
    OUTPUT=$(internxt login --email="$INTERNXT_EMAIL" --password="$INTERNXT_PASSWORD" --non-interactive 2>&1)
fi
log_debug "debug" "$OUTPUT" 

log_debug "info" "Writing WebDAV configuration to $WEBDAV_CONFIG_PATH..."
# Create JSON configuration for WebDAV
if [ "$INTERNXT_HTTPS" = "true" ]; then
    echo "{\"port\":\"$INTERNXT_WEB_PORT\",\"protocol\":\"https\"}" > "$WEBDAV_CONFIG_PATH"
else
    echo "{\"port\":\"$INTERNXT_WEB_PORT\",\"protocol\":\"http\"}" > "$WEBDAV_CONFIG_PATH"
fi
log_debug "debug" "WebDAV configuration written."

# Enable WebDAV
log_debug "notice" "Enabling WebDAV..."
OUTPUT=$(internxt webdav enable 2>&1)  # Capture the output of the command
log_debug "debug" "$OUTPUT"  # Log the output at the 'fine' level

# Verify if the WebDAV server is online
if [[ "$OUTPUT" != *"online"* ]]; then
    error_exit "Internxt WebDAV server is not running. Status: $WEBDAV_STATUS"
    exit 1
fi

# Check if CRON_SCHEDULE is set, default to every 15 minutes if not
if [ -z "$CRON_SCHEDULE" ]; then
    CRON_SCHEDULE="*/15 * * * *"  # Default to every 15 minutes
    log_debug "info" "No CRON_SCHEDULE provided. Using default: $CRON_SCHEDULE"
else
    log_debug "info" "Cron schedule is set to: $CRON_SCHEDULE"
fi

# Set default values for CRON_COMMAND and CRON_COMMAND_FLAGS if not provided
if [ -z "$CRON_COMMAND" ]; then
    CRON_COMMAND="rclone copy"  # Default command
fi

if [ -z "$CRON_COMMAND_FLAGS" ]; then
    CRON_COMMAND_FLAGS="--create-empty-src-dirs --retries 5"  # Default flags
fi

# Check if cron_jobs key exists and initialize it if not
if ! jq -e '.cron_jobs' "$WORKING_JSON" > /dev/null; then
    log_debug "notice" "Initializing cron_jobs in $WORKING_JSON."
    jq '. + { cron_jobs: [] }' "$WORKING_JSON" > tmp.$$.json && mv tmp.$$.json "$WORKING_JSON"
fi

# Add the environment variables to the JSON file
log_debug "info" "Adding cron jobs from the environment variables to $WORKING_JSON"
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
        log_debug "debug" "Using user-defined command for index $i: $cron_command"
    elif [ -n "$local_path" ] && [ -n "$remote_path" ]; then
        # Use default command only if both paths are set
        cron_command="$CRON_COMMAND"
        log_debug "debug" "Using default command for index $i: $cron_command"
    else
        # Skip entry if no valid command can be determined
        log_debug "debug" "No valid command for index $i. Skipping."
        continue
    fi
    
    # Determine the command flags to use
    if [ -n "${!cron_command_flags_var}" ]; then
        # Use user-defined command flags if provided
        cron_command_flags="${!cron_command_flags_var}"
        log_debug "debug" "Using user-defined command flags for index $i: $cron_command_flags"
    elif [ -n "$local_path" ] && [ -n "$remote_path" ]; then
        # Use default command flags only if both paths are set
        cron_command_flags="$CRON_COMMAND_FLAGS"
        log_debug "debug" "Using default command flags for index $i: $cron_command_flags"
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
            log_debug "info" "Adding new schedule '$schedule' to $WORKING_JSON."
            jq --arg schedule "$schedule" '.cron_jobs += [{"schedule": $schedule, "commands": []}]' "$WORKING_JSON" > tmp.$$.json && mv tmp.$$.json "$WORKING_JSON"
        fi

        # Add the command entry to the appropriate schedule
        jq --arg schedule "$schedule" \
        --argjson command_entry "$command_entry" \
        '(.cron_jobs[] | select(.schedule == $schedule) | .commands) += [$command_entry]' \
        "$WORKING_JSON" > tmp.$$.json && mv tmp.$$.json "$WORKING_JSON"
    else
        log_debug "info" "No Schedule provided for command '$command' No. $i."
    fi
done

log_debug "debug" "Working JSON created:\n$(jq --indent 2 . "$WORKING_JSON")"

if [ -f "$WORKING_JSON" ]; then
    # Iterate over each job in the JSON file
    total_schedules=$(jq '.cron_jobs | length' "$WORKING_JSON")
    # Start cron jobs based on the schedules in the JSON file
    if [ "$total_schedules" -gt 0 ]; then
        # Initialize crontab if it doesn't exist
        [ -f "/var/spool/cron/root" ] && rm /var/spool/cron/root
        touch /var/spool/cron/root

        # Iterate over each job in the JSON file
        for ((i=0; i<total_schedules; i++)); do
            # Extract the schedule for the current job
            if jq -e ".cron_jobs[$i].schedule | type == \"array\"" "$WORKING_JSON" > /dev/null; then
                schedules_array=$(jq -r ".cron_jobs[$i].schedule[]" "$WORKING_JSON")
                
                while IFS= read -r schedule; do
                    # Register the cron job in crontab
                    echo "$schedule flock -n /tmp/cron.$i.lock /usr/local/bin/rclone_cron.sh \"$i\"" >> /var/spool/cron/root
                    log_debug "info" "Added cron job for schedule '$schedule' at index $i."
                done <<< "$schedules_array"
            else
                schedule=$(jq -r ".cron_jobs[$i].schedule" "$WORKING_JSON")

                # Register the cron job in crontab
                echo "$schedule flock -n /tmp/cron.$i.lock /usr/local/bin/rclone_cron.sh \"$i\"" >> /var/spool/cron/root
                log_debug "info" "Added cron job for schedule '$schedule' at index $i."
            fi
        done
        /usr/bin/crontab /var/spool/cron/root  # Load the new crontab

        OUTPUT=$(service cron start 2>&1)  # Start the cron service
        log_debug "debug" "$OUTPUT" 
        if ! pgrep cron > /dev/null; then
            log_debug "error" "Cron service is not running."
        else
            log_debug "notice" "Cron service started."
        fi
        
        OUTPUT=$(crontab -l 2>&1)
        log_debug "debug" "Cron jobs created created:\n$OUTPUT"
    fi
fi

# Start log monitoring for rclone and Internxt
echo " "
echo " "
echo "--------------------------------------------------"
echo "Starting log monitoring for rclone and Internxt..."
echo "--------------------------------------------------"
echo " "

# Function to tail a log file with a specific prefix
tail_with_prefix() {
    local log_file="$1"
    local prefix="$2"

    tail -f -n 0 "$log_file" | while read -r line; do
        
        if [[ "$line" == "tail: '$log_file'"* ]]; then
            continue
        fi

        # Prompt the line to the log file only if onlyCheckSize is not true
        if [ "$onlyCheckSize" != "true" ]; then
            # If the line is JSON, parse it and extract the desired fields
            if echo "$line" | jq . >/dev/null 2>&1; then
                timestamp=$(echo "$line" | jq -r '.timestamp')
                level=$(echo "$line" | jq -r '.level' | tr '[:lower:]' '[:upper:]')
                service=$(echo "$line" | jq -r '.service')
                message=$(echo "$line" | jq -r '.message')
                echo "[$prefix] $timestamp $level $service $message"
            else
                # If the line is not JSON, it is from rclone
                echo "[$prefix] $line"
            fi
        fi
    done || {
        log_debug "error" "An unexpected error occurred while tailing the log file: $log_file"
        return 1  # Exit with an error status if the tailing process fails
    }
}

# Start tailing multiple log files in parallel
for log_file in "${LOCAL_LOG_FILES[@]}"; do
    prefix=$(basename "$log_file" | sed 's/[\.-].*$//')  # Extract prefix from filename

    # Decide whether to start tailing based on the log level
    if [[ "$LOG_LEVEL" = "debug" || ! "$log_file" =~ combined\.log$ || ! "$log_file" =~ internxt ]]; then
        tail_with_prefix "$log_file" "$prefix" &  # Tail log file with prefix
    else
        log_debug "notice" "Skipping logging for $log_file as the log level is not 'fine'."
    fi
done

max_log_size=${LOG_MAX_LOG_SIZE:-10485760}

while true; do
    # Check the size of the log file only if LOG_MAX_LOG_SIZE is set
    if [ "$max_log_size" -gt 0 ]; then
        for log_file in "${LOCAL_LOG_FILES[@]}"; do
            # Check the size of the log file
            current_size=$(stat -c%s "$log_file")

            # Rotate the log file if current size exceeds max size
            if [ "$current_size" -gt "$max_log_size" ]; then
               rotate_logs "$log_file"
            fi
       done
    fi
    sleep 60  # Adjust the sleep time as needed
done &

inotifywait -m /logs/rclone -e create |
    while read dir action file; do
        tail_with_prefix "$file" "rclone" &  # Tail log file with prefix
    done
# Wait indefinitely to keep the script running
wait
