#!/bin/bash
WORKSPACE=`pwd`
CURRENT_DIR=${PWD##*/}
echo "Using workspace ${WORKSPACE}"

CONFIG_DIR=./.devcontainer
CONFIG_FILE=devcontainer.json
if [ ! -e "$CONFIG_DIR/$CONFIG_FILE" ]; then
    echo "Folder contains no devcontainer configuration"
    exit
fi

CONFIG=$(cat $CONFIG_DIR/$CONFIG_FILE | grep -v //)

cd $CONFIG_DIR

DOCKER_FILE=$(readlink -f $(echo $CONFIG | jq -r .dockerFile))
if [ ! -e $DOCKER_FILE ]; then
    echo "Can not find dockerfile ${DOCKER_FILE}"
    exit
fi

REMOTE_USER=$(echo $CONFIG | jq -r .remoteUser)
if [ ! -z "$REMOTE_USER" ]; then
    REMOTE_USER="-u ${REMOTE_USER}"
fi

SHELL=$(echo $CONFIG | jq -r '.settings."terminal.integrated.shell.linux"')
PORTS=$(echo $CONFIG | jq -r '.forwardPorts | map("-p \(.):\(.)")? | join(" ")')
ENVS=$(echo $CONFIG | jq -r '.remoteEnv | to_entries | map("-e \(.key)=\(.value)")? | join(" ")')
WORK_DIR="/workspaces/${CURRENT_DIR}"
MOUNT="${MOUNT} --mount type=bind,source=${WORKSPACE},target=${WORK_DIR}"

echo "Building and starting container"
DOCKER_IMAGE_HASH=$(docker build -q -f $DOCKER_FILE .)
docker run -it $REMOTE_USER $PORTS $ENVS $MOUNT -w $WORK_DIR $DOCKER_IMAGE_HASH $SHELL