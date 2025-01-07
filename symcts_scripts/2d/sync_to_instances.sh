#!/bin/bash

SCRIPT_DIR=$(dirname $(realpath $0))

SSH_CONFIG_PATH="$SCRIPT_DIR/ssh_config"
HOSTS=($(grep -oP 'Host \K.*' $SSH_CONFIG_PATH))

FUZZBENCH_ROOT_DIR=$(realpath "$SCRIPT_DIR/../../fuzzbench")

for host in ${HOSTS[@]}
do
    echo "Syncing to $host"
    rsync -raz --exclude=.venv "$FUZZBENCH_ROOT_DIR/" "$host:~/lukas/research/mctsse/repos/fuzzbench/"
    rsync -raz ~/.ssh/id_rsa "$host:~/.ssh/"
done