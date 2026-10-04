#!/bin/sh

if [ "$RM_INSTALL_FOLDER" = 1 ] && [ -d "${GALETTE_INSTALL}/install" ]; then
    echo "* Removing install folder ..."
    rm -rf "${GALETTE_INSTALL}/install"
fi

supercronic /etc/galette-cron &

exec apachectl -D FOREGROUND
