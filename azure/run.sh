#!/bin/bash

# set -x
set -e
set -o pipefail

CWD="$(realpath "$(dirname $0)")"

echo
echo
echo "======================================================================================="
time bash "$CWD/run-ior.sh" hard single 2 "--dfs.dir_oclass=RP_3GX --dfs.oclass=EC_8P2GX"

echo
echo
echo "======================================================================================="
time bash "$CWD/run-ior.sh" hard shared 2 "--dfs.dir_oclass=RP_3GX --dfs.oclass=EC_8P2GX"

echo
echo
echo "======================================================================================="
time bash "$CWD/run-ior.sh" hard single 2 "--dfs.dir_oclass=RP_3GX --dfs.oclass=RP_3GX"

echo
echo
echo "======================================================================================="
time bash "$CWD/run-ior.sh" hard shared 2 "--dfs.dir_oclass=RP_3GX --dfs.oclass=RP_3GX"

echo
echo
echo "======================================================================================="
time bash "$CWD/run-ior.sh" hard single 0 "--dfs.dir_oclass=SX --dfs.oclass=SX"

echo
echo
echo "======================================================================================="
time bash "$CWD/run-ior.sh" hard shared 0 "--dfs.dir_oclass=SX --dfs.oclass=SX"

echo
echo
echo "======================================================================================="
time bash "$CWD/run-ior.sh" easy single 2 "--dfs.dir_oclass=RP_3GX --dfs.oclass=EC_8P2GX"

echo
echo
echo "======================================================================================="
time bash "$CWD/run-ior.sh" easy shared 2 "--dfs.dir_oclass=RP_3GX --dfs.oclass=EC_8P2GX"

echo
echo
echo "======================================================================================="
time bash "$CWD/run-ior.sh" easy single 2 "--dfs.dir_oclass=RP_3GX --dfs.oclass=RP_3GX"

echo
echo
echo "======================================================================================="
time bash "$CWD/run-ior.sh" easy shared 2 "--dfs.dir_oclass=RP_3GX --dfs.oclass=RP_3GX"

echo
echo
echo "======================================================================================="
time bash "$CWD/run-ior.sh" easy single 0 "--dfs.dir_oclass=SX --dfs.oclass=SX"

echo
echo
echo "======================================================================================="
time bash "$CWD/run-ior.sh" easy shared 0 "--dfs.dir_oclass=SX --dfs.oclass=SX"

echo
echo
echo "======================================================================================="
time bash "$CWD/run-mdtest.sh" hard 0

echo
echo
echo "======================================================================================="
time bash "$CWD/run-mdtest.sh" hard 2
