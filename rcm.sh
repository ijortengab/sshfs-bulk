#!/bin/bash
#
# Convention:
# - variable is lower_case and underscore.
# - temporary variable diawali dengan _underscore.
# - function is camelCase.

# Default value.
verbose=1

# *arguments* adalah array penampungan semua argument.
# Argument pertama ($1) nantinya akan diset menjadi command.
# Contoh:
# ```
# rcm command satu dua ti\ ga
# ```
# Dari contoh diatas, maka nilai dari variable ini sama dengan
# arguments=(command satu dua "ti ga")
arguments=()

# *command* adalah argument pertama yang menjadi perintah utama.
command=

# *route* adalah string yang berisi server tujuan dan (jika ada) server-server
# lain yang menjadi batu loncatan (tunnel). Pola penamaannya adalah
# [$user@]$host[:$port] [via ...]
# Contoh:
# ```
# route=user@virtualmachine
# route=user@virtualmachine via foo@office.local via proxy@company.com
# ```
# Variable ini akan diisi berdasarkan argument.
route=

# *hosts*, *ports*, dan *users* adalah array yang merupakan parse info dari
# *route*. Contoh, jika:
# ```
# route=user@virtualmachine via foo@office.local via proxy@company.com
# ```
# maka,
# ```
# hosts=(virtualmachine office.local company.com)
# ports=(22 22 22)
# users=(user foo proxy)
# ```
# Variable ini akan diisi oleh fungsi parseRoute.
hosts=()
ports=()
users=()

# *local_ports* merupakan array yang menjadi local port forwarding untuk
# kebutuhan tunneling berdasarkan informasi pada variable ROUTE.
# Contoh, jika:
# ```
# route=user@virtualmachine via foo@office.local via proxy@company.com
# ```
# Maka,
# host virtualmachine akan diset local port forwarding misalnya 50000
# host office.local akan diset local port forwarding misalnya 50001
# host company.com tidak perlu local port forwarding karena dia menjadi koneksi
# langsung.
# sehingga hasil akhir menjadi
# ```
# local_ports=(50000 50001)
# ```
# Variable ini akan diisi oleh fungsi parseRoute dan getLocalPortBasedOnHost().
# Penggunaan local port seperti pada command berikut:
# ```
# ssh -fN proxy@company.com -L 50001:office.local:22
# ssh -fN foo@localhost -p 50001 -L 50000:virtualmachine:22
# ssh user@localhost -p 50000
# ```
local_ports=()

# Fungsi containsElement() seperti fungsi PHP in_array(). Berguna untuk mengecek
# apakah sebuah value sudah ada didalam array.
containsElement () {
    local e match="$1"
    shift
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}

# Fungsi mengecek bilangan adalah genap.
isEven () {
    if [[ ! $1 =~ ^-?[0-9]+$ ]];then
        echo "Argument harus angka integer (postivie atau negative)." >&2
        return
    fi
    if [[ $(( $1 % 2 )) == 1 ]];then
        return 1
    fi
    return 0
}

# Fungsi mengecek bilangan adalah ganjil.
isOdd () {
    if [[ ! $1 =~ ^-?[0-9]+$ ]];then
        echo "Argument harus angka integer (postivie atau negative)." >&2
        return
    fi
    if [[ $(( $1 % 2 )) == 1 ]];then
        return 0
    fi
    return 1
}

# Fungsi untuk mengeksekusi template.
executeTemplate() {
    _file=$1
    # cat $_file
    chmod u+x $_file
    /bin/bash $_file
}

