#!/bin/bash
#
# Convention:
# - variable is lower_case and underscore.
# - define is UPPER_CASE, underscore, and prefix with RCM_.
# - temporary variable diawali dengan _underscore.
# - function is camelCase.

linesPre=()
lines=()
linesPost=()

# Default value.
verbose=1
interactive=0
RCM_ROOT=$HOME/.config/rcm
RCM_DIR_PORTS=$RCM_ROOT/ports
RCM_EXE=$RCM_ROOT/exe

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

# *destination* adalah string yang bernilai server tujuan dan (jika ada)
# server-server lain yang menjadi batu loncatan (tunnel). Pola penamaannya
# adalah [$user@]$host[:$port] [via ...]
# Contoh:
# ```
# destination=user@virtualmachine
# destination=user@virtualmachine via foo@office.lan via proxy@company.com
# ```
# Variable ini akan diisi oleh fungsi execute.
destination=

# *hosts*, *ports*, dan *users* adalah array yang merupakan parse info dari
# *destination*. Contoh, jika:
# ```
# destination=user@virtualmachine via foo@office.lan via proxy@company.com:2222
# ```
# maka,
# ```
# hosts=(virtualmachine office.lan company.com)
# ports=(22 22 2222)
# users=(user foo proxy)
# ```
# Variable ini akan diisi oleh fungsi parseDestination.
hosts=()
ports=()
users=()

