#!/bin/bash

DAOS_CONTAINER_NAME=mdtest_easy
MDTEST_OPTS="$MDTEST_OPTS -e 0 -w 0 --dfs.cont=$DAOS_CONTAINER_NAME"
