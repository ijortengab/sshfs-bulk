_new_arguments=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --preview|-p) preview=1; shift ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done

set -- "${_new_arguments[@]}"

unset _new_arguments
