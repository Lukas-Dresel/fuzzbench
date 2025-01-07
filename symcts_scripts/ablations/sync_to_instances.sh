#!/bin/bash

SCRIPT_DIR=$(dirname $(realpath $0))

SSH_CONFIG_PATH="$SCRIPT_DIR/ssh_config"
# HOSTS=($(grep -oP 'Host \K.*' $SSH_CONFIG_PATH))
HOSTS=()
for i in $(seq 1 3); do HOSTS+=("symcts-ablations-$i"); done

FUZZBENCH_ROOT_DIR=$(realpath "$SCRIPT_DIR/../../")

set -x
for host in ${HOSTS[@]}
do
    echo "Syncing to $host"
    rsync -ravz --exclude=generated.mk --exclude=.venv "$FUZZBENCH_ROOT_DIR/" "$host:/nvme/lukas/mctsse/repos/fuzzbench-ablations/"
    rsync -raz ~/.ssh/id_rsa "$host:~/.ssh/"
    rsync -raz "$SCRIPT_DIR/.bash_aliases" "$host:~/"
done