# Fungsi untuk menampilkan dialog wizard. Hanya untuk eksekusi rcm tanpa 
# argument.
welcomeMessage() {
while :
do
    echo -e "\e[92m# Welcome to RCM wizard\e[39m"
    echo
    echo RCM is Remote Connection Manager.
    echo It will generate shell script about ssh, sshfs, rsync, and samba.
    echo "Try 'rcm --help' for more information."
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

# Fungsi untuk mengeksekusi rcm jika diberi argument.
executeArguments() {
    # echo ---------------------------
    # for f in "${arguments[@]}"
    # do
        # echo $f
    # done
    # echo ---------------------------
    # Verifikasi dan populate command.
    case "${arguments[0]}" in
        ssh|send-key|sshfs|rsync|smb)
            command="${arguments[0]}"
            ;;
        *)
            echo Error. Command \'"${arguments[0]}"\' tidak dikenali.
            exit
            ;;
    esac
    # Verifikasi dan populate options.
    _arguments=()
    for s in "${arguments[@]}"
    do
        key="$1"
        case $s in
            ssh|send-key|sshfs|rsync|smb)
                shift
                ;;
            -q|--quiet)
                verbose=0
                shift
                ;;
            *)
            _arguments+=("$s")
            shift
            ;;
        esac
    done
    # echo ---------------------------
    # echo $command
    # for f in "${_arguments[@]}"
    # do
        # echo $f
    # done
    # echo ---------------------------
    # Verifikasi arguments.
    if [[ ${#_arguments[@]} == 0 ]];then
        echo "Error. Argument tidak lengkap."
        exit
    fi
    # Verifikasi dan populate variable $route.
    case $command in
        ssh|send-key)
            for (( i=0; i < ${#_arguments[@]} ; i++ )); do
                _order=$(( $i + 1 ))
                if [[ ${_arguments[$i]} =~ " " ]];then
                    echo Error. Argument \'${_arguments[$i]}\' mengandung karakter spasi.
                    exit
                fi
                if isEven $_order ;then
                    if [[ ! ${_arguments[$i]} == 'via' ]];then
                        echo "Error. Tidak memisah route dengan kata 'via'."
                        exit
                    fi
                fi
            done
            if isEven ${#_arguments[@]};then
                echo "Error. Argument kurang lengkap."
                exit
            fi
            # Populate variable route.
            for (( i=0; i < ${#_arguments[@]} ; i++ )); do
                route+=${_arguments[$i]}" "
            done
            parseRoute
        ;;
    esac
    # Mulai eksekusi berdasarkan command.
    case $command in
            ssh)
                sshCommand ${_arguments}
                ;;
            send-key)
                sendKeyCommand $route
                ;;
            sshfs)
                sshfsCommand ${_arguments}
                ;;
            rsync)
                rsyncCommand ${_arguments}
                ;;
            smb)
                smbCommand ${_arguments}
                ;;
            add)
                clear
                addNewConnection
                ;;
        esac
}

# Fungsi untuk memparse variable $route untuk nanti mem-populate variable 
# terkait.
parseRoute() {
    # Ubah string route menjadi array.
    _route=($route)
    for (( i=0; i < ${#_route[@]} ; i++ )); do
        _order=$(( $i + 1 ))
        if isEven $_order;then
            continue
        fi
        _host=${_route[$i]}
        _user=$(echo $_host | grep -E -o '^[^@]+@')
        if [[ $_user == "" ]];then
            _user=---
        else
            _host=$(echo $_host | sed 's/^'$_user'//' )
            _user=$(echo $_user | grep -E -o '[^@]+')
        fi
        _port=$(echo $_host | grep -E -o ':[0-9]+$')
        if [[ $_port == "" ]];then
            _port=22
        else
            _host=$(echo $_host | sed 's/'$_port'$//' )
            _port=$(echo $_port | grep -E -o '[0-9]+')
        fi
        hosts+=("$_host")
        users+=("$_user")
        ports+=("$_port")
        if [[ ! $i == $((${#_route[@]} - 1)) ]];then
            # host selain yang terakhir pada argument, maka buat local portnya.
            _localport=$(getLocalPortBasedOnHost $_host)
            local_ports+=($_localport)
        fi
    done
}

# Fungsi untuk memberikan local port start from port 50000 berdasarkan
# host dengan melihat variable $local_ports sebagai acuan. Satu host bisa
# memiliki banyak local port tergantung kebutuhan pembuatan tunnel.
getLocalPortBasedOnHost() {
    mkdir -p $HOME/.config/rcm/ports
    cd $HOME/.config/rcm/ports
    _array=(`grep -r $1 | cut -d: -f1`)
    _port=
    for e in "${_array[@]}"
    do
        if containsElement $f "${local_ports[@]}";then
            continue
        else
            _port=$e
            break
        fi
    done
    if [[ $_port == "" ]];then
        _file=50000
        while :
        do
            if [[ -e $_file ]];then
                let _file++
            else
                break
            fi
        done
        echo $1 > $_file
        _port=$_file
    fi
    echo $_port
}

# Fungsi untuk command ssh.
sshCommand () {
    _is_first=1 # Just flag for first index of $hosts.
    _last_index=$(( ${#hosts[@]} - 1 )) # Last index of $hosts.
    _line=
    _lines=()
    if [[ ${#hosts[@]} == 1 ]];then
        _line+="ssh "
        if [[ ! ${users[0]} == "---" ]];then
            _line+=${users[0]}
            _line+=@
        fi
        _line+="${hosts[0]}"
        if [[ ! ${ports[0]} == 22 ]];then
            _line+=" -p ${ports[0]}"
        fi
        _lines+=("$_line")
    fi
    if [[ ${#hosts[@]} > 1 ]];then
        for (( i=$_last_index; i >= 0 ; i-- )); do
            _line="ssh"
            _i=$(( $i - 1 ))
            if [[ ! $i == 0 ]];then
                _line+=" -fN "
                if [[ ! ${users[$i]} == "---" ]];then
                    _line+="${users[$i]}@"
                fi
                if [[ $_is_first == 1 ]];then
                    _line+="${hosts[$i]}"
                    if [[ ! ${ports[$i]} == 22 ]];then
                        _line+=" -p ${ports[$i]}"
                    fi
                    _is_first=0
                else
                    _line+="localhost"
                    _line+=" -p ${local_ports[$i]}"
                fi
                _line+=" -L ${local_ports[$_i]}:${hosts[$_i]}:"
                _line+="${ports[$_i]}"
            else
                _line+=" "
                if [[ ! ${users[$i]} == "---" ]];then
                    _line+="${users[$i]}@"
                fi
                _line+="localhost"
                _line+=" -p ${local_ports[$i]}"
            fi
            _lines+=("$_line")
        done
    fi
    # Create and fill template.
    mkdir -p $HOME/.cache/rcm
    _file=$HOME/.cache/rcm/ssh
    getTemplateSsh $_file
    _order=$_last_index # Countdown order.
    _log=
    for (( i=0; i < ${#_lines[@]} ; i++ )); do
        if [[ ! $_order == 0 ]];then
            _log='log "Create tunnel on '
        else
            _log='log "SSH connect to '
        fi
        if [[ ! ${users[$_order]} == "---" ]];then
            _log+="${users[$_order]}@"
        fi
        _log+="${hosts[$_order]}"
        if [[ ! ${ports[$_order]} == 22 ]];then
            line+=":${ports[$_order]}"
        fi
        _log+='."'
        echo $_log >> $_file
        echo ${_lines[$i]} >> $_file
        let _order--
    done
    _is_first=1 # Just flag for first index of $_lines.
    _last_index=$(( ${#_lines[@]} - 1 )) # Last index of $_lines.
    _order=0
    _log=
    for (( i=$_last_index; i >= 0 ; i-- )); do
        if [[ $_is_first == 1 ]];then
            _is_first=0
            let _order++
            continue
        fi
        _log='log "Destroy tunnel on '
        if [[ ! ${users[$_order]} == "---" ]];then
            _log+="${users[$_order]}@"
        fi
        _log+="${hosts[$_order]}"
        if [[ ! ${ports[$_order]} == 22 ]];then
            _log+=":${ports[$_order]}"
        fi
        _log+='."'
        echo $_log >> $_file
        echo 'kill $(getPid "'${_lines[$i]}'")' >> $_file
        let _order++
    done
    # Execute.
    executeTemplate $_file
}

# Fungsi untuk command send-key.
sendKeyCommand () {
    echo 
}

# Fungsi untuk membuat template berdasarkan command ssh.
getTemplateSsh () {
    cat <<TEMPLATE > $1
#!/bin/bash
verbose=$verbose
getPid () {
    local line=\$(ps x | grep "\$1" | grep -v grep)
    local array=(\$line)
    local pid=\${array[0]}
    echo \$pid
}
log () {
    local normal="\$(tput sgr0)"
    local yellow="\$(tput setaf 3)"
    if [[ \$verbose == 1 ]];then
        printf "\${yellow}\$1\${normal}\n"
    fi
}
TEMPLATE
}

# Jika dari terminal. Contoh: `rcm ssh user@localhost`.
if [ -t 0 ]; then
    # echo Process Reguler via terminal.
    # Jika tidak ada argument.
    if [[ $1 == "" ]];then
        clear
        welcomeMessage
        exit
    fi
# Jika dari standard input. Contoh: `echo ssh user@localhost | rcm`.
else
    set -- ${@:-$(</dev/stdin)}
    # echo Process Standard Input.
fi

while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        *)
        arguments+=("$1")
        shift
        ;;
    esac
done
set -- "${arguments[@]}" # restore positional parameters
executeArguments
