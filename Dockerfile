FROM node:alpine as builder

# Set environment variables
ENV CRON_COMMAND="" \
    CRON_SCHEDULE="" \
    INTERNXT_EMAIL="" \
    INTERNXT_HTTPS=false \
    INTERNXT_PASSWORD="" \
    INTERNXT_TOTP="" \
    INTERNXT_WEB_PORT=3005 \
    TZ=Etc/UTC \
    RCLONE_CONFIG="/config/rclone.conf" \
    RCLONE_GUI_PASS="rclone_password" \
    RCLONE_GUI_USER="rclone_user" \
    RCLONE_SSL_CERT="" \
    RCLONE_SSL_KEY="" \
    RCLONE_WEB_GUI_PORT=5572

# Install the Internxt CLI
RUN npm install -g @internxt/cli

# Install rclone and other required packages
RUN apk add --no-cache curl tzdata rclone cron

# Set the timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Create directories for the rclone configuration and SSL certs
RUN mkdir -p /config /root/.internxt-cli/certs

# Link SSL certificate and key files if provided
RUN ln -sf $INTERNXT_SSL_CERT /root/.internxt-cli/certs/cert.crt && \
    ln -sf $INTERNXT_SSL_KEY /root/.internxt-cli/certs/priv.key

# Copy the internxt_script.sh and health_check.sh into the container
COPY internxt_script.sh /usr/local/bin/internxt_script.sh
COPY health_check.sh /usr/local/bin/health_check.sh

# Make the scripts executable
RUN chmod +x /usr/local/bin/internxt_script.sh /usr/local/bin/health_check.sh

# Set the entry point to run the script
ENTRYPOINT ["/usr/local/bin/internxt_script.sh"]

# Add a health check that checks if the Internxt CLI is functioning
HEALTHCHECK --interval=60s --timeout=15s --start-period=10s --retries=3 \
    CMD /usr/local/bin/health_check.sh || exit 1