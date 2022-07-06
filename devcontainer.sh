#!/bin/bash

if ! [ -x "$(command -v jq)" ]; then
    printf "\x1B[31m[ERROR] jq is not installed.\x1B[0m\n"
    exit 1
fi
OPTIND=1
VERBOSE=0

while getopts "v" opt; do
    case ${opt} in
        v ) VERBOSE=1 ;;
    esac
done

debug() {
    if [ $VERBOSE == 1 ]; then
        printf "\x1B[33m[DEBUG] ${1}\x1B[0m\n"
    fi
}

PROJECT_ROOT=$(git rev-parse --show-toplevel)
CURRENT_DIR=${PWD##*/}
echo "Using workspace ${PROJECT_ROOT}"

CONFIG_DIR=./.devcontainer
debug "CONFIG_DIR: ${CONFIG_DIR}"
CONFIG_FILE=devcontainer.json
debug "CONFIG_FILE: ${CONFIG_FILE}"
if ! [ -e "$CONFIG_DIR/$CONFIG_FILE" ]; then
    # Config file may also be ".devcontainer.json" on the project folder.
    CONFIG_DIR=.
    debug "CONFIG_DIR: ${CONFIG_DIR}"
    CONFIG_FILE=.devcontainer.json
    debug "CONFIG_FILE: ${CONFIG_FILE}"
    if ! [ -e "$CONFIG_DIR/$CONFIG_FILE" ]; then
        echo "Folder contains no devcontainer configuration"
        exit
    fi
fi

CONFIG=$(cat $CONFIG_DIR/$CONFIG_FILE | grep -v //)
debug "CONFIG: \n${CONFIG}"

cd $CONFIG_DIR

DOCKER_FILE=$(echo $CONFIG | jq -r .dockerFile)
if [ "$DOCKER_FILE" == "null" ]; then 
    DOCKER_FILE=$(echo $CONFIG | jq -r .build.dockerfile)
fi
DOCKER_FILE=$(readlink -f $DOCKER_FILE)
debug "DOCKER_FILE: ${DOCKER_FILE}"
if ! [ -e $DOCKER_FILE ]; then
    echo "Can not find dockerfile ${DOCKER_FILE}"
    exit
fi

REMOTE_USER=$(echo $CONFIG | jq -r .remoteUser)
debug "REMOTE_USER: ${REMOTE_USER}"
if ! [ "$REMOTE_USER" == "null" ]; then
    REMOTE_USER="-u ${REMOTE_USER}"
fi

ARGS=$(echo $CONFIG | jq -r '.build.args | to_entries? | map("--build-arg \(.key)=\"\(.value)\"")? | join(" ")')
debug "ARGS: ${ARGS}"

SHELL=$(echo $CONFIG | jq -r '.settings."terminal.integrated.shell.linux"')
debug "SHELL: ${SHELL}"

PORTS=$(echo $CONFIG | jq -r '.forwardPorts | map("-p \(.):\(.)")? | join(" ")')
debug "PORTS: ${PORTS}"

ENVS=$(echo $CONFIG | jq -r '.remoteEnv | to_entries? | map("-e \(.key)=\(.value)")? | join(" ")')
debug "ENVS: ${ENVS}"

TARGET_PROJECT_ROOT="/workspace/$(basename $PROJECT_ROOT)"
debug "WORK_DIR: ${WORK_DIR}"

MOUNT="${MOUNT} --mount type=bind,source=${PROJECT_ROOT},target=${TARGET_PROJECT_ROOT}"
debug "MOUNT: ${TARGET_PROJECT_ROOT}"

WORK_DIR=$(echo "$TARGET_PROJECT_ROOT${PWD#"$PROJECT_ROOT"}")
debug "WORK_DIR: ${WORK_DIR}"

echo "Building and starting container"
DOCKER_BUILD_OUTPUT=$(docker build -f $DOCKER_FILE $ARGS .)
DOCKER_IMAGE_HASH=$(echo $DOCKER_BUILD_OUTPUT | awk '/Successfully built/{print $NF}')
debug "DOCKER_IMAGE_HASH: ${DOCKER_IMAGE_HASH}"

docker run -it $REMOTE_USER $PORTS $ENVS $MOUNT -w $WORK_DIR $DOCKER_IMAGE_HASH $SHELL