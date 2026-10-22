# Apache and PHP from Debian packages: the extensions come prebuilt for every
# architecture, nothing is compiled when building the image
FROM debian:trixie-slim
## The PHP version Debian trixie ships, only used to name its packages
ARG PHP_VERSION=8.4
ARG GALETTE_VERSION=1.3.1
ARG GALETTE_RELEASE=galette-${GALETTE_VERSION}

# Maintained by GrasDK for Galette community
LABEL maintainer="GrasDK"
# @author Hiob
# @author GrasDK


## Plugins versions
ARG PLUGIN_AUTO_VERSION="2.3.0"
ARG PLUGIN_EVENTS_VERSION="2.3.0"
ARG PLUGIN_FULLCARD_VERSION="2.3.0"
ARG PLUGIN_MAPS_VERSION="2.3.0"
ARG PLUGIN_OBJECTSLEND_VERSION="2.3.0"
ARG PLUGIN_PAYPAL_VERSION="2.3.0"
ARG PLUGIN_ACTIVITIES_VERSION="1.2.0"

LABEL description="PHP $PHP_VERSION / Apache 2 / $GALETTE_RELEASE"

LABEL org.opencontainers.image.source=https://github.com/galette/docker
LABEL org.opencontainers.image.description="Galette is a membership management web application towards non profit organizations."
LABEL org.opencontainers.image.licenses=GPL-3.0-or-later

ARG MAIN_PACKAGE_URL="https://galette.eu/download/"
## {name} is replaced with each plugin name, for sources with one location per
## plugin, such as the nightly builds on GitHub
ARG PLUGIN_PACKAGE_URL="https://galette.eu/download/plugins/"

## Supercronic runs scheduled tasks without root privileges
## https://github.com/aptible/supercronic/releases
ARG SUPERCRONIC_VERSION="v0.2.49"
ARG SUPERCRONIC_SHA1SUM_AMD64="e63c11a9726b775a6a11801e81af4f3fb926aa68"
ARG SUPERCRONIC_SHA1SUM_ARM64="0b6c5bb743e0b0dafed1132198c81807927ac413"
ARG SUPERCRONIC_SHA1SUM_ARM="c98e10fc30de1147bfef8d7f2722f43c0db04fe5"
## Set by buildx for each platform
ARG TARGETARCH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install Apache, PHP and its extensions, in a single layer
## Debian security updates published after the base image are applied first.
## gettext, iconv, ctype, fileinfo, posix and sodium come with php-common.
## Debian disables the session garbage collector and leaves it to a cron job
## that does not run in the container: turn it back on.
## Logs go to the container output, as with the official php image.
## Apache runs as www-data, which must own its runtime directories.
## SC2016: the single-quoted $ belong to php, not to the shell
# hadolint ignore=SC2016
RUN apt-get -y update \
  && apt-get -y upgrade \
  && apt-get install --no-install-recommends -y \
  apache2 \
  bzip2 \
  ca-certificates \
  curl \
  libapache2-mod-php${PHP_VERSION} \
  php${PHP_VERSION}-cli \
  php${PHP_VERSION}-curl \
  php${PHP_VERSION}-gd \
  php${PHP_VERSION}-intl \
  php${PHP_VERSION}-mbstring \
  php${PHP_VERSION}-mysql \
  php${PHP_VERSION}-opcache \
  php${PHP_VERSION}-pgsql \
  php${PHP_VERSION}-xml \
  tzdata \
  && php -r 'foreach (["ctype", "curl", "dom", "fileinfo", "gd", "gettext", "iconv", "intl", "mbstring", "mysqli", "pdo_mysql", "pdo_pgsql", "posix", "SimpleXML", "sodium", "xmlreader", "xmlwriter", "Zend OPcache"] as $e) { extension_loaded($e) || exit(1); }' \
  && printf 'session.gc_probability = 1\n' > "/etc/php/${PHP_VERSION}/mods-available/galette.ini" \
  && phpenmod galette \
  && a2enmod rewrite \
  && ln -sfT /dev/stderr /var/log/apache2/error.log \
  && ln -sfT /dev/stdout /var/log/apache2/access.log \
  && ln -sfT /dev/stdout /var/log/apache2/other_vhosts_access.log \
  && chown -R --no-dereference www-data:www-data /var/log/apache2 /var/run/apache2 /var/lock/apache2 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Enabling apache vhost
