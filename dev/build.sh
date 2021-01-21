#!/bin/bash
touch ../rcm.sh
chmod +x ../rcm.sh
SOURCE=$(<rcm.dev.sh)
FILE_FUNCTIONS=$(<rcm.functions.sh)
SOURCE="${SOURCE//source \$(dirname \$0)\/rcm.functions.sh/$FILE_FUNCTIONS}"
echo "${SOURCE}" > ../rcm.sh
# Delete line.
sed -i '/var-dump\.function\.sh/d' ../rcm.sh
sed -i '/VarDump/d' ../rcm.sh
