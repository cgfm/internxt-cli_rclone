# Internxt CLI Docker Image

![Docker](https://img.shields.io/badge/Docker-ready-brightgreen) ![License](https://img.shields.io/badge/license-MIT-lightgrey)

This project provides a Docker image for the **Internxt CLI**, allowing users to easily interact with the Internxt storage service using command-line tools. The image encapsulates all dependencies and configurations needed to run the Internxt CLI in a clean and reproducible environment.

**Note**: This project was generated with Workik AI.

## Table of Contents

- [Internxt CLI Docker Image](#internxt-cli-docker-image)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Prerequisites](#prerequisites)
  - [Getting Started](#getting-started)
  - [Usage](#usage)
    - [Environment Variables](#environment-variables)
  - [Using Docker Compose](#using-docker-compose)
    - [Create `docker-compose.yml`](#create-docker-composeyml)
    - [Running the Service](#running-the-service)
  - [Building the Docker Image](#building-the-docker-image)
  - [GitHub Actions Workflow](#github-actions-workflow)
    - [Workflow File](#workflow-file)
  - [Contributing](#contributing)
  - [License](#license)

## Features

- **Dockerized Environment**: Easy setup and configuration for the Internxt CLI in a container.
- **Automated Builds**: Utilize GitHub Actions for automated builds and deployments.
- **Cron Job Support**: Schedule commands to run at specified intervals.
- **WebDAV and rclone Integration**: Seamless integration with WebDAV and rclone for file management.

## Prerequisites

Before you begin, ensure you have the following installed:

- [Docker](https://www.docker.com/get-started) - To build and run Docker containers.
- A Docker Hub account (or an account with your preferred container registry) to push the Docker image.

## Getting Started

1. **Clone the repository**:

   ```bash
   git clone https://github.com/your_username/internxt-cli-docker.git
   cd internxt-cli-docker
   ```

2. **Set up secrets for Docker Hub**:
   - Go to your GitHub repository settings.
   - Under the "Secrets and variables" section, add the following secrets:
     - `DOCKER_USERNAME`: Your Docker Hub username.
     - `DOCKER_PASSWORD`: Your Docker Hub password.

## Usage

To run the Internxt CLI Docker container, use the following command:

```bash
docker run -e INTERNXT_EMAIL="your_email@example.com" \
           -e INTERNXT_PASSWORD="your_password" \
           -e INTERNXT_TOTP="your_totp_secret" \
           -e INTERNXT_WEB_PORT=3005 \
           -e INTERNXT_HTTPS=true \
           -e INTERNXT_SSL_CERT="/path/to/your/cert.crt" \
           -e INTERNXT_SSL_KEY="/path/to/your/key.key" \
           -e RCLONE_WEB_GUI_PORT=5572 \
           -e RCLONE_CONFIG="/config/rclone.conf" \
           -e RCLONE_GUI_USER="your_rclone_username" \
           -e RCLONE_GUI_PASS="your_rclone_password" \
           -e CRON_COMMAND="rclone ls internxt:" \
           -e CRON_SCHEDULE="*/15 * * * *" \
           --rm -v /local/config/dir:/config \
           cgfm/internxt-cli_rclone:latest
```

### Environment Variables

| Variable                | Description                                                   |
|-------------------------|---------------------------------------------------------------|
| `INTERNXT_EMAIL`       | Your Internxt email address.                                 |
| `INTERNXT_PASSWORD`    | Your Internxt password.                                      |
| `INTERNXT_TOTP`        | Your TOTP secret (if two-factor authentication is enabled).  |
| `INTERNXT_WEB_PORT`    | Port for WebDAV (default: `3005`).                          |
| `INTERNXT_HTTPS`       | Set to `true` if using HTTPS.                                |
| `INTERNXT_SSL_CERT`    | Path to your SSL certificate.                                |
| `INTERNXT_SSL_KEY`     | Path to your SSL key.                                       |
| `RCLONE_WEB_GUI_PORT`  | Port for the rclone Web GUI (default: `5572`).              |
| `RCLONE_CONFIG`        | Path to your rclone configuration file.                      |
| `RCLONE_GUI_USER`      | Username for the rclone Web GUI.                             |
| `RCLONE_GUI_PASS`      | Password for the rclone Web GUI.                             |
| `CRON_COMMAND`         | Command to run in the cron job (e.g., `rclone ls internxt:`). |
| `CRON_SCHEDULE`        | Cron schedule (default: `*/15 * * * *`).                     |

## Using Docker Compose

To simplify the process of running the Internxt CLI with all necessary configurations, you can use Docker Compose. Below is an example of a `docker-compose.yml` file you can use.

### Create `docker-compose.yml`

Create a file named `docker-compose.yml` in the root of your project directory with the following content:

```yaml
version: '3.8'

services:
  internxt-cli:
    image: cgfm/internxt-cli_rclone:latest
    environment:
      INTERNXT_EMAIL: your_email@example.com
      INTERNXT_PASSWORD: your_password
      INTERNXT_TOTP: your_totp_secret
      INTERNXT_WEB_PORT: 3005
      INTERNXT_HTTPS: "true"
      INTERNXT_SSL_CERT: /path/to/your/cert.crt
      INTERNXT_SSL_KEY: /path/to/your/key.key
      RCLONE_WEB_GUI_PORT: 5572
      RCLONE_CONFIG: /config/rclone.conf
      RCLONE_GUI_USER: your_rclone_username
      RCLONE_GUI_PASS: your_rclone_password
      CRON_COMMAND: rclone ls internxt:
      CRON_SCHEDULE: "*/15 * * * *"
    volumes:
      - ./local/config/dir:/config
    ports:
      - "3005:3005"
      - "5572:5572"
```

### Running the Service

To start the service defined in your `docker-compose.yml` file, run the following command:

```bash
docker-compose up -d
```

This command will run the Internxt CLI container in detached mode. You can view the logs using:

```bash
docker-compose logs -f
```

To stop the service, use:

```bash
docker-compose down
```

## Building the Docker Image

To build the Docker image locally, run:

```bash
docker build -t your_dockerhub_username/your_image_name:latest .
```

## GitHub Actions Workflow

The project includes a GitHub Actions workflow that automatically builds and pushes the Docker image to Docker Hub when changes are pushed to the `main` branch. The image is tagged as `latest`.

### Workflow File

The GitHub Actions workflow is defined in `.github/workflows/docker-build.yml`. Make sure to customize your Docker Hub username and repository name in the workflow file.

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository.
2. Create a new branch for your feature or bug fix.
3. Make your changes and commit them.
4. Push your branch to your forked repository.
5. Create a pull request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
