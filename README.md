# Internxt CLI Docker Setup

This repository provides a Docker setup for running the Internxt CLI and rclone with WebDAV support. The `internxt_script.sh` script is designed to handle configuration, authentication, and WebDAV functionality.

## Prerequisites

- Docker
- Docker Compose (optional)

## Environment Variables

The following environment variables are required to configure the script:

- `INTERNXT_EMAIL`: Your Internxt account email.
- `INTERNXT_PASSWORD`: Your Internxt account password.
- `INTERNXT_TOTP`: Your two-factor authentication secret (if enabled).
- `INTERNXT_WEB_PORT`: Port for the Internxt WebDAV server (default: `3005`).
- `INTERNXT_HTTPS`: Set to `true` to enable HTTPS (default: `false`).
- `INTERNXT_SSL_CERT`: Path to your SSL certificate file.
- `INTERNXT_SSL_KEY`: Path to your SSL private key file.
- `RCLONE_WEB_GUI_PORT`: Port for the rclone Web GUI (default: `5572`).
- `CRON_COMMAND`: Command to run on a schedule.
- `CRON_SCHEDULE`: Cron schedule expression (default: `*/15 * * * *`).
- `RCLONE_GUI_USER`: Username for the rclone Web GUI (default: `rclone_user`).
- `RCLONE_GUI_PASS`: Password for the rclone Web GUI (default: `rclone_password`).

## Usage

### Build the Docker Image

To build the Docker image, run:

```bash
docker build -t internxt-cli .
```

### Run the Docker Container

To run the Docker container, use the following command:

```bash
docker run -e INTERNXT_EMAIL="your_email@example.com" \
           -e INTERNXT_PASSWORD="your_password" \
           -e INTERNXT_TOTP="your_totp_secret" \
           -e INTERNXT_WEB_PORT=3005 \
           -e INTERNXT_HTTPS=true \
           -e RCLONE_SSL_CERT="/path/to/your/cert.crt" \
           -e RCLONE_SSL_KEY="/path/to/your/key.key" \
           -e RCLONE_WEB_GUI_PORT=5572 \
           -e CRON_COMMAND="your_cron_command" \
           -e CRON_SCHEDULE="*/15 * * * *" \
           -e RCLONE_GUI_USER="your_rclone_user" \
           -e RCLONE_GUI_PASS="your_rclone_password" \
           --rm -v /path/to/your/cert.crt:/path/to/your/cert.crt \
           -v /path/to/your/key.key:/path/to/your/key.key \
           -v /local/config/dir:/config \
           internxt-cli
```

### Docker Compose Example

You can also use Docker Compose to manage the container. Below is a sample \`docker-compose.yml\` file:

```yaml
version: '3.8'

services:
  internxt-cli:
    image: internxt-cli
    environment:
      INTERNXT_EMAIL: your_email@example.com
      INTERNXT_PASSWORD: your_password
      INTERNXT_TOTP: your_totp_secret
      INTERNXT_WEB_PORT: 3005
      INTERNXT_HTTPS: 'true'
      INTERNXT_SSL_CERT: /path/to/your/cert.crt
      INTERNXT_SSL_KEY: /path/to/your/key.key
      RCLONE_WEB_GUI_PORT: 5572
      CRON_COMMAND: your_cron_command
      CRON_SCHEDULE: '*/15 * * * *'
      RCLONE_GUI_USER: your_rclone_user
      RCLONE_GUI_PASS: your_rclone_password
    volumes:
      - /path/to/your/cert.crt:/path/to/your/cert.crt
      - /path/to/your/key.key:/path/to/your/key.key
      - /local/config/dir:/config
    restart: unless-stopped
```

### Notes

- Make sure to replace `/path/to/your/cert.crt` and `/path/to/your/key.key` with the actual paths to your SSL certificate and key files.
- Adjust the `CRON_COMMAND` and `CRON_SCHEDULE` according to your needs.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