# *local_ports* merupakan array yang menjadi local port forwarding untuk
# kebutuhan tunneling berdasarkan informasi pada variable $destination.
# Contoh, jika:
# ```
# destination=user@virtualmachine via foo@office.lan via proxy@company.com
# ```
# Maka,
# host virtualmachine akan diset local port forwarding misalnya 50000
# host office.lan akan diset local port forwarding misalnya 50001
# host company.com tidak perlu local port forwarding karena dia menjadi koneksi
# langsung. Sehingga hasil akhir menjadi:
# ```
# local_ports=(50000 50001)
# ```
# Variable ini akan diisi oleh fungsi getLocalPortBasedOnHost().
# Penggunaan local port seperti pada command berikut:
# ```
# ssh -fN proxy@company.com -L 50001:office.lan:22
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
    local string
    local compileLines
    compileLines=()
    for string in "${linesPre[@]}"
    do
        compileLines+=("$string")
    done
    for string in "${lines[@]}"
    do
        compileLines+=("$string")
    done
    for string in "${linesPost[@]}"
    do
        compileLines+=("$string")
    done

    if [[ $interactive == 1 ]];then
        echo "Preview generated script."
        echo "--------------------------------------------------------------------------------"
        echo "#!/bin/bash"
        for string in "${compileLines[@]}"
        do
            echo "$string"
        done
        echo "--------------------------------------------------------------------------------"
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
        echo '#!/bin/bash' > $RCM_EXE
        for string in "${compileLines[@]}"
        do
            echo $string >> $RCM_EXE
        done
        chmod u+x $RCM_EXE
        /bin/bash $RCM_EXE
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
    local h i j
    local string flag order
    local subcommand options mass_arguments pass_arguments

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
        string=${arguments[$i]}
        case $string in
           -p|--pass)
                flag=1
                continue
                ;;
        esac
        if [[ $flag == 1 ]];then
            pass_arguments+=("$string")
        elif [[ $string =~ ^- ]];then
            options+=("$string")
        else
            mass_arguments+=("$string")
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

    # Verifikasi dan populate variable $destination.
    case $subcommand in
        ssh|send-key)
            for (( i=0; i < ${#mass_arguments[@]} ; i++ )); do
                j=$(( $i + 1 ))
                if [[ ${mass_arguments[$i]} =~ " " ]];then
                    echo "Error. Argument '${mass_arguments[$i]}' mengandung karakter spasi." >&2
                    exit
                fi
                if isEven $j ;then
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
            # Populate variable destination.
            for (( i=0; i < ${#mass_arguments[@]} ; i++ )); do
                destination+=${mass_arguments[$i]}" "
            done
            parseDestination
        ;;
    esac
    # Mulai eksekusi berdasarkan command.
    case $subcommand in
            ssh)
                sshCommand $destination
                ;;
            send-key)
                sendKeyCommand $destination
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

# Fungsi untuk memparse variable $destination untuk nanti mem-populate variable
# terkait.
parseDestination() {
    # Ubah string destination menjadi array.
    _destination=($destination)
    for (( i=0; i < ${#_destination[@]} ; i++ )); do
        _order=$(( $i + 1 ))
        if isEven $_order;then
            continue
        fi
        _host=${_destination[$i]}
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
        if [[ ! $i == $((${#_destination[@]} - 1)) ]];then
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
    local h i j
    local string flag order
    local array port file
    mkdir -p $RCM_DIR_PORTS
    cd $RCM_DIR_PORTS
    array=(`grep -r $1 | cut -d: -f1`)
    port=
    for string in "${array[@]}"
    do
        if containsElement $string "${local_ports[@]}";then
            continue
        else
            port=$string
            break
        fi
    done
    if [[ $port == "" ]];then
        file=50000
        while :
        do
            if [[ -e $file ]];then
                let file++
            else
                break
            fi
        done
        echo $1 > $file
        port=$file
    fi
    echo $port
}

# Fungsi untuk mempersiapkan code untuk generate tunnel dan mengisinya pada
# variable $linesPre, atau $linesPost.
writeLinesAddTunnel() {
    local h i j o
    local flag
    local line lines last_index_hosts last_index_lines log
    lines=()
    flag=1 # Just flag for last index of $hosts.
    last_index_hosts=$(( ${#hosts[@]} - 1 )) # Last index of $hosts.
    for (( i=$last_index_hosts; i > 0 ; i-- )); do
        h=$(( $i - 1 ))
        log='echo -e "\e[93m'
        line="ssh -fN "
        log+='Create tunnel on '
        if [[ ! ${users[$i]} == "---" ]];then
            line+="${users[$i]}@"
            log+="${users[$i]}@"
        fi
        log+="${hosts[$i]}"
        if [[ ! ${ports[$i]} == 22 ]];then
            log+=":${ports[$i]}"
        fi
        if [[ $flag == 1 ]];then
            line+="${hosts[$i]}"
            if [[ ! ${ports[$i]} == 22 ]];then
                line+=" -p ${ports[$i]}"
            fi
            flag=0
        else
            line+="localhost"
            line+=" -p ${local_ports[$i]}"
        fi
        line+=" -L ${local_ports[$h]}:${hosts[$h]}:${ports[$h]}"
        log+='.\e[39m"'
        if [[ $verbose == 1 ]];then
            linesPre+=("$log")
        fi
        linesPre+=("$line")
        lines+=("$line")
    done
    last_index_lines=$(( ${#lines[@]} - 1 )) # Last index of $lines.
    o=$last_index_lines
    for (( i=1; i <= $last_index_hosts ; i++ )); do
        log=
        log='echo -e "\e[93m'
        log+='Destroy tunnel on '
        if [[ ! ${users[$i]} == "---" ]];then
            log+="${users[$i]}@"
        fi
        log+="${hosts[$i]}"
        if [[ ! ${ports[$i]} == 22 ]];then
            log+=":${ports[$i]}"
        fi
        log+='.\e[39m"'
        if [[ $verbose == 1 ]];then
            linesPost+=("$log")
        fi
        line="kill \$(ps aux | grep \""${lines[$o]}"\" | grep -v grep | awk '{print \$2}')"
        linesPost+=("$line")
        let o--
    done
}

writeLinesVerbose() {
    if [[ $verbose == 1 ]];then
        lines+=("$1")
    fi
}
# Fungsi untuk command ssh.
sshCommand () {
    local host port log line
    local string
    host=${hosts[0]}
    port=${ports[0]}
    if [[ ${#hosts[@]} > 1 ]];then
        writeLinesAddTunnel
        host=localhost
        port=${local_ports[0]}
    fi
    log='echo -e "\e[93m'
    log+='SSH connect to '
    line='ssh '
    if [[ ! ${users[0]} == "---" ]];then
        log+="${users[0]}@"
        line+="${users[0]}@"
    fi
    log+="${hosts[0]}"
    line+="$host"
    line+=" -p $port"
    for string in "${pass_arguments[@]}"
    do
        line+=" "
        line+=$string
    done
    log+='.\e[39m"'
    if [[ $verbose == 1 ]];then
        lines+=("$log")
    fi
    lines+=("$line")

    # Execute.
    executeTemplate
}

# Fungsi untuk command send-key.
sendKeyCommand () {
    local host port log line _log _line
    local string ssh
    host=${hosts[0]}
    port=${ports[0]}
    if [[ ${#hosts[@]} > 1 ]];then
        writeLinesAddTunnel
        host=localhost
        port=${local_ports[0]}
    fi
    _log=
    _line='ssh '
     if [[ ! ${users[0]} == "---" ]];then
        _log+="${users[0]}@"
        _line+="${users[0]}@"
    fi
    _log+="${hosts[0]}"
    _line+="$host"
     if [[ ! ${ports[0]} == 22 ]];then
        _log+=":${ports[0]}"
    fi
    _line+=" -p $port "
    # echo $_log
    # echo $_line
    writeLinesVerbose 'echo -e "\e[93mTest SSH connect to '${_log}' using public key.\e[39m"'
    line="if [[ ! \$(${_line} -o PreferredAuthentications=publickey -o PasswordAuthentication=no 'echo 1' 2>/dev/null) == 1 ]];then"
    lines+=("$line")
    # pe er disini
    writeLinesVerbose '    echo -e "\e[93mSSH connect using public key is failed. It means sending public key is necessary.\e[39m"'
    writeLinesVerbose '    echo -e "\e[93mYou need input password twice to sending public key.\e[39m"'
    writeLinesVerbose '    echo -e "\e[93mSSH connect to make sure ~/.ssh/authorized_keys on '${_log}' exits.\e[39m"'
    line="    ${_line}"
    line+="'mkdir -p .ssh && chmod 700 .ssh && touch .ssh/authorized_keys && chmod 640 .ssh/authorized_keys'"
    lines+=("$line")
    writeLinesVerbose '    echo -e "\e[93mSSH connect again to sending public key to '${_log}'.\e[39m"'
    line="    ${_line}"
    # line+="'mkdir -p .ssh && chmod 700 .ssh && touch .ssh/authorized_keys && chmod 640 .ssh/authorized_keys'"
    line="    cat ~/.ssh/id_rsa.pub | ${_line} 'cat >> .ssh/authorized_keys'"
    lines+=("$line")
    writeLinesVerbose '    echo -e "\e[93mRetest SSH connect to '${_log}' using public key.\e[39m"'
    writeLinesVerbose "    if [[ \$(${_line} -o PreferredAuthentications=publickey -o PasswordAuthentication=no 'echo 1' 2>/dev/null) == 1 ]];then"
    writeLinesVerbose '        echo -e "\e[92mSuccess.\e[39m"'
    writeLinesVerbose '    else'
    writeLinesVerbose '        echo -e "\e[91mFailed.\e[39m"'
    writeLinesVerbose '    fi'
    writeLinesVerbose 'else'
    writeLinesVerbose '    echo -e "\e[93mSSH connect using public key is success. It means sending public key is not necessary.\e[39m"'
    line="fi"
    lines+=("$line")

    # Execute.
    executeTemplate
}

# Jika dari terminal. Contoh: `rcm ssh user@localhost`.
if [ -t 0 ]; then
    # Process Reguler via terminal.
    # Jika tidak ada argument.
    if [[ $1 == "" ]];then
        clear
        welcomeMessage
        exit
    fi
# Jika dari standard input. Contoh: `echo ssh user@localhost | rcm`.
else
    set -- ${@:-$(</dev/stdin)}
    # Process Standard Input.
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

# getLocalPortBasedOnHost localhost