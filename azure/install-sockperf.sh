#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y git gcc gcc-c++ ncurses-devel automake autoconf libtool

if [[ ! -d "$HOME/local" ]] ; then
	mkdir "$HOME/local"
fi

build_dir="${1:?"Build directory undefined"}"
if [[ -e "$build_dir" ]] ; then
	rm -fr "$build_dir"
fi
mkdir -p "$build_dir"

pushd "$build_dir"
git clone https://github.com/mellanox/sockperf
cd sockperf
if [[ ! -f configure ]] ; then
	./autogen.sh
fi
./configure --prefix=$HOME/local
make -j $(nproc) install
popd

$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES mkdir -p $HOME/local
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES --copy $HOME/local
