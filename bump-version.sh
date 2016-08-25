#!/bin/bash
set -euo pipefail

current_version() {
    curl -sSL http://api.wordpress.org/core/version-check/1.7 \
        | jq -r .offers[0].current
}

shasum() {
    curl -ssL "https://wordpress.org/wordpress-$1.tar.gz.sha1"
}

current="$(current_version)"
sha="$(shasum "$current")"

echo "$current $sha"

sed -i "/^ENV WORDPRESS_VERSION /cENV WORDPRESS_VERSION $current
        /^ENV WORDPRESS_SHA1 /cENV WORDPRESS_SHA1 $sha" Dockerfile
