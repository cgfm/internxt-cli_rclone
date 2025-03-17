# Internxt CLI with rclone

This repository contains a Docker setup to run the Internxt CLI with rclone support. It allows you to synchronize files between your local filesystem and Internxt using WebDAV.

## Development ##
This is still in development and not ready for production use.

## Environment Variables

The following environment variables can be set when running the Docker container. You can define up to 20 pairs of remote and local paths. Note that for each local path, a corresponding remote path is necessary.

| Environment Variable                | JSON Key                      | Description                                                                                                                                        |
|-------------------------------------|-------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| `CONFIG_FILE`                       |                               | Path to the JSON configuration file for cron jobs. Default is `/config/rclone_cron.json`. If this file does not exist, it will be ignored. Details for creating this file is explained at [JSON Configuration](#json-configuration)        |
| `INTERNXT_EMAIL`                    |  `internxt.email`             | Email address for Internxt login.  ![Static Badge](https://img.shields.io/badge/mandatory-red) if not set in config file.                                                      | 
| `INTERNXT_PASSWORD`                 |  `internxt.password`          | Password for Internxt login.  ![Static Badge](https://img.shields.io/badge/mandatory-red) if not set in config file.                                                          |
| `INTERNXT_HTTPS`                    |  `internxt.https`             | Set to `true` to enable HTTPS for WebDAV. Default is `false`.                                                                                      |
| `INTERNXT_SSL_CERT`                 |  `internxt.ssl_cert`          | Path to the SSL certificate for HTTPS (if enabled).                                                                                                |
| `INTERNXT_SSL_KEY`                  |  `internxt.ssl_key`           | Path to the SSL key for HTTPS (if enabled).                                                                                                        |
| `INTERNXT_TOTP`                     |  `internxt.totp`              | TOTP secret for two-factor authentication (optional).                                                                                              |
| `INTERNXT_HOST`                     |  `internxt.host`              | The host of the Internxt WebDAV to connect to (optional). Default is 0.0.0.0                                                                       |
| `INTERNXT_WEB_PORT`                 |  `internxt.web_port`          | Port for Internxt WebDAV service. Default is `3005`.                                                                                               |
| `RCLONE_CONFIG`                     |  `rclone.config`              | Path to the rclone configuration file. Default is `/config/rclone.conf`.                                                                           |
| `RCLONE_WEB_GUI_SERVE`              |  `rclone.webgui_serve`        | Set to false to disable the rClone Web GUI. Default is `true`.                                                                                     |
| `RCLONE_WEB_GUI_PORT`               |  `rclone.webgui_port`         | Port for rclone Web GUI. Default is `5572`.                                                                                                        |
| `RCLONE_WEB_GUI_USER`               |  `rclone.webgui_user`         | Username for the rclone Web GUI (optional). If no user and pass are set they won't be used. |
| `RCLONE_WEB_GUI_PASS`               |  `rclone.webgui_pass`         | Password for the rclone Web GUI (optional). If no user and pass are set they won't be used. |
| `RCLONE_WEB_GUI_HTPASSWD_PATH`      |  `rclone.webgui_htpasswd_path`| Path to the htpasswd file for the rclone Web GUI (optional). Ìf username and password are set together with .htpasswd file, the username and password will be checked against the file. If the check fails, the user will be updated with the given username and password. |
| `RCLONE_WEB_GUI_SSL_CERT`           |  `rclone.webgui_ssl_cert`     | Path to the SSL certificate for HTTPS (if enabled).                                                                                                |
| `RCLONE_WEB_GUI_SSL_KEY`            |  `rclone.webgui_ssl_key`      | Path to the SSL key for HTTPS (if enabled).                                                                                                        |
| `RCLONE_WEB_GUI_EXTRA_PARAMS`       |  `rclone.webgui_extra_params` | Additional parameters for rclone Web GUI (optional). Default is an empty string.                                                                   |
| `CRON_COMMAND`                      |  `cron.command`               | Default cron command to be executed by cron (optional). Can be overwritten by the `CRON_COMMAND_*` variables. Default is `rclone copy`. The command will be run with each pair of local and remote paths.<br>If remote files should be deleted if the don't exists locally anymore set this to `rclone sync`. **WARNING:** This will delete files on the remote if they are not present locally. **This could cause data loss!**  |
| `CRON_COMMAND_FLAGS`                |  `cron.command_flags`         | The Flags appended to the command above  (optional). Can be overwritten by the `CRON_COMMAND_FLAGS_*` variables. Default is ` --create-empty-src-dirs --retries 5`. The command will be run with each pair of local and remote paths. |
| `CRON_SCHEDULE`                     |  `cron.schedule`              | Cron schedule for running the specified command. Can be overwritten by the `CRON_SCHEDULE_*` variables. Default is */15 * * * *.                                    |
| `LOCAL_PATH_1` to `LOCAL_PATH_20`   |                               | Up to 20 local paths where files will be synchronized. Each local path must have a corresponding remote path.                                      |
| `REMOTE_PATH_1` to `REMOTE_PATH_20` |                               | Up to 20 remote paths for synchronization with the Internxt service.                                                                               |
| `CRON_COMMAND_1` to `CRON_COMMAND_20` |                               | Up to 20 custom commands can be set. Details are explained at [Building and Executing Cron Commands](#custom-cron-command).                        |
| `CRON_COMMAND_FLAGS_1` to `CRON_COMMAND_FLAGS_20`  |                               | Up to 20 flags for the associated custom command can be set. Details are explained at [JSON Configuration](#json-configuration).                        |
| `CRON_SCHEDULE_1` to `CRON_SCHEDULE_20` |                               | Up to 20 schedules for the associated custom command and/or the associated local and remote path can be set. Details are explained at [Building and Executing Cron Commands](#custom-cron-command).                        |
| `ROOT_CA`                           |  `root_ca`                    | If the path to a root ca is set it will be appended to the ca-certificates.crt file to avoid "Unknown CA" errors (optional).                       |
| `TZ`                                |                               | Timezone for the application. Default is `Etc/UTC`.                                              |
| `LOG_LEVEL`                         |  `log.level`                  | Set the log level for the application. Default is `notice`. See [Log Level](#log-level) for more information.    |
| `LOG_LOGFILE_COUNT`                  | `log.file_count`          | Set the number of log files to keep. Default is `3`. If its set to a negative value it will keep all log files. See [Log File Management](#log-file-management) for more information.        |
| `LOG_MAX_LOG_SIZE`                   | `log.max_log_size`          | Set the maximum size of a single log file in bytes. Default is `10485760` (10MB). If its set to a negative value the log file size will not be limited. Instead at each startup the log file will be rotated. See [Log File Management](#log-file-management) for more information. |
| `STOPATSTART`                       |                               | If set to `true`, the container will stop after the initial synchronization. Before starting any services. Default is `false`. This is just for debugging purposes.                        |

## Docker Image

The Docker image is available on Docker Hub under the name `cgfm/internxt-cli_rclone`.

## Running the Container

### Docker Run Command

You can run the Docker container using the following command:

```bash
docker run -v /path/to/local/config:/config \
           -v /path/to/local/data:/data \
           -v /path/to/local/logs:/logs \
           --name internxt-cli_container \
           -e INTERNXT_EMAIL="your_email@example.com" \
           -e INTERNXT_PASSWORD="your_password" \
           -e CRON_SCHEDULE="*/15 * * * *" \
           -e REMOTE_PATH_1="remote:path1" \
           -e LOCAL_PATH_1="/local/path1" \
           -e TZ="Europe/Berlin" \
           -p 3005:3005 \
           -p 5572:5572 \
           -p 53682:53682 \
           cgfm/internxt-cli_rclone
```

### Docker Compose Example

Here’s an example of how to use Docker Compose to run the container:

```yaml
version: '3.8'

services:
  internxt-cli:
    container_name: internxt-cli_rclone 
    image: cgfm/internxt-cli_rclone
    environment:
      INTERNXT_EMAIL: your_email@example.com
      INTERNXT_PASSWORD: your_password
      CRON_SCHEDULE: '*/15 * * * *'
      REMOTE_PATH_1: remote:path1
      LOCAL_PATH_1: /local/path1
      TZ: "Europe/Berlin"
    ports:
      # Internxt WebDAV 
      - "3005:3005"
      # rClone webgui 
      - "5572:5572"
      # rClone ssh
      - "53682:53682"
    volumes:
      - /local/config/dir:/config
      - /local/data/dir:/data
      - /local/logs/dir:/logs
    restart: unless-stopped
```

## Directory Structure

### Overview

This application utilizes two primary directories—`/config` and `/data`—to manage configurations and persistent data effectively. Understanding the purpose of each directory helps ensure the application runs smoothly and that data is preserved across container restarts.

### `/data` Directory

- **Purpose**: The `/data` directory is used to store persistent data related to the Internxt CLI.
- **Initialization Process**:
  - On the first run of the container, the `entrypoint.sh` script checks for the existence of the `init_done` file in the `/data` directory to determine if the initialization process has already occurred.
  - If the `init_done` file does not exist, the script performs the following actions:
    - Copies the `config.webdav.inxt` file from `/root/.internxt-cli` to `/data`. This file contains the WebDAV configuration for the Internxt service.
    - Copies the `internxt-cli-drive.sqlite` database file from `/root/.internxt-cli` to `/data`. This database stores important data for the Internxt CLI.
    - Copies the entire `logs` directory from `/root/.internxt-cli` to `/config/log/internxt`, allowing for access to logs related to the Internxt CLI.

  - After copying these files, the script creates a file named `init_done` in the `/data` directory to signal that the initialization has been completed.

- **Subsequent Runs**:
  - On subsequent container runs, if the `init_done` file exists, the initialization process will be skipped. This prevents overwriting existing configurations and data.
  
### `/config` Directory

- **Purpose**: The `/config` directory is used to store configuration files for the application.
- **Contents**:
  - **rClone Conf**: By default the rClone conf will be stored here to let the remotes be stored persistent.
  - **config json**: By default the config.json will be stored here.

### `/logs` Directory

- **Purpose**: The `/logs` directory is used to store log files for the application.
- **Contents**:
  - **Logs**: The application writes logs to `/logs`, which allows for monitoring and debugging.
  - **Internxt Logs**: The logs related to the Internxt CLI are specifically stored in `/logs/internxt`, which is created during the first run if it does not already exist.

### `/root/.ssh` Directory

- **Purpose**: The `/root/.ssh` directory is used to store ssh keys. These are used for SFTP access with rClone.
- **Contents**:
  - **id_rsa**: This is typically the private key for SSH access. 
  - **id_rsa.pub**: This is typically the public key for SSH access. 

## Building and Executing Cron Commands
### Cron Command
The `CRON_COMMAND` environment variable allows you to specify a custom command that will be executed by cron based on the defined schedule. If no command is provided, the default command used is:

```
rclone copy
```

The `CRON_COMMAND_FLAGS` environment variable allows you to specify additional flags for the command. If no flags are provided, the default flags used are:

```
 --create-empty-src-dirs --retries 5
```

**Notice:** You cant -v or --verbose in your flags as it will cause the cron job to fail. The parameter --log-level is allways appended to rclone commands. If -v and --log-level is set, rClone will fail with the error "CRITICAL: Can't set -v and --log-level". To be sure this won't happen in the custom flags -v and --verbose will be removed from the flags. 

The cron command will be built to include all pairs of local and remote paths defined. For example, if you define `LOCAL_PATH_1` and `REMOTE_PATH_1`, the command will be constructed to run the sync between these two paths.

```
rclone copy LOCAL_PATH_1 REMOTE_PATH_1 --create-empty-src-dirs --retries 5
rclone copy LOCAL_PATH_2 REMOTE_PATH_2 --create-empty-src-dirs --retries 5
...
rclone copy LOCAL_PATH_n<=20 REMOTE_PATH_n<=20 --create-empty-src-dirs --retries 5 
```

### Custom Cron Command
The `CUSTOM_CRON_COMMAND_[1-20]` environment variables allow you to define custom cron commands. These commands will be executed in the order of the added number where numbers can be skiped. To run multiple commands before the sync commands just skip the definition of the local and remote Path.

```yaml
environment:
  ...
  REMOTE_PATH_1: remote:path1
  LOCAL_PATH_1: /local/path1
  REMOTE_PATH_2: remote:path2
  LOCAL_PATH_2: /local/path2
  CUSTOM_CRON_COMMAND_2: command 2
  CUSTOM_CRON_COMMAND_3: command 3
  CUSTOM_CRON_COMMAND_4: command 4
  REMOTE_PATH_4: remote:path4
  LOCAL_PATH_4: /local/path4
  CUSTOM_CRON_COMMAND_5: command 5
  ...
```

Will result in the following cron jobs:
```
rclone copy /local/path1 remote:path1 --create-empty-src-dirs --retries 5
command 2
rclone copy /local/path2 remote:path2 --create-empty-src-dirs --retries 5
command 3
command 4
rclone copy /local/path4 remote:path4 --create-empty-src-dirs --retries 5
command 5
```

## JSON Configuration

### Cron jobs
The cron jobs and commands you define are stored at runtime in a JSON file located at `/working/rclone_cron.json`. You can provide your own JSON file to customize the cron jobs and commands by setting the `CONFIG_FILE` environment variable to the path of your JSON file or by simply storing your JSON file at `/config/rclone_cron.json`. The structure of this JSON file allows for dynamic command execution based on the defined environment variables and the `CONFIG_FILE` file. You can Use the ENV Vars and the JSON file both at the same time. they will be combined in the `/working/rclone_cron.json` file. More about the cron jobs and commands in the [Building and Executing Cron Commands](#custom-cron-command) section.

- **cron_jobs**: This is an array containing objects for each scheduled job. Each object need to have:
  - **schedule**: The cron schedule for the job.
  - **commands**: An array of command objects to execute at the specified schedule.

### Settings
All settings listed in the ENV Vars section can be set in the JSON file as well. If an ENV Var is set, it will override the value in the JSON file. If an ENV Var is not set, the value in the JSON file will be used. If the key is not present in the JSON file, the default value will be used.

- **settings**: This object contains configuration settings that are loaded from environment variables. It's possible containing keys are listed in the [Environment Variables](#environment-variables) section above.

### Example JSON Structure

```json
{
  "cron_jobs": [
    {
      "schedule": "*/15 * * * *",
      "commands": [
        {
          "command": "rclone copy",
          "command_flags": "--create-empty-src-dirs --retries 5",
          "local_path": "/local/path1",
          "remote_path": "remote:path1"
        },
        {
          "command": "rclone copy",
          "command_flags": "--create-empty-src-dirs --retries 5",
          "local_path": "/local/path2",
          "remote_path": "remote:path2"
        }
      ]
    },
    {
      "schedule": "0 * * * *",
      "commands": [
        {
          "command": "my_backup_script.sh"
        },
        {
          "command": "rclone copy",
          "command_flags": "--create-empty-src-dirs --retries 5",
          "local_path": "/local/backup/path",
          "remote_path": "remote:backup/path"
        }
      ]
    }
  ],
  "settings": {
    "internxt": {
      "email": "your_email@example.com",
      "password": "your_password"
    },
    "rclone": {
      "config": "/config/rclone.conf"
    },
    "log": {
      "level": "notice"
    }
  }
}
```

## Execution of Cron Jobs in rclone_cron.sh

The `rclone_cron.sh` script is designed to be scheduled via cron jobs, which are defined in the system's crontab. The following command format is used to automate the execution of the script:

```shell
"$schedule root flock -n /tmp/cron.$i.lock /usr/local/bin/rclone_cron.sh \"$schedule_index_in_json_file\""
```

The `rclone_cron.sh` script is designed to automate the process of executing scheduled tasks for synchronizing files between a local filesystem and a cloud storage solution using rclone. It reads the configuration from a JSON file, executes the defined cron jobs, and logs the activity for monitoring and debugging purposes. It expects a single argument, which is the index of the schedule in the JSON file which commands to execute. 

- **Cron Job Execution**: The script is executed by cron at scheduled intervals, allowing it to automatically perform file synchronization tasks without manual intervention.
- **Logging**: The script logs all executed commands and debug information to `/log/cron.log` this will aso be prompted in the STDOUT of the container.
- **Dynamic Configuration Loading**: It reads configuration settings from the working JSON file, containing all cron commands from the `/config/config.json` and from the ENV vars.
- **Concurrency Control**: Uses file locking mechanisms to prevent concurrent executions of the same cron job, ensuring that tasks do not overlap.

To ensure the correct configuration of rclone to the command_flags of each command starting with `rclone` the following parameters will be added:
```
--log-file=$RCLONE_LOG_FILE 
--log-format=date,time,UTC
--config=$RCLONE_CONFIG
--log-level=$LOG_LEVEL (to uppercase) 
--stats=1m0s
--stats-log-level=INFO
--stats-one-line
```

## rClone Configuration

This project includes a default rClone WebDAV remote named **Internxt**, which is configured to connect to the local Internxt CLI. This setup enables seamless file management within the Internxt service.

### Default Remote Configuration

The default **Internxt** remote is configured with the following settings:
- **Type**: WebDAV
- **Vendor**: Other
- **URL**: `http://<INTERNXT_HOST>:<INTERNXT_WEB_PORT>/` or `https://<INTERNXT_HOST>:<INTERNXT_WEB_PORT>/` (depending on the value of the `INTERNXT_HTTPS` environment variable)
- **User**: Set to the value of the `INTERNXT_EMAIL` environment variable.
- **Password**: Set to the value of the `INTERNXT_PASSWORD` environment variable.

### Setting Up Additional Remotes

To set up additional remotes in rClone, you can follow these steps:

1. Open a terminal and run the following command to access the rClone configuration menu:
   ```bash
   rclone config
   ```

2. Follow the prompts to create a new remote. You will be asked to specify the type of storage and provide the necessary authentication details.

3. After completing the configuration, your new remote will be available for use in rClone commands.

### Configuring Remotes via Web GUI

If you prefer a graphical user interface, you can configure new remotes using the rClone web GUI. Here’s how:

1. Open your web browser and go to the rClone web GUI, typically at `http://<Your server IP>:<RCLONE_WEB_GUI_PORT>`.

2. Log in with your credentials if authentication is enabled.

3. Navigate to the **Configuration** section in the web GUI.

4. Select the option to add a new remote, and follow the prompts to specify the remote type and connection details.

5. Save your configuration, and the new remote will be ready for use in your rClone commands.

With the web GUI, managing your remotes becomes a straightforward process without needing to use the command line.

## SSL Configuration

### Use Case for Internxt WebDAV Certificate

The Internxt WebDAV certificate is used to secure communication between your client application (such as a web browser or another application) and the Internxt WebDAV server. This certificate ensures that the data being transmitted is encrypted and protects against potential eavesdropping or man-in-the-middle attacks. 

When you set up your Internxt WebDAV server, you should obtain a valid SSL certificate that matches the designated hostname. This certificate allows users to securely connect to the WebDAV server over HTTPS, ensuring that their credentials and data are protected during transit.

### Use Case for rclone Certificate

The rclone certificate is utilized when you run the rclone remote control daemon (rcd) with SSL enabled. This certificate secures the connection between the rclone client and the rclone server, allowing you to execute commands and transfer files securely over HTTPS. 

When configuring rclone for use with Internxt or any other service, it’s important to provide a valid SSL certificate that corresponds to the hostname specified in your rclone configuration. This ensures that the communication remains encrypted and secure.

### Important Note on Certificates

In addition to being valid for the designated hostname, the provided SSL certificates must also be valid for `localhost`. This is crucial to allow a secure connection between rclone and the Internxt CLI when running locally. Since both services can only operate over HTTP or HTTPS, having valid certificates for `localhost` ensures that you can successfully establish a secure connection without encountering SSL errors.

Make sure to test your SSL configuration thoroughly to confirm that all services can communicate securely using the specified certificates.

## Health Check Script

The `health_check.sh` script ensures the operational status of the Internxt application and the rclone Web GUI. It performs the following checks:

- Verifies if the Internxt service is running.
- Checks the accessibility of the rclone Web GUI over HTTP or HTTPS.
- Confirms the cron service is active and verifies that the specified cron jobs are configured (only if `CRON_SCHEDULE` is set).

This script provides essential diagnostics for maintaining system health and service availability.

## Logging Overview

The application includes a robust logging mechanism that allows you to control the verbosity of log output and manage log files effectively. The logging behavior can be configured through various environment variables or JSON keys. Below are the key configurations you can set:

### Log Level

- **Environment Variable**: `LOG_LEVEL`
- **JSON Key**: `log.level`
- **Description**: This variable sets the log level for the application. The default log level is `notice`, which means that only informational messages and above (like warnings and errors) will be logged. 
- **Possible Values**:
  - `fine`: Very detailed logging, useful for debugging.
  - `debug`: Less detailed than `fine`, but still verbose.
  - `notice`: General information about the application's operations (default).
  - `error`: Only error messages are logged.
  
  It's recommended to set the log level using the environment variable. If not set, the application will log entries at the default level (`notice`) until the JSON configuration file is loaded.

### Log File Management

The application provides options to manage log files, including the number of files to keep and their maximum size.

- **Environment Variable**: `LOG_LOGFILE_COUNT`
- **JSON Key**: `log.file_count`
- **Description**: This variable determines the number of log files to retain. The default value is `3`. If set to a negative value, all log files will be preserved.

- **Environment Variable**: `LOG_MAX_LOG_SIZE`
- **JSON Key**: `log.max_log_size`
- **Description**: This variable sets the maximum size (in bytes) for a single log file. The default size is `10485760` (10MB). If set to a negative value, there will be no size limit.

  When the log file exceeds the specified size, it will be rotated. For example, if you have set the maximum size to `10MB` and the logfile count to `3`, the application will keep the original log file and up to three older versions. Each of these can be up to `10MB` in size, leading to a potential total log size of `4 x 10MB = 40MB`.

### Example Usage

To configure logging, you can set the environment variables when running the application. Here’s an example:

```bash
docker run -e LOG_LEVEL="info" -e LOG_LOGFILE_COUNT="5" -e LOG_MAX_LOG_SIZE="20971520" ...
```

This command sets the log level to debug, keeps up to 5 log files, and limits each log file to 20MB.

## License

This code was generated with the help of Workik AI. The licensing model for the code generated with Workik AI is set to be permissive, allowing for modification and redistribution.

## Links

- [Internxt CLI Documentation](https://github.com/internxt/cli)
- [rclone Documentation](https://rclone.org/docs/)
