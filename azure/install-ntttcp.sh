#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

tmp_dir="$(realpath -s "${1:?"Temporary building directory undefined"}")"
source_dir="$tmp_dir/ntttcp-for-linux/"
install_dir="$source_dir/bin/"

sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y git gcc

if [[ -e "$source_dir" ]] ; then
	rm -fr "$source_dir"
fi
mkdir -p "$source_dir"

cd "$tmp_dir"
git clone https://github.com/Microsoft/ntttcp-for-linux

cd "$source_dir/src/"
make -j $(nproc) ntttcp
mkdir -p "$install_dir"
env PREFIX="$install_dir" make install

$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES mkdir -p "$HOME/local/bin/"
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES --copy --dest "$HOME/local/" "$install_dir"
