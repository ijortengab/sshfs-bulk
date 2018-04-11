#!/bin/bash
#
# Convention:
# - variable is lower_case and underscore.
# - define is UPPER_CASE, underscore, and prefix with RCM_.
# - temporary variable diawali dengan _underscore.
# - function is camelCase.

lines_pre=()
lines=()
lines_post=()

# Default value.
verbose=1
interactive=0
through=1
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

# *destination* adalah string dengan value adalah server tujuan dan (jika ada)
# server-server lain yang menjadi batu loncatan (tunnel). Pola penamaannya
# adalah [$user@]$host[:$port] [via ...]
# Contoh:
# ```
# destination=user@virtualmachine
# destination=user@virtualmachine via foo@office.lan via proxy@company.com
# ```
# Variable ini akan diisi oleh fungsi execute.
destination=

# Variable array dibawah ini merupakan parse info dari
# *destination*. Contoh, jika:
# ```
# destination=user@virtualmachine via foo@office.lan via proxy@company.com:2222
# ```
# maka,
# ```
# $destinations=(proxy@company.com:2222 foo@office.lan user@virtualmachine)
# $destinations_actual=(proxy@company.com foo@localhost user@localhost)
# $hosts=(company.com office.lan virtualmachine)
# $users=(proxy foo user)
# $ports=(2222 22 22)
# $hosts_actual=(company.com localhost localhost)
# $ports_actual=(2222 50011 50012)
# $tunnels=(50011:office.lan:22 50012:virtualmachine:22)
# ```
# Variable ini akan diisi oleh fungsi parseDestination().
# local port akan diisi oleh fungsi getLocalPortBasedOnHost().
destinations=()
destinations_actual=()
hosts=()
ports=()
users=()
hosts_actual=()
ports_actual=()
tunnels=()

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

# Fungsi untuk mengecek bahwa mesin saat ini adalah Cygwin.
isCygwin () {
    if [[ $(uname | cut -c1-6) == "CYGWIN" ]];then
        return 0
    fi
    return 1
}

