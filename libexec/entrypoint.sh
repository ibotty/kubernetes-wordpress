#!/bin/bash -e
. /opt/app-root/etc/generate_container_user
. /opt/app-root/etc/scl_enable

STRING_KEYS="DB_NAME DB_USER DB_HOST DB_CHARSET DB_COLLATE"
TO_GENERATE_KEYS="AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT DB_PASSWORD"

log() {
    echo >&2 $@
}

rand_val() {
    head -c 256k /dev/urandom | sha256sum | cut -f1 -d' '
}

wordpress_version() {
    grep '$wp_version ' wordpress/wp-includes/version.php | cut -d\' -f 2
}

version_gt() {
    [ "$1" != "$2" -a "$2" = "$(printf '%s\n%s\n' $1 $2 | sort -V | head -n1)" ]
}

copy_or_update_wordpress() {
    if ! [ -d /opt/app-root/src/wordpress ] \
         || version_gt $WORDPRESS_VERSION $(wordpress_version); then
        log "Copying wordpress-$WORDPRESS_VERSION"
        tar xzf /usr/src/wordpress.tar.gz -C /opt/app-root/src
    fi
}

mk_wpconfig() {
    for key in $TO_GENERATE_KEYS; do
        export WORDPRESS_$key=$(rand_val)
    done
    cp /opt/app-root/etc/wp-config.default.php \
        /opt/app-root/src/wordpress/wp-config.php
}

update_wpconfig() {
    local sedscript="$(mktemp)"

    for key in $STRING_KEYS $TO_GENERATE_KEYS; do
        eval "val=\$WORDPRESS_$key"
        if [ -n "$val" ]; then
            echo "/define('$key',/cdefine('$key','$val')"
        fi
    done >> $sedscript

    case "$WORDPRESS_WP_DEBUG" in
        y|yes|true|1)
            echo "/define('WP_DEBUG',/cdefine('WP_DEBUG',true);" >> $sedscript
            ;;
        n|no|false|0)
            echo "/define('WP_DEBUG',/cdefine('WP_DEBUG',false);" >> $sedscript
            ;;
        "")
            ;;
        *)
            err "cannot parse \$WP_DEBUG: \"$WP_DEBUG\". Ignoring"
            ;;
    esac

    if [ -n "$WORDPRESS_TABLE_PREFIX" ]; then
        echo "/\$table_prefix = /c\$table_prefix = $WORDPRESS_TABLE_PREFIX;" >> $sedscript
    fi

    if [ -s "$sedscript" ]; then
        sed -i -f $sedscript /opt/app-root/src/wordpress/wp-config.php
    fi

    rm $sedscript
}

mk_nginx_conf() {
    cp /opt/app-root/etc/nginx.conf /opt/app-root/src/nginx.conf
}

mk_nginx_conf

copy_or_update_wordpress

if ! [ -f /opt/app-root/src/wordpress/wp-config.php ]; then
    mk_wpconfig
fi
update_wpconfig

exec "$@"
