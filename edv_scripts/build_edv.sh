#! /bin/bash

echo -e "\n************************* Testing patch **************************\n\n"
patch -p1 -N --dry-run --silent < /opt/crtdc/daos/master/patches/edv_build_latest.patch 2>/dev/null

if [ $? -eq 0 ]; then
	echo -e "\n*****************Applying patch***************\n"
	patch -p1 < /opt/crtdc/daos/master/patches/edv_build_latest.patch
else
	echo -e "\n********************Patch Already Applied*****************\n"
fi

if [ ! -z $1 ]; then
	echo -e "\n****** Install in prefix ******\n"
	scons-3 -c && scons-3 EXCLUDE=psm2 --build-deps=yes PREFIX=$1 install
else
	echo -e "\n****** Install in-place ******\n"
	scons-3 -c && scons-3 EXCLUDE=psm2 --build-deps=yes install
fi
