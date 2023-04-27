#!/bin/bash

# set -x
set -e -o pipefail

CWD="$(realpath "$(dirname $0)")"

source "$CWD/envs/env.sh"

DAOS_VERSION=${1:-master}

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
echo "[INFO] Setting up DAOS repo of branch: $DAOS_VERSION"
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo rm -fvr "/opt/repos/daos" "/etc/yum.repos.d/daos.repo"
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo mkdir -p "/opt/repos/daos/x86_64"
cat "$CWD/files/daos-$DAOS_VERSION-el8.txz" | $CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES "sudo bash -c 'tar xvJf - --strip-components=1 --directory=/opt/repos/daos/x86_64'"
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo createrepo "/opt/repos/daos/x86_64"
cat "$CWD/files/daos.repo" | $CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES "sudo bash -c 'cat > /etc/yum.repos.d/daos.repo'"

$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf clean all
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf makecache

echo
echo "[INFO] Removing old DAOS install"
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo dnf autoremove daos-server daos-debuginfo daos-server-debuginfo libfabric
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES -x $SERVER_NODES sudo dnf autoremove daos-client daos-client-tests libfabric

echo
echo "[INFO] Install of DAOS $DAOS_VERSION"
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf config-manager --set-enabled daos

$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf clean all
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES sudo dnf makecache

$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo dnf install -y daos-server daos-debuginfo daos-server-debuginfo
$CLUSH_BIN $CLUSH_OPTS -w $ALL_NODES -x $SERVER_NODES sudo dnf install -y daos-client daos-client-tests

$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo daos_server storage prepare --nvme-only -u root
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo daos_server storage scan

$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo sysctl "vm.nr_hugepages=$SYS_HUGEPAGES_NB"
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sysctl vm.nr_hugepages
cat <<< "vm.nr_hugepages = $SYS_HUGEPAGES_NB" | $CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES "sudo bash -c 'cat > /etc/sysctl.d/50-hugepages.conf'"
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES cat /etc/sysctl.d/50-hugepages.conf
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES sudo sysctl -p

cat "$CWD/files/daos_server.service" | $CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES "sudo bash -c 'cat > /usr/lib/systemd/system/daos_server.service'"
$CLUSH_BIN $CLUSH_OPTS -w $SERVER_NODES "sudo systemctl daemon-reload"
cat "$CWD/files/daos_agent.yml" | $CLUSH_BIN $CLUSH_OPTS -w $CLIENT_NODES "sudo bash -c 'cat > /etc/daos/daos_agent.yml'"
generate-daos_control_cfg | $RSH_BIN $LOGIN_NODE "sudo bash -c 'cat > /etc/daos/daos_control.yml'"
