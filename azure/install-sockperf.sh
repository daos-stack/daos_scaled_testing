#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

tmp_dir="$(realpath -s "${1:?"Temporary building directory undefined"}")"
source_dir="$tmp_dir/sockperf/"
build_dir="$source_dir/tmp/build/"
install_dir="$source_dir/tmp/local/"

sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y git gcc gcc-c++ ncurses-devel automake autoconf libtool

if [[ -e "$source_dir" ]] ; then
	rm -fr "$source_dir"
fi
mkdir -p "$source_dir"

cd "$tmp_dir"
git clone https://github.com/mellanox/sockperf

cd "$source_dir"
if [[ ! -f configure ]] ; then
	./autogen.sh
fi

mkdir -p "$build_dir"
mkdir -p "$install_dir"

cd "$build_dir"
"$source_dir/configure" --prefix="$install_dir"
make -j $(nproc) install

$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES mkdir -p "$HOME/local"
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES --verbose --copy --dest "$HOME" "$install_dir"
