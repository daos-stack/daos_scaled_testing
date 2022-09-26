#!/bin/bash

DAOS_CONTAINER_NAME=ior_easy_single
IOR_OPTS="$IOR_OPTS -F --dfs.cont=$DAOS_CONTAINER_NAME"
