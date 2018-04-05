exit
    for (( I=0; I < ${#_arguments[@]} ; I++ )); do
        O=$(( $I + 1 ))

        HOST=${_arguments[$I]}
        USER=$(echo $HOST | grep -E -o '^[^@]+@')
        if [[ $USER == "" ]];then
            USER=---
        else
            HOST=$(echo $HOST | sed 's/^'$USER'//' )
            USER=$(echo $USER | grep -E -o '[^@]+')
        fi
        PORT=$(echo $HOST | grep -E -o ':[0-9]+$')
        if [[ $PORT == "" ]];then
            PORT=22
        else
            HOST=$(echo $HOST | sed 's/'$PORT'$//' )
            PORT=$(echo $PORT | grep -E -o '[0-9]+')
        fi
        # echo $HOST
        # echo $I
        # echo
        HOSTS+=("$HOST")
        USERS+=("$USER")
        PORTS+=("$PORT")
        if [[ ! $I == $((${#_arguments[@]} - 1)) ]];then
            # Host selain yang terakhir pada argument, maka buat local portnya.
            LOCALPORT=$(getLocalPortBasedOnHost $HOST)
            LOCALPORTS+=($LOCALPORT)
        fi
    done
    
    
    # echo oi
    # echo $route
    
    # for f in "${hosts[@]}"
    # do
        # echo $f
    # done
    # for f in "${ports[@]}"
    # do
        # echo $f
    # done
    # for f in "${users[@]}"
    # do
        # echo $f
    # done
    # for f in "${local_ports[@]}"
    # do
        # echo $f
    # done
    
    
    exit
    
    # populateRoute
    for f in "${_arguments[@]}"
    do
        echo $f
    done

    
    if [[ ${#_arguments[@]} == 0 ]];then
        echo "Error. Argument tidak ada."
        return
    fi
    if [[ $(isEven ${#_arguments[@]}) == 1 ]];then
        echo "Error. Argument tidak boleh genap."
        return
    fi
    # if [[ ${#_arguments[@]} == 1 ]];then
        # echo ${_arguments[0]}
        # ssh ${_arguments[0]}
        # exit
    # fi
    # Parse Argument then populate array.
    HOSTS=()
    USERS=()
    PORTS=()
    LOCALPORTS=() # Reset
    for (( I=0; I < ${#_arguments[@]} ; I++ )); do
        O=$(( $I + 1 ))
        if [[ ${_arguments[$I]} =~ " " ]];then
            echo Error. Argument \'${_arguments[$I]}\' mengandung karakter spasi.
            return
        fi
        if [[ $(isEven $O) == 1 ]];then
            if [[ ! ${_arguments[$I]} == 'via' ]];then
                echo "Error. Argument posisi genap tidak bernilai 'via'."
                return
            fi
            continue
        fi
        HOST=${_arguments[$I]}
        USER=$(echo $HOST | grep -E -o '^[^@]+@')
        if [[ $USER == "" ]];then
            USER=---
        else
            HOST=$(echo $HOST | sed 's/^'$USER'//' )
            USER=$(echo $USER | grep -E -o '[^@]+')
        fi
        PORT=$(echo $HOST | grep -E -o ':[0-9]+$')
        if [[ $PORT == "" ]];then
            PORT=22
        else
            HOST=$(echo $HOST | sed 's/'$PORT'$//' )
            PORT=$(echo $PORT | grep -E -o '[0-9]+')
        fi
        # echo $HOST
        # echo $I
        # echo
        HOSTS+=("$HOST")
        USERS+=("$USER")
        PORTS+=("$PORT")
        if [[ ! $I == $((${#_arguments[@]} - 1)) ]];then
            # Host selain yang terakhir pada argument, maka buat local portnya.
            LOCALPORT=$(getLocalPortBasedOnHost $HOST)
            LOCALPORTS+=($LOCALPORT)
        fi
    done
    
    
    # echo test
    # echo ${#HOSTS[@]}

    echo ---------------------------
    for f in "${HOSTS[@]}"
    do
        echo $f
    done
    echo ---------------------------
    for f in "${USERS[@]}"
    do
        echo $f
    done
    echo ---------------------------
    for f in "${PORTS[@]}"
    do
        echo $f
    done
    echo ---------------------------
    for f in "${LOCALPORTS[@]}"
    do
        echo $f
    done
    echo ---------------------------

    
    
sshCommandOld () {


    # if [[ ${#_arguments[@]} == 1 ]];then
        # echo ${_arguments[0]}
        # ssh ${_arguments[0]}
        # exit
    # fi
    
    # exit
    # Create array LINES
    M=1 # Mark. Just flag for first looping.
    LINES=()
    if [[ ${#HOSTS[@]} == 1 ]];then
        LINE="ssh "
        if [[ ! ${USERS[0]} == "---" ]];then
            LINE+=${USERS[0]}
            LINE+=@
        fi
        LINE+="${HOSTS[0]}"
        if [[ ! ${PORTS[0]} == 22 ]];then
            LINE+=" -p ${PORTS[0]}"
        fi
        LINES+=("$LINE")
    fi
    if [[ ${#HOSTS[@]} > 1 ]];then
        for (( I=$(( ${#HOSTS[@]} - 1 )); I >= 0 ; I-- )); do
            LINE="ssh"
            _I=$(( $I - 1 ))
            if [[ ! $I == 0 ]];then
                LINE+=" -fN "
                if [[ ! ${USERS[$I]} == "---" ]];then
                    LINE+="${USERS[$I]}@"
                fi
                if [[ $M == 1 ]];then
                    LINE+="${HOSTS[$I]}"
                    if [[ ! ${PORTS[$I]} == 22 ]];then
                        LINE+=" -p ${PORTS[$I]}"
                    fi
                    M=0
                else
                    LINE+="localhost"
                    LINE+=" -p ${LOCALPORTS[$I]}"
                fi
                LINE+=" -L ${LOCALPORTS[$_I]}:${HOSTS[$_I]}:"
                LINE+="${PORTS[$_I]}"
            else
                LINE+=" "
                if [[ ! ${USERS[$I]} == "---" ]];then
                    LINE+="${USERS[$I]}@"
                fi
                LINE+="localhost"
                LINE+=" -p ${LOCALPORTS[$I]}"
            fi
            LINES+=("$LINE")
        done
    fi
    # Create and fill template.
    mkdir -p $HOME/.cache/rcm
    _file=$HOME/.cache/rcm/ssh
    createTemplateSsh $_file
    L=$(( ${#HOSTS[@]} - 1 )) # Just flag for the last.
    for (( I=0; I < ${#LINES[@]} ; I++ )); do
        if [[ ! $L == 0 ]];then
            NOTICE='NOTICE "Create tunnel on '
        else
            NOTICE='NOTICE "SSH connect to '
        fi
        if [[ ! ${USERS[$L]} == "---" ]];then
            NOTICE+="${USERS[$L]}@"
        fi
        NOTICE+="${HOSTS[$L]}"
        if [[ ! ${PORTS[$L]} == 22 ]];then
            LINE+=":${PORTS[$L]}"
        fi
        NOTICE+='."'
        echo $NOTICE >> $_file
        echo ${LINES[$I]} >> $_file
        let L--
    done
    M=1 # Mark. Just flag for first looping.
    F=0 # First. Just key for incremental.
    for (( I=$(( ${#LINES[@]} - 1 )); I >= 0 ; I-- )); do
        if [[ $M == 1 ]];then
            M=0
            let F++
            continue
        fi
        NOTICE='NOTICE "Destroy tunnel on '
        if [[ ! ${USERS[$F]} == "---" ]];then
            NOTICE+="${USERS[$F]}@"
        fi
        NOTICE+="${HOSTS[$F]}"
        if [[ ! ${PORTS[$F]} == 22 ]];then
            LINE+=":${PORTS[$F]}"
        fi
        NOTICE+='."'
        echo $NOTICE >> $_file
        echo 'kill $(GETPID "'${LINES[$I]}'")' >> $_file
        let F++
    done
    # Execute.
    executeTemplate $_file
}



populateRoute() {
    a=("$1")
    for f in "${a[@]}"
    do
        echo $f
    done
    exit
}

sshfsCommand () {
    for f in "${_arguments[@]}"
    do
        echo $f
    done
}
rsyncCommand () {
    for f in "${_arguments[@]}"
    do
        echo $f
    done
}
smbCommand () {
    for f in "${_arguments[@]}"
    do
        echo $f
    done
}


# Fungsi perlu perbaikan
listAllConnection() {
    cd ~/.config/RCM/enabled
    OIFS="$IFS"
    IFS=$'\n'
    for file in `find . `
    do
        case $file in
            .)
            continue
            ;;
        esac
        fileClean=$(echo $file | sed -E 's/^[./]+//g')
        if ! echo $fileClean | grep -E '\-variation\-[0-9]+$' 1>/dev/null ; then
            echo $fileClean >&2
        else
            cat $fileClean >&2
        fi
    done
    IFS="$OIFS"
    # set -- ${@:-$(</dev/stdout)}
    exit
}
# todo: dokumentasi
addNewConnection() {
while :
do
    wizardFormAddConnection
    if [[ $return == 1 ]];then
        createScript -u=$inputUsername -h=$inputHostname -p=$inputPort
        while :
        do
            echo -e "\e[92m# This connection has been added\e[39m"
            echo
            echo $contentScript
            echo
            echo "What's next?"
            echo
            echo -e "| 1 | \e[93ma\e[39mdd more connection"
            echo -e "| 2 | c\e[93ml\e[39mone this connection"
            echo -e "| 3 | \e[93ms\e[39msh connects"
            echo -e "| 4 | \e[93mc\e[39mancel"
            echo
            read -rsn1 -p "Select an option (number or yellow letter): " option
            echo
            case $option in
                1|a)
                inputUsername=
                inputHostname=
                inputPort=
                next=add
                clear
                ;;
                2|l)
                clear
                next=add
                ;;
                3|s)
                clear
                next=ssh
                ;;
                4|c)
                clear
                next=
                ;;
                *)
                clear
                continue
                ;;
            esac
            break
        done
        case $next in
            add)
            continue
            ;;
        esac
    fi
    break
done
case $next in
    ssh)
    connectSSH $contentScript
    ;;
esac
}

# return: $contentScript
createScript() {
    for i in "$@"
    do
    case $i in
        -u=*|--username=*)
        username="${i#*=}"
        shift # past argument
        ;;
        -h=*|--hostname=*)
        hostname="${i#*=}"
        shift # past argument
        ;;
        -p=*|--port=*)
        port="${i#*=}"
        shift # past argument
        ;;
        *)    # unknown option
        ;;
    esac
    done
    fileScript=0_$username@$hostname
    isVariation=0
    if [[ ! $port == 22 ]]; then
        isVariation=1
    fi
    # connections
    storageDir=~/.config/RCM/connections
    /bin/mkdir -p $storageDir
    if [[ ! $port == 22 ]]; then
        i=1
        while [[ -e $storageDir/$fileScript-variation-$i ]] ; do
            let i++
        done
        fileScript=$fileScript-variation-$i
        contentScript=$username@$hostname:$port
    else
        contentScript=$username@$hostname
    fi
    echo $contentScript > $storageDir/$fileScript
}

wizardFormAddConnectionValidate() {
    for i in "$@"
    do
    case $i in
        -u=*|--username=*)
        username="${i#*=}"
        shift # past argument
        ;;
        -h=*|--hostname=*)
        hostname="${i#*=}"
        shift # past argument
        ;;
        -p=*|--port=*)
        port="${i#*=}"
        shift # past argument
        ;;
        *)    # unknown option
        ;;
    esac
    done
    if [[ $username == "" ]];then
        echo Username tidak boleh kosong.
    fi
    if [[ $hostname == "" ]];then
        echo Hostname tidak boleh kosong.

    fi
    if [[ $port == "" ]];then
        echo Port tidak boleh kosong.
    fi
    if [[ ! $port =~ ^[0-9]+$ ]];then
        echo "Port harus berupa angka."
        exit
    fi
}
# return variable: $return=1 $inputUsername, $inputHostname, $inputPort
wizardFormAddConnection() {
return=
edit=1
while :
do
    echo -e "\e[92m# Add a new connection\e[39m"
    echo
    echo Tell me a Remote Server information.
    echo
    if [[ $edit == 1 ]];then
        if [[ ! $inputUsername == "" ]];then
            read -p "Username: " -e -i $inputUsername inputUsername
        else
            read -p "Username: " -e inputUsername
        fi
        if [[ ! $inputHostname == "" ]];then
            read -p "Hostname: " -e -i $inputHostname inputHostname
        else
            read -p "Hostname: " -e inputHostname
        fi
        if [[ ! $inputPort == "" ]];then
            read -p "Port number: " -e -i $inputPort inputPort
        else
            read -p "Port number: " -e -i 22 inputPort
        fi
    else
        echo Username: $inputUsername
        echo Hostname: $inputHostname
        echo Port number: $inputPort
    fi
    echo
    errorResult=$(wizardFormAddConnectionValidate -u=$inputUsername -h=$inputHostname -p=$inputPort)
    if [[ ! $errorResult == "" ]]; then
        echo Error ditemukan: $errorResult
        echo
        echo "What's next?"
        echo
        echo -e "| 1 | \e[93mm\e[39modify value"
        echo -e "| 2 | \e[93mc\e[39mancel"
        echo
        read -rsn1 -p "Select an option (number or yellow letter): " option
        echo
        case $option in
            1|m)
            clear
            edit=1
            continue
            ;;
            2|c)
            clear
            break
            ;;
            *)
            clear
            edit=0
            continue
        esac
    fi
    echo "Is this correct?"
    echo
    echo -e "| 1 | \e[93my\e[39mes, save"
    echo -e "| 2 | \e[93mm\e[39modify value"
    echo -e "| 3 | \e[93mc\e[39mancel"
    echo
    read -rsn1 -p "Select an option (number or yellow letter): " option
    echo
    case $option in
        1|y)
        clear
        ;;
        2|m)
        clear
        edit=1
        continue
        ;;
        3|c)
        clear
        break
        ;;
        *)
        clear
        edit=0
        continue
        ;;
    esac
    return=1
    break
done
}
# return variable: $selectedConnection
wizardFormSelectConnection() {
define=10
countAll=$(ls -U ~/.config/RCM/enabled | wc -l)
if (( $countAll > $define ));then
    list=(`ls -vr ~/.config/RCM/enabled | head -$define`)
    judul="Showing $define popular connection"
else
    list=(`ls ~/.config/RCM/enabled`)
    judul="Showing All connection"
fi
array=()
count=-1
for t in "${list[@]}"
do
    let count++
    line="| \e[93m$count\e[39m | "$(cat ~/.config/RCM/enabled/$t)
    array=("${array[@]}" "$line")
done
while :
do
    while :
    do
        echo -e "\e[92m$judul\e[39m"
        echo
        if [[ ${#array[@]} == 0 ]];then
            echo Not Found
        else
            for t in "${array[@]}"
            do
                echo -e $t
            done
        fi
        echo
        echo Guide:
        if [[ ! ${#array[@]} == 0 ]];then
            echo " - Type number of connection to select"
        fi
        if (($countAll > $define));then
            echo " - Type 'grep foo' to filter connection that contains word 'foo'"
        fi
        echo -e " - Type \e[93mc\e[39m to cancel"
        echo
        text="What's next: "
        read -p "$text" input
        case $input in
            c)
            break
            ;;
            [0-$count])
            break
            ;;
            grep*)
            clear
            break
            ;;
            *)
            clear
            continue
        esac
    done
    match='^\s*grep\s+'
    if [[ $input =~ $match ]]; then
        all=(`ls -U ~/.config/RCM/enabled`)
        array=()
        count=-1
        for a in "${all[@]}"
        do
            c=$(cat ~/.config/RCM/enabled/$a | $input)
            if [[ ! $c == "" ]];then
                let count++
                line="| \e[93m$count\e[39m | $c"
                array=("${array[@]}" "$line")
            fi
        done
        judul="Show connection filtered by: $input"
        continue
    fi
    match="^[0-9]+$"
    if [[ $input =~ $match ]]; then
        line="${array[${input}]}"
        selectedConnection=$(echo $line | sed -r 's/^\|[^|]+\|\s//')
    fi
    break
done
}
# $contentScript
connectSSH() {
    echo $1
    echo "$@"
}








    exit
    # Create array LINES
    M=1 # Mark. Just flag for first looping.
    LINES=()
    if [[ ${#HOSTS[@]} == 1 ]];then
        LINE="ssh "
        if [[ ! ${USERS[0]} == "---" ]];then
            LINE+=${USERS[0]}
            LINE+=@
        fi
        LINE+="${HOSTS[0]}"
        if [[ ! ${PORTS[0]} == 22 ]];then
            LINE+=" -p ${PORTS[0]}"
        fi
        LINES+=("$LINE")
    fi
    if [[ ${#HOSTS[@]} > 1 ]];then
        for (( I=$(( ${#HOSTS[@]} - 1 )); I >= 0 ; I-- )); do
            LINE="ssh"
            _I=$(( $I - 1 ))
            if [[ ! $I == 0 ]];then
                LINE+=" -fN "
                if [[ ! ${USERS[$I]} == "---" ]];then
                    LINE+="${USERS[$I]}@"
                fi
                if [[ $M == 1 ]];then
                    LINE+="${HOSTS[$I]}"
                    if [[ ! ${PORTS[$I]} == 22 ]];then
                        LINE+=" -p ${PORTS[$I]}"
                    fi
                    M=0
                else
                    LINE+="localhost"
                    LINE+=" -p ${LOCALPORTS[$I]}"
                fi
                LINE+=" -L ${LOCALPORTS[$_I]}:${HOSTS[$_I]}:"
                LINE+="${PORTS[$_I]}"
            else
                LINE+=" "
                if [[ ! ${USERS[$I]} == "---" ]];then
                    LINE+="${USERS[$I]}@"
                fi
                LINE+="localhost"
                LINE+=" -p ${LOCALPORTS[$I]}"
            fi
            LINES+=("$LINE")
        done
    fi
    # Create and fill template.
    mkdir -p $HOME/.cache/rcm
    _file=$HOME/.cache/rcm/ssh
    createTemplateSsh $_file
    L=$(( ${#HOSTS[@]} - 1 )) # Just flag for the last.
    for (( I=0; I < ${#LINES[@]} ; I++ )); do
        if [[ ! $L == 0 ]];then
            NOTICE='NOTICE "Create tunnel on '
        else
            NOTICE='NOTICE "SSH connect to '
        fi
        if [[ ! ${USERS[$L]} == "---" ]];then
            NOTICE+="${USERS[$L]}@"
        fi
        NOTICE+="${HOSTS[$L]}"
        if [[ ! ${PORTS[$L]} == 22 ]];then
            LINE+=":${PORTS[$L]}"
        fi
        NOTICE+='."'
        echo $NOTICE >> $_file
        echo ${LINES[$I]} >> $_file
        let L--
    done
    M=1 # Mark. Just flag for first looping.
    F=0 # First. Just key for incremental.
    for (( I=$(( ${#LINES[@]} - 1 )); I >= 0 ; I-- )); do
        if [[ $M == 1 ]];then
            M=0
            let F++
            continue
        fi
        NOTICE='NOTICE "Destroy tunnel on '
        if [[ ! ${USERS[$F]} == "---" ]];then
            NOTICE+="${USERS[$F]}@"
        fi
        NOTICE+="${HOSTS[$F]}"
        if [[ ! ${PORTS[$F]} == 22 ]];then
            LINE+=":${PORTS[$F]}"
        fi
        NOTICE+='."'
        echo $NOTICE >> $_file
        echo 'kill $(GETPID "'${LINES[$I]}'")' >> $_file
        let F++
    done
    # Execute.
    executeTemplate $_file