# Fungsi untuk mengeksekusi template.
executeTemplate() {
    local execute=1
    local string
    local compileLines
    compileLines=()
    for string in "${lines_pre[@]}"
    do
        compileLines+=("$string")
    done
    for string in "${lines[@]}"
    do
        compileLines+=("$string")
    done
    for string in "${lines_post[@]}"
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
        mkdir -p $RCM_ROOT
        echo '#!/bin/bash' > $RCM_EXE
        for string in "${compileLines[@]}"
        do
            echo "$string" >> $RCM_EXE
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

    while getopts ":iql" opt ${options[@]}; do
      case $opt in
        i)
          interactive=1
          ;;
        q)
          verbose=0
          ;;
        l)
          through=0
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
    local h i o
    local last_index_destinations
    local flag
    local _host _user _port _local_port _tunnel _destination

    # Ubah string destination menjadi array.
    _destination=($destination)
    flag=0
    last_index_destination=$(( ${#_destination[@]} - 1 ))
    for (( i=$last_index_destination; i >= 0 ; i-- )); do
        j=$(( $i + 1 ))
        if isOdd $i;then
            continue
        fi
        destinations+=("${_destination[$i]}")
        _host=${_destination[$i]}
        _user=$(echo $_host | grep -E -o '^[^@]+@')
        _destination_actual=$_user
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
        if [[ $flag == 0 ]];then
            flag=1
            host_actual=$_host
            hosts_actual+=("$_host")
            ports_actual+=("$_port")
        else
            host_actual=localhost
            hosts_actual+=("localhost")
            _local_port=$(getLocalPortBasedOnHost $_host)
            local_ports+=($_local_port)
            ports_actual+=("$_local_port")
            _tunnel="${_local_port}:${_host}:${_port}"
            tunnels+=("$_tunnel")
        fi
        _destination_actual+="$host_actual"
        destinations_actual+=("${_destination_actual}")
    done
    # varDump
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

# Fungsi untuk menambah baris fungsi getPidCygwin pada variable $lines_pre
writeLinesAddGetPidCygwin() {
    lines_pre+=("getPidCygwin() {")
    lines_pre+=("    local pid command ifs")
    lines_pre+=("    ifs=\$IFS")
    lines_pre+=("    ps -s | grep ssh | awk '{print \$1}' | while IFS= read -r pid; do\\")
    lines_pre+=("        command=\$(cat /proc/\${pid}/cmdline | tr '\0' ' ')")
    lines_pre+=("        command=\$(echo \"\$command\" | sed 's/\ \$//')")
    lines_pre+=("        if [[ \"\$command\" == \"\$1\" ]];then")
    lines_pre+=("            echo \$pid")
    lines_pre+=("            break")
    lines_pre+=("        fi")
    lines_pre+=("    done")
    lines_pre+=("    IFS=\$ifs")
    lines_pre+=("}")
}

# Fungsi untuk menulis pada variable $lines hanya jika verbose aktif.
writeLinesVerbose() {
    if [[ $verbose == 1 ]];then
        lines+=("$1")
    fi
}

# Fungsi untuk menulis pada variable $lines terkait command send-key.
writeLinesSendKey() {
    i=$1
    options=
    if [[ ! ${ports_actual[$i]} == 22 ]];then
        options+="-p ${ports_actual[$i]} "
    fi
    options+="-o PreferredAuthentications=publickey -o PasswordAuthentication=no "
    writeLinesVerbose 'echo -e "\e[93mTest SSH connect to '${destinations[$i]}' using key.\e[39m"'
    lines+=("if [[ ! \$(ssh ${options}${destinations_actual[$i]} 'echo 1' 2>/dev/null) == 1 ]];then")
    writeLinesVerbose '    echo -e "\e[93mSSH connect using key is failed. It means process continues.\e[39m"'
    writeLinesVerbose '    echo -e "\e[93mYou need input password twice to sending public key.\e[39m"'
    writeLinesVerbose '    echo -e "\e[93mFirstly, SSH connect to make sure ~/.ssh/authorized_keys on '${destinations[$i]}' exits.\e[39m"'
    options=
    if [[ ! ${ports_actual[$i]} == 22 ]];then
        options+="-p ${ports_actual[$i]} "
    fi
    line="ssh ${options}${destinations_actual[$i]}"
    lines+=("    ${line} 'mkdir -p .ssh && chmod 700 .ssh && touch .ssh/authorized_keys && chmod 640 .ssh/authorized_keys'")
    writeLinesVerbose '    echo -e "\e[93mSecondly, SSH connect again to sending public key to '${destinations[$i]}'.\e[39m"'
    lines+=("    cat ~/.ssh/id_rsa.pub | ${line} 'cat >> .ssh/authorized_keys'")
    writeLinesVerbose '    echo -e "\e[93mRetest SSH connect to '${destinations[$i]}' using key.\e[39m"'
    options=
    if [[ ! ${ports_actual[$i]} == 22 ]];then
        options+="-p ${ports_actual[$i]} "
    fi
    options+="-o PreferredAuthentications=publickey -o PasswordAuthentication=no "
    writeLinesVerbose "    if [[ ! \$(ssh ${options}${destinations_actual[$i]} 'echo 1' 2>/dev/null) == 1 ]];then"
    writeLinesVerbose '        echo -e "\e[92mSuccess.\e[39m"'
    writeLinesVerbose '    else'
    writeLinesVerbose '        echo -e "\e[91mFailed.\e[39m"'
    writeLinesVerbose '    fi'
    writeLinesVerbose 'else'
    writeLinesVerbose '    echo -e "\e[93mSSH connect using key is successful thus sending key is not necessary.\e[39m"'
    lines+=("fi")
}

# Fungsi untuk command ssh.
sshCommand () {
    local options last_index_destinations _tunnels flag
    last_index_destinations=$(( ${#destinations[@]} - 1 ))
    for (( i=0; i <= $last_index_destinations ; i++ )); do
        options=
        if [[ ! ${tunnels[$i]} == "" ]];then
            options+="-fN -L ${tunnels[$i]} "
            writeLinesVerbose 'echo -e "\e[93m'"SSH Connect. Create tunnel on ${destinations[$i]}."'\e[39m"'
        else
            writeLinesVerbose 'echo -e "\e[93m'"SSH Connect to ${destinations[$i]}"'\e[39m"'
        fi
        if [[ ! ${ports_actual[$i]} == 22 ]];then
            options+="-p ${ports_actual[$i]} "
        fi
        lines+=("ssh ${options}${destinations_actual[$i]}")
        if [[ ! ${tunnels[$i]} == "" ]];then
            _tunnels+=("ssh ${options}${destinations_actual[$i]}")
        fi
    done
    last_index_tunnels=$(( ${#tunnels[@]} - 1 ))
    flag=0
    for (( i=$last_index_tunnels; i >= 0 ; i-- )); do
        writeLinesVerbose 'echo -e "\e[93m'"Destroy tunnel on ${destinations[$i]}."'\e[39m"'
        if isCygwin;then
            flag=1
            lines+=("kill \$(getPidCygwin \"${_tunnels[$i]}\")")
        else
            lines+=("kill \$(ps aux | grep \"${_tunnels[$i]}\" | grep -v grep | awk '{print \$2}')")
        fi
    done
    if [[ $flag == 1 ]];then
        writeLinesAddGetPidCygwin
    fi
    executeTemplate
}

# Fungsi untuk command send-key.
sendKeyCommand() {
    local options last_index_destinations _tunnels flag
    last_index_destinations=$(( ${#destinations[@]} - 1 ))
    for (( i=0; i <= $last_index_destinations ; i++ )); do
        if [[ ! ${tunnels[$i]} == "" ]];then
            if [[ $through == "1" ]];then
                writeLinesSendKey $i
            fi
            options=
            options+="-fN -L ${tunnels[$i]} "
            writeLinesVerbose 'echo -e "\e[93m'"SSH Connect. Create tunnel on ${destinations[$i]}."'\e[39m"'
            if [[ ! ${ports_actual[$i]} == 22 ]];then
                options+="-p ${ports_actual[$i]} "
            fi
            lines+=("ssh ${options}${destinations_actual[$i]}")
            if [[ ! ${tunnels[$i]} == "" ]];then
                _tunnels+=("ssh ${options}${destinations_actual[$i]}")
            fi
        else
            writeLinesSendKey $i
        fi
    done
    last_index_tunnels=$(( ${#tunnels[@]} - 1 ))
    flag=0
    for (( i=$last_index_tunnels; i >= 0 ; i-- )); do
        writeLinesVerbose 'echo -e "\e[93m'"Destroy tunnel on ${destinations[$i]}."'\e[39m"'
        if isCygwin;then
            flag=1
            lines+=("kill \$(getPidCygwin \"${_tunnels[$i]}\")")
        else
            lines+=("kill \$(ps aux | grep \"${_tunnels[$i]}\" | grep -v grep | awk '{print \$2}')")
        fi
    done
    if [[ $flag == 1 ]];then
        writeLinesAddGetPidCygwin
    fi
    executeTemplate
}

# Debug global variable.
varDump() {
    local normal="$(tput sgr0)"
    local red="$(tput setaf 1)"
    local yellow="$(tput setaf 3)"
    local cyan="$(tput setaf 6)"

    printf "${cyan}\$destinations${normal}"
    printf "${red} = ( ${normal}"
    for string in ${destinations[@]}
    do
        printf "\"${yellow}$string${normal}\" "
    done
    printf "${red})${normal}"
    echo -e "\n"

    printf "${cyan}\$destinations_actual${normal}"
    printf "${red} = ( ${normal}"
    for string in ${destinations_actual[@]}
    do
        printf "\"${yellow}$string${normal}\" "
    done
    printf "${red})${normal}"
    echo -e "\n"

    printf "${cyan}\$hosts${normal}"
    printf "${red} = ( ${normal}"
    for string in ${hosts[@]}
    do
        printf "\"${yellow}$string${normal}\" "
    done
    printf "${red})${normal}"
    echo -e "\n"

    printf "${cyan}\$users${normal}"
    printf "${red} = ( ${normal}"
    for string in ${users[@]}
    do
        printf "\"${yellow}$string${normal}\" "
    done
    printf "${red})${normal}"
    echo -e "\n"

    printf "${cyan}\$ports${normal}"
    printf "${red} = ( ${normal}"
    for string in ${ports[@]}
    do
        printf "\"${yellow}$string${normal}\" "
    done
    printf "${red})${normal}"
    echo -e "\n"

    printf "${cyan}\$hosts_actual${normal}"
    printf "${red} = ( ${normal}"
    for string in ${hosts_actual[@]}
    do
        printf "\"${yellow}$string${normal}\" "
    done
    printf "${red})${normal}"
    echo -e "\n"

    printf "${cyan}\$ports_actual${normal}"
    printf "${red} = ( ${normal}"
    for string in ${ports_actual[@]}
    do
        printf "\"${yellow}$string${normal}\" "
    done
    printf "${red})${normal}"
    echo -e "\n"

    printf "${cyan}\$tunnels${normal}"
    printf "${red} = ( ${normal}"
    for string in ${tunnels[@]}
    do
        printf "\"${yellow}$string${normal}\" "
    done
    printf "${red})${normal}"
    echo -e "\n"

    printf "${cyan}\$verbose${normal}"
    printf "${red} = ${normal}"
    printf "\"${yellow}$verbose${normal}\" "
    echo -e "\n"

    printf "${cyan}\$interactive${normal}"
    printf "${red} = ${normal}"
    printf "\"${yellow}$interactive${normal}\" "
    echo -e "\n"

    printf "${cyan}\$through${normal}"
    printf "${red} = ${normal}"
    printf "\"${yellow}$through${normal}\" "
    echo -e "\n"

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
