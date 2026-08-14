> [!NOTE]
> This repository is community-maintained, and not part of Galette project.

![Docker Stars](https://img.shields.io/docker/stars/galette/galette.svg) ![Docker Pulls](https://img.shields.io/docker/pulls/galette/galette.svg) ![Docker Automated](https://img.shields.io/docker/automated/galette/galette.svg)
# Galette using Docker

Current repository hosts sources of the [Galette docker image](https://hub.docker.com/repository/docker/galette/galette).

## Contributing
If you want to contribute to containerized galette, take a look [here](./CONTRIBUTING.md).

## Features
* integrated plugins : [events](https://github.com/galette/plugin-events), [fullcard](https://github.com/galette/plugin-fullcard), [maps](https://github.com/galette/plugin-maps), [objectslend](https://github.com/galette/plugin-objectslend) and [paypal](https://github.com/galette/plugin-paypal)
* mount volume to keep persistent database settings (*config.inc.php*)
* keep data (images, logs, etc) persistent by mounting volumes
* enabling Log IP addresses behind a proxy (*optional*)
* customize your CSS (volume)
* user www-data instead of root
* a crontab will run `reminder.php` (with user www-data) every day at 8:30am to send reminder mail
* only webroot is exposed via Apache DocumentRoot and vhost
* you can use reverse proxy to access Galette by domain or subdomain

## Prerequisites
This docker image has no included database, so you need to have that separately. Since you probably already are running docker, take a look [here](https://mariadb.com/kb/en/installing-and-using-mariadb-via-docker/#creating-a-container) for a guide on how to run MariaDB in a container.

**Important!**: Following the instructions instructions for Galette versions earlier than 1.1.0 will **not** work, due to differences in volumes. If you are using a Galette version earlier than 1.1.0, please follow [the earlier version of these instructions](https://github.com/galette-community/docker/blob/1.0.4/README.md#how-to-use-this-image-using-docker-command-line). Instructions for version 1.0.4 should work for all ealier versions, but if you run into trouble with those, you can follow [version-specific instructions](https://github.com/galette-community/docker/tags).

## How to use this image using docker command line

Galette has a really nice installer, that runs you through database setup and initial admin user creation. The installer creates a configuration file in the `config` folder, which you should keep on a volume outside the docker image, for reuse when you upgrade to a newer version. You also have the option to create files for advanced configuration in the same `config` folder (see step 6).

Therefore it is really important that you follow this guide exactly.

If you are upgrading from an earlier version, you can skip step 1, 2 and 4 below.

1. Create folders corresponding to all the volumes in the next step.
2. Optional: Create a file `config.inc.php` in the `config` folder. You can also copy [this](.example/config/config.inc.php) and alter it to suit your configuration. You can put in your database details up front, or wait until step 4.
3. Start a container with the version of galette you want (e.g. V1.1.0) and the proper list of volumes.
    ```
    docker run  -d -p 8080:80 --name galette \
    -v  /path/to/config:/var/www/galette/config \
    -v  /path/to/data/attachments:/var/www/galette/data/attachments \
    -v  /path/to/data/cache:/var/www/galette/data/cache \
    -v  /path/to/data/files:/var/www/galette/data/files \
    -v  /path/to/data/plugins:/var/www/galette/data/plugins \
    -v  /path/to/data/logs:/var/www/galette/data/logs \
    -v  /path/to/data/photos:/var/www/galette/data/photos \
    -v  /path/to/data/templates_c:/var/www/galette/data/templates_c \
    galette/galette:1.1.0
    ```
    Remember to replace `./path/to/` with your own path.

4. Run the installer: Open a browser to http://\<ip or server name\>:8080/installer.php, e.g. [http://localhost:8080/installer.php](http://localhost:8080/installer.php) and follow the instructions.
    - Remember your database details, as you will need them in this process.

    You're done!
    
    N.B.: You can check `config.inc.php` in container.

    `docker exec galette cat /var/www/galette/config/config.inc.php`

5. As a security precaution, you should delete the galette installation files **after** you finished installing or upgrading. Replace `galette` with the actual container name, if you changed that in the commands above.

    `docker exec galette rm -r /var/www/galette/install`

6. Advanced configuration:

    - To change some default behavior of Galette, add `behavior.inc.php` to your `config` folder (same folder as `config.inc.php`). You can start with a copy of [this file](./.example/config/behavior.inc.php). You can change most things listed [here](https://doc.galette.eu/en/master/usermanual/avancee.html#behavior), among them:
        - session timeout
        - logging of IP's behind a proxy
        - operation mode

    - Galette provides a parameterized CSV exports system. Only one parameterized export is provided, but you can add your own: Add `exports.yaml` to your `config` folder (same folder as `config.inc.php`). Read [here](https://doc.galette.eu/en/master/usermanual/avancee.html#csv-exports) for more info.

    - To provide your own CSS styling for galette, create a `galette_local.css` on your host system, and add the folloing volume to your container parameters:

        `-v ./path/to/galette_local.css:/var/www/galette/webroot/themes/default/galette_local.css`

        Remember to replace `./path/to/` with your own path. Read [here](https://doc.galette.eu/en/master/usermanual/avancee.html#adapt-to-your-graphical-chart) for more info on the styling.

### Configure plugins
From the main page of galette, click the plugin icon and manage the built-in modules. You can disable/enable them an initialize their database configuration from the UI.

## How to use this image using Docker Compose
1. Copy [`docker-compose/galette/docker-compose.yml`](docker-compose/galette/docker-compose.yml) and [`docker-compose/galette/.env`](docker-compose/galette/.env) to the folder, where you want to persist your configuration.
2. Optionally edit the values in `.env`
3. Create a `config` folder and optionally add a `config.inc.php` file to that folder. You can copy the one from [here](.example/config/config.inc.php) and adjust it.
4. Launch with `docker-compose up -d`
5. Go to http://localhost:8080/installer.php and complete installation (database, etc).
    - Note that http://localhost:8080 will report a failure, but adding /installer will work.

You're done.

5. See above for deleting the install folder, advanced configuration and plugin configuration! In the docker compose example file, there are commented out lines for the css volume.

## How to use this image AND a mariadb image using Docker Compose
1. Copy [`docker-compose/galette-and-mariadb/docker-compose.yml`](docker-compose/galette-and-mariadb/docker-compose.yml) and [`docker-compose/galette-and-mariadb/.env`](docker-compose/galette-and-mariadb/.env) to the folder, where you want to persist your configuration.
    - Note: The official mariadb docker image LTS version `10.11` is currently not released for `arm/v7` so it can't be used for e.g. RaspBerry Pi 32 bit. However, you can switch to this unofficial mariadb-image instead: `jbergstroem/mariadb-alpine:10.11.5`.
2. Edit the `env` file to set your database configuration. **Don't** skip this.   
3. Continue with the rest of the steps above

- MariaDB takes some time to start, so have patience. 
- MariaDB and Galette will be running in two different containers. The MariaDB exposes its standard port 3306 according to the compose-configuration, so you can connect using the IP or hostname of the docker host, when you enter the database details in the galette installer.

## Reverse proxy
### Nginx

An [example of reverse proxy configuration for Nginx](.example/nginx/nginx.conf) is provided.
