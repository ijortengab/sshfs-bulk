#!/bin/bash
#
# RCM - Remote Connection Manager
#
# Created by: IjorTengab http://ijortengab.id
# Homepage  : https://github.com/ijortengab/rcm
#
# Convention:
# - define is UPPER_CASE, underscore, and prefix with RCM_.
# - variable is lower_case and underscore.
# - temporary variable (return string from function) prefix with _underscore.
# - function is camelCase.
# - indent is 4 spaces.
source $(dirname $0)/rcm.parse_options.sh
source $(dirname $0)/rcm.debug.sh

source $(dirname $0)/bash/functions/var-dump/dev/var-dump.function.sh
# Define.
RCM_ROOT=$HOME/.config/rcm
RCM_DIR_PORTS=$RCM_ROOT/ports
RCM_DIR_ROUTE=$RCM_ROOT/route
RCM_EXE=$RCM_ROOT/exe
RCM_PORT_START=49152

# Default value of options.
options=()
through=1
interactive=0
style=auto
public_key=auto
numbering=auto

# Default value of flag.
add_func_get_pid_cygwin=0
add_var_tunnel_success=0

source $(dirname $0)/rcm.functions.sh

# Jika tidak ada argument.
if [[ $1 == "" ]];then
    # Coming Soon.
    # clear
    exit
fi
VarDump ---
VarDump '<$1>'"$1"
arguments=("$@")
VarDump arguments
setOptions once # Parse options (locate between rcm and command).
validateArguments
setOptions # Parse options (locate after command).
validateOptions
execute
