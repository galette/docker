ARG PHP_VERSION=8.3

# Using PHP-Apache image
FROM php:${PHP_VERSION}-apache
ARG PHP_VERSION
ARG GALETTE_VERSION=1.3.0
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

LABEL org.opencontainers.image.source=https://github.com/galette-community/docker
LABEL org.opencontainers.image.description="Galette is a membership management web application towards non profit organizations."
LABEL org.opencontainers.image.licenses=GPL-3.0-or-later

ARG MAIN_PACKAGE_URL="https://galette.eu/download/"
ARG PLUGIN_PACKAGE_URL="https://galette.eu/download/plugins/"
#ARG MAIN_PACKAGE_URL="https://download.tuxfamily.org/galette/"
#ARG PLUGIN_PACKAGE_URL="https://download.tuxfamily.org/galette/plugins/"

## Supercronic runs scheduled tasks without root privileges
## https://github.com/aptible/supercronic/releases
ARG SUPERCRONIC_VERSION="v0.2.49"
ARG SUPERCRONIC_SHA1SUM_AMD64="e63c11a9726b775a6a11801e81af4f3fb926aa68"
ARG SUPERCRONIC_SHA1SUM_ARM64="0b6c5bb743e0b0dafed1132198c81807927ac413"
ARG SUPERCRONIC_SHA1SUM_ARM="c98e10fc30de1147bfef8d7f2722f43c0db04fe5"
## Set by buildx for each platform
ARG TARGETARCH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install APT dependencies
RUN a2enmod rewrite
RUN apt-get -y update \
  && apt-get install --no-install-recommends -y \
  wget \
  libfreetype6-dev \
  libicu-dev \
  libjpeg62-turbo-dev \
  libpng-dev \
  libwebp-dev \
  libpq-dev \
  tzdata \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Install, Configure and Enable PHP extensions
## opcache is always built in since PHP 8.5
RUN docker-php-ext-install "-j$(nproc)" gettext intl && \
  { php -m | grep -q "Zend OPcache" || docker-php-ext-install opcache; } && \
  docker-php-ext-install mysqli pdo pdo_mysql pdo_pgsql && \
  docker-php-ext-enable mysqli && \
  docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ --with-webp=/usr/include/ && \
  docker-php-ext-install "-j$(nproc)" gd
RUN apachectl restart

# Enabling apache vhost
COPY vhost.conf /etc/apache2/sites-available/vhost.conf
RUN sed -i "s/galette.localhost/galette.${HOSTNAME}/" /etc/apache2/sites-available/vhost.conf \
    && a2dissite -- * && a2ensite vhost.conf

# ENVIRONMENT VARIABLES
## Galette ENV
ENV GALETTE_CONFIG /var/www/galette/config
ENV GALETTE_DATA /var/www/galette/data
ENV GALETTE_INSTALL /var/www/galette
ENV GALETTE_WEBROOT /var/www/galette/webroot
ENV RM_INSTALL_FOLDER 0

# Changing DOCUMENT ROOT
RUN mkdir $GALETTE_INSTALL
ENV APACHE_DOCUMENT_ROOT $GALETTE_INSTALL

