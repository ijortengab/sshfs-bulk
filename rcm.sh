#!/bin/bash
#
# Convention:
# - variable is lower_case and underscore.
# - define is UPPER_CASE, underscore, and prefix with RCM_.
# - temporary variable diawali dengan _underscore.
# - function is camelCase.

# Default value.
verbose=1
interactive=0
RCM_ROOT=$HOME/.config/rcm
RCM_DIR_PORTS=$RCM_ROOT/ports

    # mkdir -p
    # cd $HOME/.config/rcm/ports

# *arguments* adalah array penampungan semua argument.
# Argument pertama ($1) nantinya akan diset menjadi command.
# Contoh:
# ```
# rcm command satu dua ti\ ga
# ```
# Dari contoh diatas, maka nilai dari variable ini sama dengan
# arguments=(command satu dua "ti ga")
arguments=()

# *pass_arguments* adalah array tempat penampungan options yang akan di-pass
# di-oper ke command terakhir.
# Contoh:
# ```
# rcm ssh satu dua tiga --pass empat lima
# ```
# Maka:
# pass_arguments=(empat lima)
pass_arguments=()

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
    local file=$1
    local normal="$(tput sgr0)"
    local red="$(tput setaf 1)"
    local yellow="$(tput setaf 3)"
    local cyan="$(tput setaf 6)"
    local execute=1
    if [[ $interactive == 1 ]];then
        printf "${red}Preview generated script.${normal}\n"
        printf "${red}\`\`\`${normal}\n"
        printf "${cyan}"
        cat $file
        printf "${red}\`\`\`${normal}\n"
        read -p "Do you want to execute (y/N): " option
        case $option in
            n|N|no)
                execute=0
                ;;
            y|Y|yes)
                execute=1
                ;;
            *)
                execute=0
                ;;
        esac
    fi
    if [[ $execute == 1 ]];then
        chmod u+x $file
        /bin/bash $file
    fi
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
execute() {
    local i o s flag subcommand options mass_arguments pass_arguments

    # Verifikasi dan populate command.
    case "${arguments[0]}" in
        ssh|send-key|sshfs|rsync|smb)
            subcommand="${arguments[0]}"
            ;;
        *)
            echo Command \'"${arguments[0]}"\' tidak dikenali. >&2
            exit
            ;;
    esac
    flag=0
    for (( i=0; i < ${#arguments[@]} ; i++ )); do
        if [[ $i == 0 ]];then continue; fi
        s=${arguments[$i]}
        case $s in
           -p|--pass)
                flag=1
                continue
                ;;
        esac
        if [[ $flag == 1 ]];then
            pass_arguments+=("$s")
        elif [[ $s =~ ^- ]];then
            options+=("$s")
        else
            mass_arguments+=("$s")
        fi
    done

    while getopts ":iq" opt ${options[@]}; do
      case $opt in
        i)
          interactive=1
          ;;
        q)
          verbose=0
          ;;
        \?)
          echo "Invalid option: -$OPTARG" >&2
          ;;
      esac
    done

    # Verifikasi arguments.
    if [[ ${#mass_arguments[@]} == 0 ]];then
        echo "Error. Argument tidak lengkap."
        exit
    fi

    # Verifikasi dan populate variable $route.
    case $subcommand in
        ssh|send-key)
            for (( i=0; i < ${#mass_arguments[@]} ; i++ )); do
                o=$(( $i + 1 ))
                if [[ ${mass_arguments[$i]} =~ " " ]];then
                    echo "Error. Argument '${mass_arguments[$i]}' mengandung karakter spasi." >&2
                    exit
                fi
                if isEven $o ;then
                    if [[ ! ${mass_arguments[$i]} == 'via' ]];then
                        echo "Error. Argument '${mass_arguments[$i]}' tidak didahului dengan 'via'." >&2
                        exit
                    fi
                fi
            done
            if isEven ${#mass_arguments[@]};then
                echo "Error. Argument kurang lengkap."
                exit
            fi
            # Populate variable route.
            for (( i=0; i < ${#mass_arguments[@]} ; i++ )); do
                route+=${mass_arguments[$i]}" "
            done
            parseRoute
        ;;
    esac
    # Mulai eksekusi berdasarkan command.
    case $subcommand in
            ssh)
                sshCommand $route
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
            _local_port=$(getLocalPortBasedOnHost $_host)
            local_ports+=($_local_port)
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
    _is_last=1 # Just flag for last index of $hosts.
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
        for s in "${pass_arguments[@]}"
        do
            _line+=" "
            _line+=$s
        done
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
                if [[ $_is_last == 1 ]];then
                    _line+="${hosts[$i]}"
                    if [[ ! ${ports[$i]} == 22 ]];then
                        _line+=" -p ${ports[$i]}"
                    fi
                    _is_last=0
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
                for s in "${pass_arguments[@]}"
                do
                    _line+=" "
                    _line+=$s
                done
            fi
            _lines+=("$_line")
        done
    fi
    # Create and fill template.
    mkdir -p $HOME/.cache/rcm
    _file=$HOME/.cache/rcm/ssh
    echo "#!/bin/bash" > $_file
    _order=$_last_index # Countdown order.
    _log=
    for (( i=0; i < ${#_lines[@]} ; i++ )); do
        _log='echo -e "\e[93m'
        if [[ ! $_order == 0 ]];then
            _log+='Create tunnel on '
        else
            _log+='SSH connect to '
        fi
        if [[ ! ${users[$_order]} == "---" ]];then
            _log+="${users[$_order]}@"
        fi
        _log+="${hosts[$_order]}"
        if [[ ! ${ports[$_order]} == 22 ]];then
            line+=":${ports[$_order]}"
        fi
        _log+='.'
        _log+='\e[39m"'
        if [[ $verbose == 1 ]];then
            echo $_log >> $_file
        fi
        echo ${_lines[$i]} >> $_file
        let _order--
    done
    _is_last=1 # Just flag for first index of $_lines.
    _last_index=$(( ${#_lines[@]} - 1 )) # Last index of $_lines.
    _order=0
    _log=
    for (( i=$_last_index; i >= 0 ; i-- )); do
        if [[ $_is_last == 1 ]];then
            _is_last=0
            let _order++
            continue
        fi
        _log='echo -e "\e[93m'
        _log+='Destroy tunnel on '
        if [[ ! ${users[$_order]} == "---" ]];then
            _log+="${users[$_order]}@"
        fi
        _log+="${hosts[$_order]}"
        if [[ ! ${ports[$_order]} == 22 ]];then
            _log+=":${ports[$_order]}"
        fi
        _log+='.'
        _log+='\e[39m"'
        if [[ $verbose == 1 ]];then
            echo $_log >> $_file
        fi
        echo "kill \$(ps aux | grep \""${_lines[$i]}"\" | grep -v grep | awk '{print \$2}')" >> $_file
        let _order++
    done
    # Execute.
    executeTemplate $_file
}

# Fungsi untuk command send-key.
sendKeyCommand () {
    echo
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
execute
