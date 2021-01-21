#!/bin/bash
touch ../rcm.sh
chmod +x ../rcm.sh
SOURCE=$(<rcm.dev.sh)
echo "${SOURCE}" > ../rcm.sh
# Delete line.
sed -i '/var-dump\.function\.sh/d' ../rcm.sh
sed -i '/VarDump/d' ../rcm.sh
# Add to $PATH
[ -d ~/bin ] && cp -r ../rcm.sh ~/bin/rcm
