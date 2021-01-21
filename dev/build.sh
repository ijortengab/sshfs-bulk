#!/bin/bash
# Generate code.
chmod +x rcm.options.sh
. rcm.options.sh
touch ../rcm.sh
chmod +x ../rcm.sh
SOURCE=$(<rcm.dev.sh)
FILE_PARSE_OPTIONS=$(<rcm.parse_options.sh)
FILE_FUNCTIONS=$(<rcm.functions.sh)
SOURCE="${SOURCE//source \$(dirname \$0)\/rcm.parse_options.sh/$FILE_PARSE_OPTIONS}"
SOURCE="${SOURCE//source \$(dirname \$0)\/rcm.functions.sh/$FILE_FUNCTIONS}"
echo "${SOURCE}" > ../rcm.sh
# Delete line.
sed -i '/var-dump\.function\.sh/d' ../rcm.sh
sed -i '/rcm\.debug\.sh/d' ../rcm.sh
sed -i '/VarDump/d' ../rcm.sh
