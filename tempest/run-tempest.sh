#!/bin/bash

set -x

DEBUG=${DEBUG:-"false"}
INSTALL_TEMPEST=${INSTALL_TEMPEST:-"true"}
TEMPEST_CONF=${TEMPEST_CONF:-"/home/ubuntu/tempest/tempest.conf"}
WHITELIST_FILE=${WHITELIST_FILE:-''}
BLACKLIST_FILE=${BLACKLIST_FILE:-''}
TEMPEST_PARAMS=${TEMPEST_PARAMS:-''}
TEMPEST_BRANCH=${TEMPEST_BRANCH:-'master'}

COMMAND=""

if [ ! "$(which tempest)" ] && [ "${INSTALL_TEMPEST}" = "true" ]; then
    sudo pip install -q "git+https://github.com/openstack/tempest@${TEMPEST_BRANCH}"
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

if [ -n "${TEMPEST_PARAMS}" ]; then
    COMMAND+=" ${TEMPEST_PARAMS} "
fi

tempest run $COMMAND
