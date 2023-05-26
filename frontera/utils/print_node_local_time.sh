#!/bin/bash
#
# Print the local time on a node.
#

echo "$(hostname) $(date +%m/%d/%G-%H:%M:%S.%N)"

