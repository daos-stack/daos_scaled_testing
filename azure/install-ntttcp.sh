#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y git gcc

if [[ ! -d "$HOME/local" ]] ; then
	mkdir "$HOME/local"
fi

build_dir="${1:?"Build directory undefined"}"
if [[ -e "$build_dir" ]] ; then
	rm -fr "$build_dir"
fi
mkdir -p "$build_dir"

pushd "$build_dir"
git clone https://github.com/Microsoft/ntttcp-for-linux
cd ntttcp-for-linux/src
make -j $(nproc) ntttcp
env PREFIX=$HOME/local/bin make install
popd

$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES mkdir -p $HOME/local/bin/
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES --copy $HOME/local/bin/
