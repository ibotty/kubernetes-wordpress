FROM openshift/base-centos7
MAINTAINER Tobias Florek <tob@butter.sh>

EXPOSE 9000
ENV PHP_VERSION 56
ENV PHP_SCL_PREFIX rh-php${PHP_VERSION}

RUN yum install --setopt=tsflags=nodocs -y centos-release-scl-rh \
 && rpmkeys --import  /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-SCLo \
 && yum install --setopt=tsflags=nodocs -y \
                ${PHP_SCL_PREFIX}-php-fpm \
                ${PHP_SCL_PREFIX}-php-gd \
                ${PHP_SCL_PREFIX}-php-mysqlnd \
                ${PHP_SCL_PREFIX}-php-opcache \
                nss_wrapper \
 && yum clean all \
 && echo "source scl_source enable $PHP_SCL_PREFIX" \
    >> /opt/app-root/etc/scl_enable \
 && touch /opt/app-root/etc/passwd \
 && chgrp root /opt/app-root/etc/passwd \
 && chmod g+rw /opt/app-root/etc/passwd \
 && chmod g+rwx /var/opt/rh/$PHP_SCL_PREFIX/run/php-fpm \
 && sed -i '/^upload_max_filesize /cupload_max_filesize = 256m' \
         /etc/opt/rh/rh-php56/php.ini

COPY libexec/* /usr/libexec/wordpress-container/
COPY share/* /opt/app-root/etc/

ENV WORDPRESS_VERSION 4.6
ENV WORDPRESS_SHA1 830962689f350e43cd1a069f3a4f68a44c0339c8
ENV WORDPRESS_URL https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz

# separate RUN commands to allow caching the base install
RUN curl -Lo /usr/src/wordpress.tar.gz $WORDPRESS_URL \
 && echo "$WORDPRESS_SHA1 /usr/src/wordpress.tar.gz" | sha1sum -c -

USER 1001
ENTRYPOINT /usr/libexec/wordpress-container/entrypoint.sh
CMD ["php-fpm", "-FO"]
