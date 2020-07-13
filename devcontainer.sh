#!/bin/bash
OPTIND=1
DEBUG=0

while getopts "d" opt; do
    case ${opt} in
        d ) DEBUG=1 ;;
    esac
done

debug() {
    if [ $DEBUG == 1 ]; then
        printf "\x1B[33m[DEBUG] ${1}\x1B[0m\n"
    fi
}

WORKSPACE=`pwd`
CURRENT_DIR=${PWD##*/}
echo "Using workspace ${WORKSPACE}"

CONFIG_DIR=./.devcontainer
debug "CONFIG_DIR: ${CONFIG_DIR}"
CONFIG_FILE=devcontainer.json
debug "CONFIG_FILE: ${CONFIG_FILE}"
if [ ! -e "$CONFIG_DIR/$CONFIG_FILE" ]; then
    echo "Folder contains no devcontainer configuration"
    exit
fi

CONFIG=$(cat $CONFIG_DIR/$CONFIG_FILE | grep -v //)
debug "CONFIG: \n${CONFIG}"

cd $CONFIG_DIR

DOCKER_FILE=$(readlink -f $(echo $CONFIG | jq -r .dockerFile))
debug "DOCKER_FILE: ${DOCKER_FILE}"
if [ ! -e $DOCKER_FILE ]; then
    echo "Can not find dockerfile ${DOCKER_FILE}"
    exit
fi

REMOTE_USER=$(echo $CONFIG | jq -r .remoteUser)
debug "REMOTE_USER: ${REMOTE_USER}"
if [ ! -z "$REMOTE_USER" ]; then
    REMOTE_USER="-u ${REMOTE_USER}"
fi

SHELL=$(echo $CONFIG | jq -r '.settings."terminal.integrated.shell.linux"')
debug "SHELL: ${SHELL}"

PORTS=$(echo $CONFIG | jq -r '.forwardPorts | map("-p \(.):\(.)")? | join(" ")')
debug "PORTS: ${PORTS}"

ENVS=$(echo $CONFIG | jq -r '.remoteEnv | to_entries? | map("-e \(.key)=\(.value)")? | join(" ")')
debug "ENVS: ${ENVS}"

WORK_DIR="/workspaces/${CURRENT_DIR}"
debug "WORK_DIR: ${WORK_DIR}"

MOUNT="${MOUNT} --mount type=bind,source=${WORKSPACE},target=${WORK_DIR}"
debug "MOUNT: ${MOUNT}"

echo "Building and starting container"
DOCKER_IMAGE_HASH=$(docker build -q -f $DOCKER_FILE .)
debug "DOCKER_IMAGE_HASH: ${DOCKER_IMAGE_HASH}"

docker run -it $REMOTE_USER $PORTS $ENVS $MOUNT -w $WORK_DIR $DOCKER_IMAGE_HASH $SHELL