#!/bin/bash
#
# Convention:
# - variable is lower_case and underscore.
# - define is UPPER_CASE, underscore, and prefix with RCM_.
# - temporary variable diawali dengan _underscore.
# - function is camelCase.

# Flag untuk mengaktifkan fungsi varDump.
debug=0

# Lines untuk menjadi storage baris-baris generated code.
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

# Command adalah apapun command di Linux yang menggunakan remote host. RCM
# didisain untuk memudahkan bekerja melalui tunnel, maka remote host yang
# menjadi argument pada command akan direplace menjadi localhost setelah tunnel
# di-create.
# Contoh command yang menggunakan remote host adalah:
# - ssh host
# - rsync host
# - sshfs host
# - wget host
# Special command adalah command internal yang dimiliki oleh rcm untuk tugas
# dan fungsi tertentu yang sudah baku.
command=
special_command=

# *mass_arguments* adalah array penampungan semua argument diluar command.
# Contoh:
# ```
# rcm command satu dua ti\ ga
# ```
# Dari contoh diatas, maka nilai dari variable ini sama dengan
# mass_arguments=(satu dua "ti ga")
mass_arguments=()

# Todo.
destination=
tunnels=()

# Variable array dibawah ini merupakan parse dari *mass_arguments*. Contoh:
# ```
# mass_arguments=(user@virtualmachine via foo@office.lan via proxy@company.com:2222)
# ```
# maka,
# ```
# $route=(proxy@company.com:2222 foo@office.lan user@virtualmachine)
# $route_actual=(proxy@company.com foo@localhost user@localhost)
# $hosts=(company.com office.lan virtualmachine)
# $users=(proxy foo user)
# $ports=(2222 22 22)
# $hosts_actual=(company.com localhost localhost)
# $ports_actual=(2222 50011 50012)
# $tunnels_actual=(50011:office.lan:22 50012:virtualmachine:22)
# ```
# Variable ini akan diisi oleh fungsi parseMassArgumentsAsRoute().
# local port akan diisi oleh fungsi getLocalPortBasedOnHost().
route=()
route_actual=()
hosts=()
ports=()
users=()
hosts_actual=()
ports_actual=()
tunnels_actual=()

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
        echo "-------------------------------------------------------------------------------"
        echo "#!/bin/bash"
        for string in "${compileLines[@]}"
        do
            echo "$string"
        done
        echo "-------------------------------------------------------------------------------"
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
    readOptions
    case $special_command in
        send-key)
            verifyCommon
            verifySendKey
            executeSendKey
            ;;
        login)
            verifyCommon
            verifyLogin
            executeLogin
            ;;
        *)
            echo gak ada
    esac
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
    writeLinesVerbose 'echo -e "\e[93mTest SSH connect to '${route[$i]}' using key.\e[39m"'
    lines+=("if [[ ! \$(ssh ${options}${route_actual[$i]} 'echo 1' 2>/dev/null) == 1 ]];then")
    writeLinesVerbose '    echo -e "\e[93mSSH connect using key is failed. It means process continues.\e[39m"'
    writeLinesVerbose '    echo -e "\e[93mYou need input password twice to sending public key.\e[39m"'
    writeLinesVerbose '    echo -e "\e[93mFirstly, SSH connect to make sure ~/.ssh/authorized_keys on '${route[$i]}' exits.\e[39m"'
    options=
    if [[ ! ${ports_actual[$i]} == 22 ]];then
        options+="-p ${ports_actual[$i]} "
    fi
    line="ssh ${options}${route_actual[$i]}"
    lines+=("    ${line} 'mkdir -p .ssh && chmod 700 .ssh && touch .ssh/authorized_keys && chmod 640 .ssh/authorized_keys'")
    writeLinesVerbose '    echo -e "\e[93mSecondly, SSH connect again to sending public key to '${route[$i]}'.\e[39m"'
    lines+=("    cat ~/.ssh/id_rsa.pub | ${line} 'cat >> .ssh/authorized_keys'")
    writeLinesVerbose '    echo -e "\e[93mRetest SSH connect to '${route[$i]}' using key.\e[39m"'
    options=
    if [[ ! ${ports_actual[$i]} == 22 ]];then
        options+="-p ${ports_actual[$i]} "
    fi
    options+="-o PreferredAuthentications=publickey -o PasswordAuthentication=no "
    writeLinesVerbose "    if [[ ! \$(ssh ${options}${route_actual[$i]} 'echo 1' 2>/dev/null) == 1 ]];then"
    writeLinesVerbose '        echo -e "\e[91mFailed.\e[39m"'
    writeLinesVerbose '    else'
    writeLinesVerbose '        echo -e "\e[92mSuccess.\e[39m"'
    writeLinesVerbose '    fi'
    writeLinesVerbose 'else'
    writeLinesVerbose '    echo -e "\e[93mSSH connect using key is successful thus sending key is not necessary.\e[39m"'
    lines+=("fi")
}

