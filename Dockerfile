FROM ubuntu:22.04

# Set environment variables
ENV STOPATSTART="false"
ENV CRON_COMMAND=""
ENV CRON_SCHEDULE=""
ENV DEBUG="false"
ENV INTERNXT_EMAIL=""
ENV INTERNXT_HTTPS=false
ENV INTERNXT_PASSWORD=""
ENV INTERNXT_TOTP=""
ENV INTERNXT_WEB_PORT=3005
ENV TZ=Etc/UTC
ENV RCLONE_CONFIG="/config/rclone.conf"
ENV RCLONE_GUI_PASS="rclone_password"
ENV RCLONE_GUI_USER="rclone_user"
ENV RCLONE_SSL_CERT=""
ENV RCLONE_SSL_KEY=""
ENV RCLONE_WEB_GUI_PORT=5572

# Install required packages including Node.js and npm
RUN apt-get update && \
    apt-get install -y curl gnupg2 tzdata jq && \
    curl -fsSL https://deb.nodesource.com/setup_23.x | bash - && \
    apt-get install -y nodejs rclone cron && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install the Internxt CLI
RUN npm install -g @internxt/cli

# Set the timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Create directories for the rclone configuration and SSL certs
RUN mkdir -p /config/log /root/.internxt-cli/certs
RUN touch /config/log/rclone.log

# Link SSL certificate and key files if provided
RUN ln -sf $INTERNXT_SSL_CERT /root/.internxt-cli/certs/cert.crt && \
    ln -sf $INTERNXT_SSL_KEY /root/.internxt-cli/certs/priv.key

# Copy the internxt_script.sh and health_check.sh into the container
COPY health_check.sh /usr/local/bin/health_check.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY rclone_cron.sh /usr/local/bin/rclone_cron.sh

# Make the scripts executable
RUN chmod +x /usr/local/bin/health_check.sh /usr/local/bin/entrypoint.sh /usr/local/bin/rclone_cron.sh

# Set the entry point to run the script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Add a health check that checks if the Internxt CLI is functioning
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD /usr/local/bin/health_check.sh || exit 1
