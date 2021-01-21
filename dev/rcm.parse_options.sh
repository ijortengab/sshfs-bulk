_new_arguments=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --last-one|-l) through=0; shift ;;
        --preview|-p) preview=1; shift ;;
        --quiet|-q) verbose=0; shift ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done

set -- "${_new_arguments[@]}"

_new_arguments=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -[^-]*) OPTIND=1
            while getopts ":lpq" opt; do
                case $opt in
                    l) through=0 ;;
                    p) preview=1 ;;
                    q) verbose=0 ;;
                esac
            done
            shift "$((OPTIND-1))"
            ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done

set -- "${_new_arguments[@]}"

unset _new_arguments
