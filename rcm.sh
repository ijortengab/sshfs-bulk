#!/bin/bash

# Progress: Ahad, 18 Februari 2018
# Sudah ada form wizard untuk add connection
# Sudah ada form wizard untuk select connection
# Sudah ada page untuk list connection meski perlu perbaikan path.
# Usage sudah di definisikan dengan membuat calon halaman help. 
#
# PR berikutnya
# - bermain dengan fungsi connectSSH
# - pastikan bisa generate script untuk konek SSH.

welcomeMessage() {
while :
do
    echo -e "\e[92m# Welcome to SSRS wizard\e[39m"
    echo
    echo SSRS is management remote connection.
    echo It will generate shell script about ssh, sshfs, rsync, and samba.
    echo "Try 'ssrs --help' for more information."
    echo
    echo "What do you want to do?"
    echo
    echo -e "| 1 | \e[93ml\e[39mist"
    echo -e "| 2 | \e[93ma\e[39mdd"
    echo -e "| 3 | \e[93ms\e[39melect"
    echo -e "| 4 | \e[93mm\e[39manage"
    echo -e "| 5 | \e[93mc\e[39mancel"
    echo
    read -rsn1 -p "Select an option (number or yellow letter): " option
    echo
    case $option in
    1|l)
    clear
    listAllConnection
    continue
    ;;
    2|a)
    clear
    addNewConnection
    continue
    ;;
    c)
    clear
    break
    ;;
    *)
    clear
    continue
    ;;
    esac
done
}
# Fungsi perlu perbaikan
listAllConnection() {
    cd ~/.config/ssrs/enabled
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
    storageDir=~/.config/ssrs/connections
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
countAll=$(ls -U ~/.config/ssrs/enabled | wc -l)
if (( $countAll > $define ));then
    list=(`ls -vr ~/.config/ssrs/enabled | head -$define`)
    judul="Showing $define popular connection"
else
    list=(`ls ~/.config/ssrs/enabled`)
    judul="Showing All connection"
fi
array=()
count=-1
for t in "${list[@]}"
do
    let count++
    line="| \e[93m$count\e[39m | "$(cat ~/.config/ssrs/enabled/$t)
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
        all=(`ls -U ~/.config/ssrs/enabled`)
        array=()
        count=-1
        for a in "${all[@]}"
        do
            c=$(cat ~/.config/ssrs/enabled/$a | $input)
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
# clear
# wizardFormSelectConnection
# echo $selectedConnection

# contentScript="roji@phoenix.ui.ac.id"
# contentScript="roji@reverseproxy.ui.ac.id via roji@phoenix.ui.ac.id"
# connectSSH $contentScript
# exit

# Jika dari terminal, maka
if [ -t 0 ]; then
    # Jika tidak ada argument, maka
    if [[ $1 == "" ]];then
        # Tidak ada argument.
        clear
        welcomeMessage
    # Jika ada argument, maka
    else
        POSITIONAL=()
        command=
        while [[ $# -gt 0 ]]
        do
        key="$1"

        case $key in
            l|list)
            command=list
            EXTENSION="$2"
            shift # past argument
            # shift # past value
            ;;
            a|add)
            command=add
            SEARCHPATH="$2"
            shift # past argument
            # shift # past value
            ;;
            -l|--lib)
            LIBPATH="$2"
            shift # past argument
            shift # past value
            ;;
            --default)
            DEFAULT=YES
            shift # past argument
            ;;
            *)    # unknown option
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
        esac
        done
        set -- "${POSITIONAL[@]}" # restore positional parameters

        # echo ${POSITIONAL}

        for f in "${POSITIONAL[@]}"
        do
            echo $f
            # echo
        done
        case $command in
            l|list)
            listAllConnection
            ;;
            add)
            # echo tambah oy
            clear
            addNewConnection
            ;;
        esac
    fi
else
    # echo io
    set -- ${@:-$(</dev/stdin)}
    echo luar biasa
    echo $1
    # stdin is not a tty: process standard input
fi


# References.
#
# Passing parameters to a Bash function
#     https://stackoverflow.com/a/6212408/7074586
# Spinal Case to Camel Case
#     https://stackoverflow.com/a/34420162/7074586
# linux bash, camel case string to separate by dash
#     https://stackoverflow.com/a/8503127/7074586
# How to read from a file or stdin in Bash?
#     https://stackoverflow.com/a/28786207/7074586
# How do I parse command line arguments in Bash?
#     https://stackoverflow.com/a/14203146/7074586
# bash script read pipe or argument
#     https://stackoverflow.com/a/20359063/7074586
# How to read stdin when no arguments are passed?
#     https://stackoverflow.com/a/31602858/7074586
# Create new file but add number if filename already exists in bash
#     https://stackoverflow.com/a/12187944/7074586
# How to echo directly on standard output inside a shell function?
#     https://stackoverflow.com/a/31656923/7074586
# How do I limit the number of files printed by ls?
#     https://unix.stackexchange.com/a/21472
# Quick ls command
#     https://stackoverflow.com/a/40206/7074586
# shell script respond to keypress
#     https://stackoverflow.com/a/24016147/7074586
# How To Find BASH Shell Array Length ( number of elements )
#     https://www.cyberciti.biz/faq/finding-bash-shell-array-length-elements/