# Fungsi untuk membaca variable $options dan kemudian mengeset variable yang
# terkait.
readOptions () {
    case $special_command in
        send-key)
            while getopts ":iql" opt ${options[@]}; do
                case $opt in
                    i) interactive=1 ;;
                    q) verbose=0 ;;
                    l) through=0 ;;
                    \?) echo "Invalid option: -$OPTARG" >&2 ;;
                esac
            done
            ;;
        login)
            while getopts ":iq" opt ${options[@]}; do
                case $opt in
                    i) interactive=1 ;;
                    q) verbose=0 ;;
                    \?) echo "Invalid option: -$OPTARG" >&2 ;;
                esac
            done
            ;;
        *)
            echo .
    esac
    varDump interactive verbose through
}

# Fungsi untuk memparse variable $mass_arguments untuk nanti mem-populate
# variable terkait.
parseMassArgumentsAsRoute() {
    for (( i=0; i < ${#mass_arguments[@]} ; i++ )); do
        j=$(( $i + 1 ))
        if [[ ${mass_arguments[$i]} =~ " " ]];then
            error "Error. Argument '${mass_arguments[$i]}' mengandung karakter spasi."
        fi
        if isEven $j ;then
            if [[ ! ${mass_arguments[$i]} == 'via' ]];then
                error "Error. Argument '${mass_arguments[$i]}' tidak didahului dengan 'via'."
            fi
        fi
    done
    if isEven ${#mass_arguments[@]};then
        error "Error. Argument kurang lengkap."
    fi
    flag=0
    # Populate variable destination.
    last_index=$(( ${#mass_arguments[@]} - 1 ))
    for (( i=$last_index; i >= 0 ; i-- )); do
        j=$(( $i + 1 ))
        if isOdd $i;then
            continue
        fi
        route+=("${mass_arguments[$i]}")
        _host=${mass_arguments[$i]}
        _user=$(echo $_host | grep -E -o '^[^@]+@')
        _route_actual=$_user
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
            tunnels_actual+=("$_tunnel")
        fi
        _route_actual+="$host_actual"
        route_actual+=("${_route_actual}")
    done

    varDump route hosts users ports hosts_actual ports_actual tunnels_actual
    varDump route_actual
}

# Verifikasi bersama untuk seluruh command.
verifyCommon() {
    # Special command tidak membutuhkan argument -t maupun argument -d yang
    # mengisi array $tunnels. Array $tunnels nanti diisi dari  $mass_argument.
    if [[ ! $special_command == "" ]];then
        if [[ ${#tunnels[@]} -gt 0 ]];then
            error "Special command tidak membutuhkan option -t maupun -d."
        fi
    fi
}

# Varifikasi untuk special command login.
verifyLogin() {
    varDump ------------------------------------------------------------------------
    parseMassArgumentsAsRoute
}

# Eksekusi special command login.
executeLogin () {
    local options _tunnels flag
    for (( i=0; i < ${#route[@]} ; i++ )); do
        options=
        if [[ ! ${tunnels_actual[$i]} == "" ]];then
            options+="-fN -L ${tunnels_actual[$i]} "
            writeLinesVerbose 'echo -e "\e[93m'"SSH Connect. Create tunnel on ${route[$i]}."'\e[39m"'
        else
            writeLinesVerbose 'echo -e "\e[93m'"SSH Connect to ${route[$i]}"'\e[39m"'
        fi
        if [[ ! ${ports_actual[$i]} == 22 ]];then
            options+="-p ${ports_actual[$i]} "
        fi
        lines+=("ssh ${options}${route_actual[$i]}")
        if [[ ! ${tunnels_actual[$i]} == "" ]];then
            _tunnels+=("ssh ${options}${route_actual[$i]}")
        fi
    done
    last_index_tunnels=$(( ${#tunnels_actual[@]} - 1 ))
    flag=0
    for (( i=$last_index_tunnels; i >= 0 ; i-- )); do
        writeLinesVerbose 'echo -e "\e[93m'"Destroy tunnel on ${route[$i]}."'\e[39m"'
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

# Varifikasi untuk special command send-key.
verifySendKey() {
    varDump ------------------------------------------------------------------------
    parseMassArgumentsAsRoute
}

# Eksekusi special command send-key.
executeSendKey() {
    # last_index_route=$(( ${#last_index_route[@]} - 1 ))
    for (( i=0; i < ${#route[@]} ; i++ )); do
        if [[ ! ${tunnels_actual[$i]} == "" ]];then
            if [[ $through == "1" ]];then
                writeLinesSendKey $i
            fi
            options=
            options+="-fN -L ${tunnels_actual[$i]} "
            writeLinesVerbose 'echo -e "\e[93m'"SSH Connect. Create tunnel on ${route[$i]}."'\e[39m"'
            if [[ ! ${ports_actual[$i]} == 22 ]];then
                options+="-p ${ports_actual[$i]} "
            fi
            lines+=("ssh ${options}${route_actual[$i]}")
            if [[ ! ${tunnels_actual[$i]} == "" ]];then
                _tunnels+=("ssh ${options}${route_actual[$i]}")
            fi
        else
            writeLinesSendKey $i
        fi
    done
    last_index_tunnels=$(( ${#tunnels_actual[@]} - 1 ))
    flag=0
    for (( i=$last_index_tunnels; i >= 0 ; i-- )); do
        writeLinesVerbose 'echo -e "\e[93m'"Destroy tunnel on ${route[$i]}."'\e[39m"'
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

# Fungsi untuk mencetak error dan exit.
error() {
    echo "$1" >&2
    echo Force to exit. >&2
    exit 1
}

# Fungsi untuk debug. Mencetak variable.
varDump() {
    local globalVarName globalVarValue
    local normal red yellow cyan
    normal="$(tput sgr0)"
    red="$(tput setaf 1)"
    yellow="$(tput setaf 3)"
    cyan="$(tput setaf 6)"
    if [[ $debug == 0 ]];then
        return
    fi
    while [[ $# -gt 0 ]]; do
        # Argument special untuk var dump variable non global
        # Contoh
        # kondisi=mentah
        # varDump '<$tempe>'$kondisi
        # Hasilnya adalah `$tempe = mentah`
        if [[ $1 =~ ^\<.*\> ]];then
            label=$(echo $1 | cut -d'>' -f1 | cut -c2-)
            value=$(echo $1 | cut -d'>' -f2 )
            printf "${cyan}$label${normal}${red} = ${normal}"
            printf "\"${yellow}$value${normal}\" \n"
            shift
            continue
        fi
        # Check jika variable tidak valid.
        if [[ ! $1 =~ ^[0-9a-zA-Z] ]];then
            printf "${cyan}$1${normal}\n"
            shift
            continue
        fi
        # Check jika variable tidak pernah diset.
        eval isset=\$\(if \[ -z \$\{$1+x\} \]\; then echo 0\; else echo 1\; fi\)
        if [ $isset == 0 ];then
            printf "${cyan}$1${normal}\n"
            shift
            continue
        fi
        # Check variable jika merupakan array.
        # Syaratnya
        eval check=\$\(declare -p $1\)
        if [[ "$check" =~ "declare -a" ]]; then
            eval globalVarValue=\(\"\${$1[@]}\"\)
            printf "${cyan}\$$1${normal}${red} = ( ${normal}"
            for (( i=0; i < ${#globalVarValue[@]} ; i++ )); do
                printf "\"${yellow}${globalVarValue[$i]}${normal}\" "
            done
            printf "${red})${normal}\n"
            shift
            continue
        fi
        # Variable selain itu.
        globalVarName=$1
        globalVarValue=${!globalVarName}
        printf "${cyan}\$$globalVarName${normal}${red} = ${normal}"
        printf "\"${yellow}$globalVarValue${normal}\" \n"
        shift
    done
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

# Parse options that locate in between rcm and command/special_command.
while [[ $# -gt 0 ]]; do
    case $1 in
        --quiet|-q|--interactive|-i)
            options+=("$1"); shift
            ;;
        --tunnel=*)
            tunnels+=("$(echo $1 | cut -c10-)"); shift
            ;;
        -t)
            tunnels+=("$2"); shift 2
            ;;
        --destination=*)
            destination=("$(echo $1 | cut -c15-)"); shift
            ;;
        -d)
            destination=$2; shift 2
            ;;
        *)
            if [[ $1 =~ ^- ]];then
                while getopts ":iqt:d:" opt; do
                    case $opt in
                    i|q)
                        options+=("-$opt")
                        ;;
                    t)
                        tunnels+=("$OPTARG")
                        ;;
                    d)
                        destination="$OPTARG"
                        ;;
                    \?)
                        echo "Invalid option: -$OPTARG" >&2
                        ;;
                    :)
                        echo "Option -$OPTARG requires an argument." >&2
                        ;;
                    esac
                done
                shift $((OPTIND-1))
            fi
            break
    esac
done

if [[ $# == 0 ]];then
    error "Command not found."
fi

case "$1" in
    login|send-key|push|pull|manage|open-port|mount)
        special_command="$1"
        shift
        ;;
    *)
        command="$@"
        ;;
esac

if [[ $command == "" ]];then
    while [[ $# -gt 0 ]]; do
        varDump '<$1>'$1
        if [[ $1 =~ ^- ]];then
            options+=("$1")
        else
            mass_arguments+=("$1")
        fi
        shift
    done
fi

varDump destination interactive verbose through special_command command
varDump tunnels arguments options mass_arguments
varDump ------------------------------------------------------------------------
execute
