ARG PHP_VERSION=8.5

# Using PHP-Apache image
FROM php:${PHP_VERSION}-apache
ARG PHP_VERSION
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

RUN a2enmod rewrite

# Install, Configure and Enable PHP extensions, in a single layer
## Debian security updates published after the base image are applied first.
## Headers and compilers are only needed to build the extensions: once built,
## only the libraries they link against are kept, and the compilers the base
## image ships for phpize go too. They accounted for most of the CVEs scanners
## report on the image, linux-libc-dev alone for two thirds of them.
## libc6-dev is named apart: PHPIZE_DEPS asks for the virtual libc-dev.
## opcache is always built in since PHP 8.5. Not checked with `php -m | grep -q`:
## grep exits on the first match, php -m then dies writing to the closed pipe,
## pipefail turns that into a failure, and building opcache again breaks.
## SC2016: the single-quoted $ belong to awk and php, not to the shell
# hadolint ignore=SC2016
RUN apt-get -y update \
  && apt-get -y upgrade \
  && apt-get install --no-install-recommends -y bzip2 tzdata \
  && savedAptMark="$(apt-mark showmanual)" \
  && apt-get install --no-install-recommends -y \
  libfreetype6-dev \
  libicu-dev \
  libjpeg62-turbo-dev \
  libpng-dev \
  libwebp-dev \
  libpq-dev \
  && docker-php-ext-install "-j$(nproc)" gettext intl \
  && { php -r 'exit(extension_loaded("Zend OPcache") ? 0 : 1);' || docker-php-ext-install opcache; } \
  && docker-php-ext-install mysqli pdo pdo_mysql pdo_pgsql \
  && docker-php-ext-enable mysqli \
  && docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ --with-webp=/usr/include/ \
  && docker-php-ext-install "-j$(nproc)" gd \
  && apt-mark auto '.*' > /dev/null \
  && printf '%s\n' "$savedAptMark" | xargs -r apt-mark manual > /dev/null \
  && printf '%s\n' "$PHPIZE_DEPS" libc6-dev | xargs -r apt-mark auto > /dev/null \
  && find "$(php-config --extension-dir)" -name '*.so' -exec ldd '{}' ';' \
    | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
    | sort -u \
    | xargs -r dpkg-query --search \
    | cut -d: -f1 \
    | sort -u \
    | xargs -r apt-mark manual > /dev/null \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && php -r 'foreach (["gd", "intl", "gettext", "mysqli", "pdo_mysql", "pdo_pgsql", "Zend OPcache"] as $e) { extension_loaded($e) || exit(1); }' \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Enabling apache vhost
COPY vhost.conf /etc/apache2/sites-available/vhost.conf
RUN a2dissite -- * && a2ensite vhost.conf

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

RUN sed -ri -e "s!/var/www/html!${APACHE_DOCUMENT_ROOT}!g" /etc/apache2/sites-available/*.conf \
 && sed -ri -e "s!/var/www/!${APACHE_DOCUMENT_ROOT}!g" /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

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
