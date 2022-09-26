#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y git mpich mpich-devel

if [[ ! -d "$HOME/local" ]] ; then
	mkdir "$HOME/local"
fi

build_dir="${1:?"Build directory undefined"}"
if [[ -e "$build_dir" ]] ; then
	rm -fr "$build_dir"
fi
mkdir -p "$build_dir"

pushd "$build_dir"
git clone https://github.com/hpc/ior.git
cd ior
module load mpi/mpich-x86_64
./bootstrap
mkdir build
cd build
../configure --with-daos=/usr --prefix="$HOME/local"
make -j $(nproc)

make install
popd

$CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES sudo dnf install -y mpich
$CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES --copy $HOME/local
