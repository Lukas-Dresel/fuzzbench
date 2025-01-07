#!/bin/bash

SCRIPT_DIR=$(dirname $(realpath $0))

SSH_CONFIG_PATH="$SCRIPT_DIR/ssh_config"
# HOSTS=($(grep -oP 'Host \K.*' $SSH_CONFIG_PATH))
HOSTS=()
for i in $(seq 1 6); do HOSTS+=("symcts-2d-$i"); done

FUZZBENCH_ROOT_DIR=$(realpath "$SCRIPT_DIR/../../")

set -x
for host in ${HOSTS[@]}
do
    echo "Syncing to $host"
    rsync -ravz --exclude=.venv "$FUZZBENCH_ROOT_DIR/" "$host:~/lukas/research/mctsse/repos/fuzzbench/"
    rsync -raz ~/.ssh/id_rsa "$host:~/.ssh/"
    rsync -raz "$SCRIPT_DIR/.bash_aliases" "$host:~/"
done