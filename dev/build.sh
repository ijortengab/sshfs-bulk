#!/bin/bash
touch ../rcm.sh
chmod +x ../rcm.sh
SOURCE=$(<rcm.dev.sh)
echo "${SOURCE}" > ../rcm.sh
# Add to $PATH
[ -d ~/bin ] && cp -r ../rcm.sh ~/bin/rcm
