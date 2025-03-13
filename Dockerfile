FROM ubuntu:22.04

# Set environment variables
ENV STOPATSTART="false"
ENV TZ=Etc/UTC
ENV CRON_COMMAND=""
ENV CRON_SCHEDULE=""
# Internxt environment variables
ENV INTERNXT_EMAIL=""
ENV INTERNXT_HTTPS=false
ENV INTERNXT_PASSWORD=""
ENV INTERNXT_TOTP=""
ENV INTERNXT_WEB_PORT=3005
# rClone environment variables
ENV RCLONE_CONFIG="/config/rclone.conf"
ENV RCLONE_GUI_PASS="rclone_password"
ENV RCLONE_GUI_USER="rclone_user"
ENV RCLONE_SSL_CERT=""
ENV RCLONE_SSL_KEY=""
ENV RCLONE_WEB_GUI_PORT=5572
# Logging environment variables
#ENV LOG_LEVEL="info"
#ENV LOG_LOGFILE_COUNT="3"
#ENV LOG_MAX_LOG_SIZE="10485760"


RUN apt-get update && \
    apt-get install -y curl gnupg2 tzdata jq gzip unzip cron && \
    curl -fsSL https://deb.nodesource.com/setup_23.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl https://rclone.org/install.sh | bash

# Install the Internxt CLI
RUN npm install -g @internxt/cli
RUN npm update -g axios

# Create directories for the rclone configuration and SSL certs
RUN mkdir -p /config/log/internxt /config/internxt/certs /root/.internxt-cli /data && \
    touch /config/log/rclone.log

# Set the timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Copy the internxt_script.sh and health_check.sh into the container
COPY health_check.sh /usr/local/bin/health_check.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY rclone_cron.sh /usr/local/bin/rclone_cron.sh

# Make the scripts executable
RUN chmod +x /usr/local/bin/health_check.sh /usr/local/bin/entrypoint.sh /usr/local/bin/rclone_cron.sh

# Create the SSH directory and set permissions to allow SSH key authentication
RUN mkdir -p /root/.ssh/id_rsa
RUN chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/id_rsa

# Expose necessary ports
# Internxt WebDAV port
EXPOSE 3005
# rClone Web GUI
EXPOSE 5572
# rClone SSH
EXPOSE 53682

# Set the entry point to run the script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Add a health check that checks if the Internxt CLI is functioning
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD /usr/local/bin/health_check.sh || exit 1
