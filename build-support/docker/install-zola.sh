#!/usr/bin/env bash

set -e

. /build-support/shell/common/log.sh


if [ -z "${USERNAME}" ]
then
    error "Must set USERNAME environment variable"
    exit 1
fi

info "Installing Zola for blog management"
mkdir -p /opt/zola/ \
    && cd /opt \
    && git clone https://github.com/getzola/zola.git \
    && chmod -R 777 zola
sudo -Hiu $USERNAME bash -c 'cd /opt/zola && $HOME/.cargo/bin/cargo build --locked --release'
cp /opt/zola/target/release/zola /usr/bin
chown root:root /usr/bin/zola
chmod 755 /usr/bin/zola
