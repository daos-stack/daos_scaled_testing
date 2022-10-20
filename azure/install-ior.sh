#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

tmp_dir="$(realpath -s "${1:?"Temporary building directory undefined"}")"
source_dir="$tmp_dir/ior/"
build_dir="$source_dir/tmp/build/"
install_dir="$source_dir/tmp/local/"

sudo dnf clean all
sudo dnf makecache
sudo dnf --assumeyes install dnf-plugins-core
sudo dnf config-manager --save --setopt=fastestmirror=True
sudo dnf install -y epel-release
sudo dnf config-manager -y --enable epel
sudo dnf config-manager -y --set-enabled powertools
sudo dnf clean all
sudo dnf install -y createrepo_c

sudo wget -O /etc/yum.repos.d/daos-packages-2.0.repo https://packages.daos.io/v2.0/CentOS8/packages/x86_64/daos_packages.repo
sudo rpm --import https://packages.daos.io/RPM-GPG-KEY
sudo dnf config-manager --set-disabled daos-packages

for branch_name in master ec_rotations ; do
	sudo rm -fr "/opt/repos/daos/$branch_name/x86_64"
	sudo mkdir -p "/opt/repos/daos/$branch_name/x86_64"
	cat "$CWD/files/daos-$branch_name-el8.txz" | sudo tar xvJf - --strip-components=1 --directory="/opt/repos/daos/$branch_name/x86_64"
	sudo createrepo "/opt/repos/daos/$branch_name/x86_64"
	cat "$CWD/files/daos-$branch_name.repo" | sudo bash -c "cat > /etc/yum.repos.d/daos-$branch_name.repo"
done

sudo dnf clean all
sudo dnf makecache
sudo dnf autoremove -y daos-devel daos-client daos mpich mpich-devel hdf5-mpich
sudo dnf config-manager --set-enabled daos-master

sudo dnf clean all
sudo dnf makecache
sudo dnf install -y daos-devel daos-client daos mpich mpich-devel hdf5-mpich
sudo dnf install -y git

if [[ -e "$source_dir" ]] ; then
	rm -fr "$source_dir"
fi
mkdir -p "$source_dir"

cd "$tmp_dir"
git clone https://github.com/hpc/ior.git

cd "$source_dir"
module load mpi/mpich-x86_64
if [[ ! -f configure ]] ; then
	./bootstrap
fi

mkdir -p "$build_dir"
mkdir -p "$install_dir"

cd "$build_dir"
"$source_dir/configure" --with-daos=/usr --prefix="$install_dir"
make -j $(nproc) install

$CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES sudo dnf install -y mpich
$CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES mkdir -p "$HOME/local"
$CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES --verbose --copy --dest "$HOME" "$install_dir"
