#!/bin/bash

set -x

DEBUG=${DEBUG:-"false"}
INSTALL_TEMPEST=${INSTALL_TEMPEST:-"true"}
TEMPEST_CONF=${TEMPEST_CONF:-"/home/ubuntu/tempest.conf"}
WHITELIST_FILE=${WHITELIST_FILE:-''}
BLACKLIST_FILE=${BLACKLIST_FILE:-''}

COMMAND=""

if [ "${INSTALL_TEMPEST}" = "true" ]; then
    git clone https://github.com/openstack/tempest -b master
    pip install -q tempest/
fi

if [ "${DEBUG}" = "true" ]; then
    COMMAND+="--debug "
fi

if [ -n "${TEMPEST_CONF}" ]; then
    COMMAND+="--config-file ${TEMPEST_CONF} "
fi

if  [ -n "${WHITELIST_FILE}" ]; then
    COMMAND+="--whitelist-file ${WHITELIST_FILE} "
fi

if [ -n "${BLACKLIST_FILE}" ]; then
    COMMAND+="--blacklist-file ${BLACKLIST_FILE} "
fi

tempest run $COMMAND  > tempest-output.txt 2>&1