COPY vhost.conf /etc/apache2/sites-available/vhost.conf
RUN a2dissite 000-default && a2ensite vhost.conf

# ENVIRONMENT VARIABLES
## Galette ENV
ENV GALETTE_CONFIG=/var/www/galette/config
ENV GALETTE_DATA=/var/www/galette/data
ENV GALETTE_INSTALL=/var/www/galette
ENV GALETTE_WEBROOT=/var/www/galette/webroot
ENV RM_INSTALL_FOLDER=0

# Changing DOCUMENT ROOT
RUN mkdir $GALETTE_INSTALL
ENV APACHE_DOCUMENT_ROOT=$GALETTE_INSTALL

## Galette ships .htaccess files that deny access to its private folders
RUN sed -ri -e "s!/var/www/html!${APACHE_DOCUMENT_ROOT}!g" /etc/apache2/sites-available/*.conf \
 && sed -ri -e "s!/var/www/!${APACHE_DOCUMENT_ROOT}!g" /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf \
 && printf '<Directory %s>\n\tOptions -Indexes\n\tAllowOverride All\n</Directory>\n' "${APACHE_DOCUMENT_ROOT}" \
    > /etc/apache2/conf-available/galette.conf \
 && a2enconf galette

## Timezone
ENV TZ=Europe/Paris
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Installation Galette and plugins
# Download, extract and remove archives in a single layer, so they do not remain in the image
## Galette
## bin/console is shipped next to the galette directory, and finds it from its own location
WORKDIR /usr/src
RUN curl -fsSLO "${MAIN_PACKAGE_URL}${GALETTE_RELEASE}.tar.bz2" \
 && tar jxf ${GALETTE_RELEASE}.tar.bz2 \
 && mv ${GALETTE_RELEASE}/galette/* ${GALETTE_INSTALL} \
 && mv ${GALETTE_RELEASE}/bin /var/www/bin \
 && rm -rf ${GALETTE_RELEASE} ${GALETTE_RELEASE}.tar.bz2

## Official plugins
WORKDIR ${GALETTE_INSTALL}/plugins
RUN for plugin in \
      auto:${PLUGIN_AUTO_VERSION} \
      events:${PLUGIN_EVENTS_VERSION} \
      fullcard:${PLUGIN_FULLCARD_VERSION} \
      maps:${PLUGIN_MAPS_VERSION} \
      objectslend:${PLUGIN_OBJECTSLEND_VERSION} \
      paypal:${PLUGIN_PAYPAL_VERSION} \
      activities:${PLUGIN_ACTIVITIES_VERSION} \
    ; do \
      name="${plugin%%:*}"; version="${plugin##*:}"; \
      archive="galette-plugin-${name}-${version}"; \
      url="${PLUGIN_PACKAGE_URL//\{name\}/${name}}"; \
      curl -fsSLO "${url}${archive}.tar.bz2" \
      && tar jxf "${archive}.tar.bz2" \
      && rm "${archive}.tar.bz2" \
      && mv "${archive}" "plugin-${name}" \
      || exit 1; \
    done


# CRON (reminders and mailing queue)
## Run by supercronic from the entrypoint, as www-data; output goes to the container logs
RUN case "${TARGETARCH}" in \
      amd64) sum="${SUPERCRONIC_SHA1SUM_AMD64}" ;; \
      arm64) sum="${SUPERCRONIC_SHA1SUM_ARM64}" ;; \
      arm) sum="${SUPERCRONIC_SHA1SUM_ARM}" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac \
 && curl -fsSL -o /usr/local/bin/supercronic \
    "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-${TARGETARCH}" \
 && echo "${sum}  /usr/local/bin/supercronic" | sha1sum -c - \
 && chmod +x /usr/local/bin/supercronic
COPY galette-cron /etc/galette-cron

# Chown /var/www/galette
RUN chown -R www-data:www-data $GALETTE_INSTALL \
 && chmod -R 0755 $GALETTE_DATA

# Mount volumes
VOLUME $GALETTE_DATA
VOLUME $GALETTE_CONFIG

# Working directory
WORKDIR $GALETTE_INSTALL

# Entrypoint
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod -v +x /entrypoint.sh
USER www-data:www-data
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
