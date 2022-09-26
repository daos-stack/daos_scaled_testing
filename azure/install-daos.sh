#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

echo
echo "[INFO] Base VM config"
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf clean all
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf makecache
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf --assumeyes install dnf-plugins-core
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf config-manager --save --setopt=assumeyes=True
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf config-manager --save --setopt=fastestmirror=True
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf install epel-release
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf config-manager --enable epel
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf config-manager --set-enabled powertools
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf clean all
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf -y install createrepo_c

echo
echo "[INFO] Setting up DAOS-2.0 official repo"
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo wget -O /etc/yum.repos.d/daos-packages-2.0.repo https://packages.daos.io/v2.0/CentOS8/packages/x86_64/daos_packages.repo
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo rpm --import https://packages.daos.io/RPM-GPG-KEY
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf config-manager --set-disabled daos-packages

for branch_name in master ec_rotations ; do
	echo
	echo "[INFO] Setting up DAOS repo of branch: $branch_name"
	$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo rm -fr "/opt/repos/daos/$branch_name/x86_64"
	$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo mkdir -p "/opt/repos/daos/$branch_name/x86_64"
	cat "$CWD/files/daos-$branch_name-el8.txz" | $CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES "sudo bash -c 'tar xvJf - --strip-components=1 --directory=/opt/repos/daos/$branch_name/x86_64'"
	$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo createrepo "/opt/repos/daos/$branch_name/x86_64"
	cat "$CWD/files/daos-$branch_name.repo" | $CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES "sudo bash -c 'cat > /etc/yum.repos.d/daos-$branch_name.repo'"
done

$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf clean all
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf makecache

echo
echo "[INFO] Removing old DAOS install"
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo dnf autoremove daos-server
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES -x $SERVER_NODES sudo dnf autoremove daos-client daos-client-tests

echo
echo "[INFO] Install of DAOS"
# $CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf config-manager --set-enabled daos-packages
# $CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf config-manager --set-enabled daos-ec_rotations
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf config-manager --set-enabled daos-master

$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf clean all
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf makecache

$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo dnf install -y daos-server
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES -x $SERVER_NODES sudo dnf install -y daos-client daos-client-tests

$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo daos_server storage prepare --nvme-only -u root
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo daos_server storage scan

$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo sysctl "vm.nr_hugepages=$SYS_HUGEPAGES_NB"
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sysctl vm.nr_hugepages
cat <<< "vm.nr_hugepages = $SYS_HUGEPAGES_NB" | $CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES "sudo bash -c 'cat > /etc/sysctl.d/50-hugepages.conf'"
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES cat /etc/sysctl.d/50-hugepages.conf
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo sysctl -p

cat "$CWD/files/daos_server.service" | $CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES "sudo bash -c 'cat > /usr/lib/systemd/system/daos_server.service'"
cat "$CWD/files/daos_agent.yml" | $CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES "sudo bash -c 'cat > /etc/daos/daos_agent.yml'"
generate-daos_control_cfg | $RSH_BIN $LOGIN_NODE "sudo bash -c 'cat > /etc/daos/daos_control.yml'"
cat "$CWD/generate-daos_server_cfg.sh" | $CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES "sudo env DAOS_HUGEPAGES_NB=$DAOS_HUGEPAGES_NB bash"