RUN sed -ri -e "s!/var/www/html!${APACHE_DOCUMENT_ROOT}!g" /etc/apache2/sites-available/*.conf \
 && sed -ri -e "s!/var/www/!${APACHE_DOCUMENT_ROOT}!g" /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

## Timezone
ENV TZ Europe/Paris
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Installation Galette and plugins
## Galette
WORKDIR /usr/src
RUN wget --progress=dot:giga ${MAIN_PACKAGE_URL}${GALETTE_RELEASE}.tar.bz2
## bin/console is shipped next to the galette directory, and finds it from its own location
RUN tar jxvf ${GALETTE_RELEASE}.tar.bz2; mv ${GALETTE_RELEASE}/galette/* ${GALETTE_INSTALL} ; mv ${GALETTE_RELEASE}/bin /var/www/bin ; rm ${GALETTE_RELEASE}.tar.bz2

## Official plugins
WORKDIR ${GALETTE_INSTALL}/plugins
### Auto
RUN wget --progress=dot:giga ${PLUGIN_PACKAGE_URL}galette-plugin-auto-${PLUGIN_AUTO_VERSION}.tar.bz2
RUN tar jxvf galette-plugin-auto-${PLUGIN_AUTO_VERSION}.tar.bz2; rm galette-plugin-auto-${PLUGIN_AUTO_VERSION}.tar.bz2; mv galette-plugin-auto-${PLUGIN_AUTO_VERSION} plugin-auto

### Events
RUN wget --progress=dot:giga ${PLUGIN_PACKAGE_URL}galette-plugin-events-${PLUGIN_EVENTS_VERSION}.tar.bz2
RUN tar jxvf galette-plugin-events-${PLUGIN_EVENTS_VERSION}.tar.bz2; rm galette-plugin-events-${PLUGIN_EVENTS_VERSION}.tar.bz2; mv galette-plugin-events-${PLUGIN_EVENTS_VERSION} plugin-events

### FullCard
RUN wget --progress=dot:giga ${PLUGIN_PACKAGE_URL}galette-plugin-fullcard-${PLUGIN_FULLCARD_VERSION}.tar.bz2
RUN tar jxvf galette-plugin-fullcard-${PLUGIN_FULLCARD_VERSION}.tar.bz2; rm galette-plugin-fullcard-${PLUGIN_FULLCARD_VERSION}.tar.bz2; mv galette-plugin-fullcard-${PLUGIN_FULLCARD_VERSION} plugin-fullcard

### Maps
RUN wget --progress=dot:giga ${PLUGIN_PACKAGE_URL}galette-plugin-maps-${PLUGIN_MAPS_VERSION}.tar.bz2
RUN tar jxvf galette-plugin-maps-${PLUGIN_MAPS_VERSION}.tar.bz2; rm galette-plugin-maps-${PLUGIN_MAPS_VERSION}.tar.bz2; mv galette-plugin-maps-${PLUGIN_MAPS_VERSION} plugin-maps

### ObjectsLend
RUN wget --progress=dot:giga ${PLUGIN_PACKAGE_URL}galette-plugin-objectslend-${PLUGIN_OBJECTSLEND_VERSION}.tar.bz2
RUN tar jxvf galette-plugin-objectslend-${PLUGIN_OBJECTSLEND_VERSION}.tar.bz2; rm galette-plugin-objectslend-${PLUGIN_OBJECTSLEND_VERSION}.tar.bz2; mv galette-plugin-objectslend-${PLUGIN_OBJECTSLEND_VERSION} plugin-objectslend

### Paypal
RUN wget --progress=dot:giga ${PLUGIN_PACKAGE_URL}galette-plugin-paypal-${PLUGIN_PAYPAL_VERSION}.tar.bz2
RUN tar jxvf galette-plugin-paypal-${PLUGIN_PAYPAL_VERSION}.tar.bz2; rm galette-plugin-paypal-${PLUGIN_PAYPAL_VERSION}.tar.bz2; mv galette-plugin-paypal-${PLUGIN_PAYPAL_VERSION} plugin-paypal

### Activities
RUN wget --progress=dot:giga ${PLUGIN_PACKAGE_URL}galette-plugin-activities-${PLUGIN_ACTIVITIES_VERSION}.tar.bz2
RUN tar jxvf galette-plugin-activities-${PLUGIN_ACTIVITIES_VERSION}.tar.bz2; rm galette-plugin-activities-${PLUGIN_ACTIVITIES_VERSION}.tar.bz2; mv galette-plugin-activities-${PLUGIN_ACTIVITIES_VERSION} plugin-activities


# CRON (reminders and mailing queue)
## Run by supercronic from the entrypoint, as www-data; output goes to the container logs
RUN case "${TARGETARCH}" in \
      amd64) sum="${SUPERCRONIC_SHA1SUM_AMD64}" ;; \
      arm64) sum="${SUPERCRONIC_SHA1SUM_ARM64}" ;; \
      arm) sum="${SUPERCRONIC_SHA1SUM_ARM}" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac \
 && wget -q -O /usr/local/bin/supercronic \
    "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-${TARGETARCH}" \
 && echo "${sum}  /usr/local/bin/supercronic" | sha1sum -c - \
 && chmod +x /usr/local/bin/supercronic
COPY galette-cron /etc/galette-cron

# Chown /var/www/galette
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
