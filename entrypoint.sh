#!/bin/sh
set -e

BIND_DATA_DIR=${DATA_DIR}/bind

create_bind_data_dir() {
    mkdir -p ${BIND_DATA_DIR}

    # populate default bind configuration if it does not exist
    if [ ! -d ${BIND_DATA_DIR}/etc ]; then
	ln -sfn /usr/share/dnssec-root/bind-dnssec-root.keys /etc/bind/bind.keys
	touch /etc/bind/named.conf
	mv /etc/bind ${BIND_DATA_DIR}/etc
    fi
    rm -rf /etc/bind
    ln -sf ${BIND_DATA_DIR}/etc /etc/bind
    chmod -R 0775 ${BIND_DATA_DIR}
    chown -R ${BIND_USER}:${BIND_USER} ${BIND_DATA_DIR}

    if [ ! -d ${BIND_DATA_DIR}/lib ]; then
	mkdir -p ${BIND_DATA_DIR}/lib
	chown ${BIND_USER}:${BIND_USER} ${BIND_DATA_DIR}/lib
    fi
    rm -rf /var/lib/bind
    ln -sf ${BIND_DATA_DIR}/lib /var/lib/bind
}

create_pid_dir() {
    mkdir -p /var/run/named
    chmod 0775 /var/run/named
    chown root:${BIND_USER} /var/run/named
}

create_bind_cache_dir() {
    mkdir -p /var/cache/bind
    chmod 0775 /var/cache/bind
    chown root:${BIND_USER} /var/cache/bind
}

create_pid_dir
create_bind_data_dir
create_bind_cache_dir

# allow arguments to be passed to named
if [[ ${1:0:1} = '-' ]]; then
    EXTRA_ARGS="$*"
    set --
elif [[ ${1} == named || ${1} == "$(command -v named)" ]]; then
    EXTRA_ARGS="${*:2}"
    set --
fi

# default behaviour is to launch named
if [[ -z ${1} ]]; then
    echo "Starting named..."
    exec "$(command -v named)" -u ${BIND_USER} -g ${EXTRA_ARGS}
else
    exec "$@"
fi
