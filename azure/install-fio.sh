#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

{
	cat <<- EOF
	set -x
	set -e
	set -o pipefail

	tmp_dir="/tmp/install-fio"
	source_dir="\$tmp_dir/src/"
	build_dir="\$tmp_dir/build/"
	install_dir="\$HOME/local/"

	sudo dnf clean all
	sudo dnf makecache
	sudo dnf --assumeyes install dnf-plugins-core
	sudo dnf config-manager --save --setopt=fastestmirror=True
	sudo dnf install -y epel-release
	sudo dnf config-manager -y --enable epel
	sudo dnf config-manager -y --set-enabled powertools

	sudo dnf clean all
	sudo dnf makecache
	sudo dnf install -y git daos-devel

	if [[ -e "\$tmp_dir" ]] ; then
		rm -fr "\$tmp_dir"
	fi
	for dir in "\$source_dir" "\$build_dir" "\$install_dir" ; do
		mkdir -p "\$dir"
	done

	cd "\$tmp_dir"
	git clone http://git.kernel.dk/fio.git "\$source_dir"

	cd "\$build_dir"
	"\$source_dir/configure" --prefix="\$install_dir"
	make -j \$(nproc) install
	EOF
} | $CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES bash -s


$CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES 'bash -c "$HOME/local/bin/fio --enghelp=dfs"'
