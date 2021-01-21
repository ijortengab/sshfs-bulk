_new_arguments=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --interactive|-i) interactive=1; shift ;;
        --last-one|-l) through=0; shift ;;
        --preview|-p) preview=1; shift ;;
        --quiet|-q) verbose=0; shift ;;
        --style=*|-s=*) style="${1#*=}"; shift ;;
        --style|-s) if [[ ! $2 == "" && ! $2 =~ ^-[^-] ]]; then style="$2"; shift; fi; shift ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done

set -- "${_new_arguments[@]}"

_new_arguments=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -[^-]*) OPTIND=1
            while getopts ":ilpqs:" opt; do
                case $opt in
                    i) interactive=1 ;;
                    l) through=0 ;;
                    p) preview=1 ;;
                    q) verbose=0 ;;
                    s) style="$OPTARG" ;;
                esac
            done
            shift "$((OPTIND-1))"
            ;;
        *) _new_arguments+=("$1"); shift ;;
    esac
done

set -- "${_new_arguments[@]}"

unset _new_arguments
