# Use a base image with bash and necessary tools
FROM ubuntu:20.04

# Set environment variables
ENV CRON_COMMAND="" \
    CRON_SCHEDULE="*/15 * * * *" \
    INTERNXT_CONFIG_DIR="/config" \
    INTERNXT_EMAIL="" \
    INTERNXT HTTPS=false \
    INTERNXT_PASSWORD="" \
    INTERNXT_TOTP="" \
    INTERNXT_WEB_PORT=3005 \
    RCLONE_CONFIG="/config/rclone.conf" \
    RCLONE_GUI_PASS="rclone_password" \
    RCLONE_GUI_USER="rclone_user" \
    RCLONE_SSL_CERT="" \
    RCLONE_SSL_KEY="" \
    RCLONE_WEB_GUI_PORT=5572

# Install required packages including Node.js and npm
RUN apt-get update && \
    apt-get install -y curl gnupg2 && \
    curl -fsSL https://deb.nodesource.com/setup_23.x | bash - && \
    apt-get install -y nodejs rclone cron && \
    npm install -g @internxt/cli && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a directory for Internxt CLI configuration
RUN mkdir -p /config

# Copy the Internxt CLI script into the container
COPY internxt_script.sh /usr/local/bin/internxt_script.sh

# Make the script executable
RUN chmod +x /usr/local/bin/internxt_script.sh

# Set the entry point to run the script
ENTRYPOINT ["/usr/local/bin/internxt_script.sh"]

# Add a health check that runs the specified CRON_COMMAND
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD /bin/bash -c "$CRON_COMMAND" || exit 1
