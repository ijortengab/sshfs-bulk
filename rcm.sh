#!/bin/bash
#
# RCM - Remote Connection Manager
#
# Created by: IjorTengab http://ijortengab.id
# Homepage  : https://github.com/ijortengab/rcm
#
# Convention:
# - define is UPPER_CASE, underscore, and prefix with RCM_.
# - variable is lower_case and underscore.
# - temporary variable (return string from function) prefix with _underscore.
# - function is camelCase.
# - indent is 4 spaces.

# Define.
RCM_ROOT=$HOME/.config/rcm
RCM_DIR_PORTS=$RCM_ROOT/ports
RCM_EXE=$RCM_ROOT/exe
RCM_PORT_START=49152

# Default value of options.
options=()
verbose=1
preview=0
through=1
style=auto
public_key=auto
numbering=auto

# Default value of flag.
add_func_get_pid_cygwin=0
add_var_tunnel_success=0

# Developer only.
# Flag untuk mengaktifkan fungsi varDump.
debug=0

# Informasi Global Variables.
# ---------------------------
#
# $lines* - Array. Penyimpanan baris-baris generated code.
#
# ```
# lines_define=()
# lines_function=()
# lines_pre=()
# lines=()
# lines_post=()
# ```
#
# Informasi global variable lainnya diperlukan contoh command line.
# -----------------------------------------------------------------
#
# Contoh:
#
# ```
# rcm login guest@virtualmachine.vm via ijortengab@office.lan:2223 via staff-it@company.com:80 -pstunnel
# rcm login guest@virtualmachine.vm via ijortengab@office.lan:2223 via staff-it@company.com:80 -psjump
# ```
#
# $argument - Array. Tempat penyimpanan seluruh argument yang masuk pada
# command line.
#
# ```
# $arguments = ( "guest@virtualmachine.vm" "via" "ijortengab@office.lan:2223" "via" "staff-it@company.com:80" "-pstunnel" )
# $arguments = ( "guest@virtualmachine.vm" "via" "ijortengab@office.lan:2223" "via" "staff-it@company.com:80" "-psjump" )
# ```
#
# $command - String. Merupakan mass-arguments pertama setelah command `rcm`.
# Value tersedia adalah `login`, `send-key`, dan `open-port`.
#
# ```
# $command = "login"
# ```
#
# $verbose - Default value true (1). Options `--quiet` atau `-q` akan
# mengubahnya menjadi false (0). Apabila bernilai false (0) maka rcm akan
# menggenerate code yang menghasilkan standard output.
#
# $preview - Default value false (0). Options `--preview` atau `-p` akan
# mengubahnya menjadi true (1). Apabila bernilai true (1) maka rcm akan
# menampilkan generate code sebagai standard output dan tidak mengeksekusi
# generate code tersebut.
#
# $through - Default value true (1). Options `--last-one` atau `-l` akan
# mengubahnya menjadi false (0). Command yang menggunakan variable ini adalah
# `send-key`. Apabila bernilai true (1), maka seluruh address (host) yang
# berada pada $route akan diberi tindakan sesuai command (dalam hal ini adalah
# send public key). Apabila bernilai false (0), maka hanya address (host)
# destination saja yang akan diberi tindakan sesuai command.
#
# $style - Default value adalah "auto". Value tersedia adalah "auto", "jump",
# dan "tunnel". Options `--style` atau `-s` tersedia untuk mengubah default
# value. Apabila bernilai `jump`, maka generate code akan menggunakan option
# ssh bernama ProxyJump untuk melakukan lompatan koneksi, sementara apabila
# bernilai `tunnel`, maka generate code akan membuat tunnel (local port
# forwarding) untuk melakukan lompatan koneksi. Jika bernilai `auto`, maka
# akan menggunakan style `jump` jika open-ssh client berada pada versi 7.3
# keatas, selain itu maka akan menggunakan style `tunnel`.
#
# $public_key - Default value adalah "auto". Command yang menggunakan variable
# ini adalah `send-key`. Jika bernilai auto, maka `rcm` akan mencari public key
# sesuai urutan dari ssh client (lihat pada validatePublicKey::tester).
#
# $numbering - Default value adalah "auto". Command yang menggunakan variable
# ini adalah `open-port`. Command open-port menggunakan option ini untuk
# mengeset port number.
#
# ```
# $verbose = "1"
# $preview = "0"
# $through = "1"
# $style = "auto"
# $public_key = "auto"
# $numbering = "auto"
# ```
#
# $route* - Array. Kumpulan dari address yang dilalui. Tiap address memiliki
# format `[USER@]HOST[:PORT]`. Jika route hanya terdiri dari satu address,
# maka berarti itu koneksi langsung tanpa melalui jump/tunnel.
# Jika route terdiri lebih dari satu address, maka address terakhir disebut
# `destination` dan address yang berada diawal dari destination disebut
# `tunnel`.
#
# ```
# $route = ( "staff-it@company.com:80" "ijortengab@office.lan:2223" "guest@virtualmachine.vm" )
# $route_hosts = ( "company.com" "office.lan" "virtualmachine.vm" )
# $route_users = ( "staff-it" "ijortengab" "guest" )
# $route_ports = ( "80" "2223" "22" )
# ```
#
# Variable khusus jika dibutuhkan Jump:
# -------------------------------------
#
# $ssh* - Array. Kumpulan dari informasi command ssh yang telah digenerate
# sesuai kebutuhan jump.
# ```
# $ssh_route_jumps = ( "" "staff-it@company.com:80" "staff-it@company.com:80,ijortengab@office.lan:2223" )
# $ssh_route_options = ( " -p 80" " -p 2223 -J staff-it@company.com:80" " -J staff-it@company.com:80,ijortengab@office.lan:2223" )
# $ssh_route_mass_arguments = ( "staff-it@company.com" "ijortengab@office.lan" "guest@virtualmachine.vm" )
# ```
#
# Variable khusus jika dibutuhkan Tunnel:
# ---------------------------------------
#
# $local_ports - Array. Penyimpanan local port yang telah didapat untuk
# keperluan local port forwarding. Digenerate oleh fungsi yang khusus
# menggenerate local port yang free (tidak sedang digunakan oleh aplikasi
# lain). Local port yang digunakan oleh `rcm` dimulai dari angka 49152.
#
# ```
# $local_ports = ( "50012" "50013" )
# ```
#
# $route-tunnel - Array. Kumpulan dari address untuk membuat tunnel, dimana
# address destination HARUS ditempatkan pada element terakhir diperlukan
# sebagai referensi. Pada umumnya $route-tunnel sama dengan $route kecuali
# pada kasus `open-port` dengan style `jump`.
#
# $tunnel* - Array. Informasi hasil parsing `$route-tunnel` untuk kebutuhan
# pembuatan command.
#
# $destination* - String. Informasi hasil parsing `$route-tunnel` untuk
# kebutuhan pembuatan command. Destination adalah host terakhir dari `$route`
# dan juga `$route-tunnel`.
#
# ```
# $route_tunnel = ( "staff-it@company.com:80" "ijortengab@office.lan:2223" "guest@virtualmachine.vm" )
# $tunnel_count = "2"
# $tunnel_hosts = ( "company.com" "localhost" )
# $tunnel_users = ( "staff-it" "ijortengab" )
# $tunnel_ports = ( "80" "50012" )
# $destination_host = "localhost"
# $destination_user = "guest"
# $destination_port = "50013"
# $tunnel_fwd_local_ports = ( "50012" "50013" )
# $tunnel_fwd_target_hosts = ( "office.lan" "virtualmachine.vm" )
# $tunnel_fwd_target_ports = ( "2223" "22" )
# ```
#
# $ssh* - Array. Kumpulan dari informasi command ssh yang telah digenerate
# sesuai kebutuhan tunnel.
#
# ```
# $ssh_tunnel_options = ( " -p 80 -fN -L 50012:office.lan:2223" " -p 50012 -fN -L 50013:virtualmachine.vm:22" )
# $ssh_tunnel_mass_arguments = ( "staff-it@company.com" "ijortengab@localhost" )
# $ssh_tunnel_command = ( "ssh -p 80 -fN -L 50012:office.lan:2223 staff-it@company.com" "ssh -p 50012 -fN -L 50013:virtualmachine.vm:22 ijortengab@localhost" )
# $ssh_tunnel_command_info_route = ( "staff-it@company.com:80" "ijortengab@office.lan:2223" )
# $ssh_route_options = ( " -p 80" " -p 50012" " -p 50013" )
# $ssh_route_mass_arguments = ( "staff-it@company.com" "ijortengab@localhost" "guest@localhost" )
# ```

# Mencetak variable untuk keperluan debug (pengecekan dan fixasi).
# Pencetakan disertai syntax highlighting dan hanya berlaku jika variable
# $debug=1 (default). Dapat mencetak array maupun non array (string/number).
#
# Options:
#   -f: Force print, tanpa mengindahkan variable $debug sebagai controller
#       fungsi ini.
#
# Globals:
#   Used: debug
#
# Arguments:
#   $@: Semua variable yang masuk akan dianggap sebagai parameter atau value
#        untuk kemudian dicetak.
#
# Returns:
#   1: Fungsi dibatalkan karena global variable $debug sebagai control bernilai
#      0 (false).
#
# Argument yang masuk akan dianggap parameter. Contoh:
#
# ```
# tujuan=Jakarta
# rute=("Jakarta" "Surabaya")
# varDump tujuan rute
# ```
#
# Hasil yang diperoleh (stdout) adalah:
#
# ```
# $tujuan = "Jakarta"
# $rute = ( "Jakarta" "Surabaya" )
# ```
#
# Untuk argument berupa variable numeric, maka sebaiknya menggunakan format
# label namun hanya berlaku untuk non array. Contoh:
#
# ```
# rute=("Jakarta" "Semarang" "Yogyakarta" "Surabaya")
# set -- ${rute[@]}
# varDump '<$1>'"$1" '<$2_before>'"$2"
# echo Proses disini
# varDump '<$2_after>'"$2"
# ```
#
# Hasil yang diperoleh (stdout) adalah:
#
# ```
# $1 = "Jakarta"
# $2_before = "Semarang"
# Proses disini
# $2_after = "Semarang"
# ```
#
# Argument yang tidak valid sebagai parameter, maka akan dicetak dengan
# mengganggap sebagai value.
varDump() {
    local i
    local globalVarName globalVarValue label value
    local normal red yellow cyan magenta
    if [[ $1 == '-f' ]];then
        shift
    elif [[ $debug == 0 ]];then
        return 1
    fi
    normal="$(tput sgr0)"
    red="$(tput setaf 1)"
    yellow="$(tput setaf 3)"
    cyan="$(tput setaf 6)"
    magenta="$(tput setaf 5)"
    while [[ $# -gt 0 ]]; do
        # Jika argument memiliki format khusus untuk labelling.
        # Yakni <...>....
        # Contoh:
        # ```
        # kondisi=mentah
        # varDump '<$tempe>'"$kondisi"
        # ```
        # Hasilnya adalah `$tempe = mentah`
        if [[ $1 =~ ^\<.*\> ]];then
            label=$(echo $1 | cut -d'>' -f1 | cut -c2-)
            value=$(echo $1 | cut -d'>' -f2 )
            printf "${cyan}$label${normal}${red} = ${normal}"
            printf "\"${yellow}$value${normal}\" \n"
            shift
            continue
        fi
        # Jika argument tidak valid sebagai parameter.
        if [[ $1 =~ [^0-9a-zA-Z_] ]];then
            printf "${magenta}$1${normal}\n"
            shift
            continue
        fi
        # Check jika variable tidak pernah diset.
        eval isset=\$\(if \[ -z \$\{$1+x\} \]\; then echo 0\; else echo 1\; fi\)
        if [ $isset == 0 ];then
            printf "${yellow}$1${normal}\n"
            shift
            continue
        fi
        # Check variable jika merupakan array.
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

# Mencetak versi dari program ssh yang sekarang sedang digunakan. Memparse
# output dari ssh -V mengembalikan nilai float. Contoh output: 7.2, 7.4
#
# Globals:
#   None
#
# Arguments:
#   None
#
# Returns:
#   None
getSshVersion() {
    echo $(ssh -V 2>&1 | grep -o -P 'OpenSSH_\K([0-9]+\.[0-9]+)')
}

# Membandingkan dua nomor versi, apakah lebih besar, lebih kecil, atau sama.
# Credit: https://stackoverflow.com/a/4025065/7074586
#
# Globals:
#   Used: IFS
#
# Arguments:
#   $1: Versi pertama
#   $2: Versi kedua
#
# Returns:
#   0: Versi pertama sama dengan versi kedua
#   1: Versi pertama lebih bersar dari versi kedua
#   2: Versi pertama lebih kecil dari versi kedua
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

# Mengecek apakah sebuah value sudah ada di dalam array.
# Credit: https://stackoverflow.com/a/8574392/7074586
#
# Globals:
#   None
#
# Arguments:
#   $1: Value yang akan dicek
#   $2: Array sebagai referensi
#
# Returns:
#   0: Value berada pada array
#   1: Value tidak berada pada array
inArray () {
    local e match="$1"
    shift
    for e; do [[ "$e" == "$match" ]] && return 0; done
    return 1
}

# Mengecek bilangan adalah genap.
#
# Globals:
#   None
#
# Arguments:
#   $1: Value yang akan dicek
#
# Returns:
#   0: Value adalah bilangan genap
#   1: Value bukan bilangan genap
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

# Mengecek bilangan adalah ganjil.
#
# Globals:
#   None
#
# Arguments:
#   $1: Value yang akan dicek
#
# Returns:
#   0: Value adalah bilangan ganjil
#   1: Value bukan bilangan ganjil
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

# Mengecek apakah mesin yang digunakan untuk eksekusi script ini adalah Cygwin.
#
# Globals:
#   None
#
# Arguments:
#   None
#
# Returns:
#   0: Mesin adalah Cygwin
#   1: Mesin bukan Cygwin
isCygwin () {
    if [[ $(uname | cut -c1-6) == "CYGWIN" ]];then
        return 0
    fi
    return 1
}

# Mencetak proses id (pid) berdasarkan command+argument.
#
# Globals:
#   Used: IFS
#
# Arguments:
#   $1: Command beserta argument yang dijalankan
#
# Returns:
#   None
getPid() {
    local pid command ifs
    if isCygwin;then
        ifs=$IFS
        ps -s | grep ssh | awk '{print $1}' | while IFS= read -r pid; do\
            command=$(cat /proc/${pid}/cmdline | tr '\0' ' ')
            command=$(echo "$command" | sed 's/\ $//')
            if [[ "$command" == "$1" ]];then
                echo $pid >&1
                break
            fi
        done
        IFS=$ifs
    else
        command="$1"
        pid=$(ps aux | grep "${command}" | grep -v grep | awk '{print $2}')
        echo $pid >&1
    fi
}

# Mengecek apakah port di localhost free dari di-listen oleh aplikasi.
#
# Globals:
#   None
#
# Arguments:
#   $1: Port yang akan dicek
#
# Returns:
#   0: Port adalah free
#   1: Port tidak free
isPortFree() {
    local port="$1" test
    if isCygwin;then
        test=`netstat -aon | grep 127.0.0.1:${port}`
        if [[ $test == "" ]];then
            return 0
        fi
        return 1
    fi
    test=`/bin/ss -nl | grep 127.0.0.1:${port}`
    if [[ $test == "" ]];then
        return 0
    fi
    return 1
}

# Mengeset options pada argument kedalam variable terkait.
#
# Globals:
#   Used: arguments
#   Modified: arguments, preview, verbose, through, style
#
# Arguments:
#   $1: Tipe looping (once or none)
#       Once artinya jika bertemu mass argument maka penge-set-an options
#       dihentikan.
#
# Returns:
#   None
setOptions() {
    local loop
    varDump 'Begin of function setOptions()'
    loop=$1
    set -- ${arguments[@]}
    arguments=()
    # Set options.
    while [[ $# -gt 0 ]]; do
        varDump '<$1>'"$1"
        case $1 in
        -) shift;;
        --preview|-p) preview=1 ; shift;;
        --quiet|-q) verbose=0 ; shift;;
        --last-one|-l) through=0 ; shift;;
        --style=*) style="$(echo $1 | cut -c9-)"; shift ;;
        --public-key=*) public_key="$(echo $1 | cut -c14-)"; shift ;;
        --number=*) numbering="$(echo $1 | cut -c15-)"; shift ;;
        -s) style=$2; shift; shift ;;
        -k) public_key=$2; shift; shift ;;
        -n) numbering=$2; shift; shift ;;
        *)
            if [[ $1 =~ ^- ]];then
                # Reset builtin function getopts.
                OPTIND=1
                while getopts ":pqls:k:n:" opt; do
                    varDump '<$opt>'"$opt"
                    case $opt in
                        p) preview=1 ;;
                        q) verbose=0 ;;
                        l) through=0 ;;
                        s) style="$OPTARG" ;;
                        k) public_key="$OPTARG" ;;
                        n) numbering="$OPTARG" ;;
                        \?) echo "Invalid option: -$OPTARG" >&2 ;;
                        :) echo "Option -$OPTARG requires an argument." >&2 ;;
                    esac
                done
                shift $((OPTIND-1))
            else
                # Mass arguments dikembalikan ke variable semula.
                if [[ $loop == once ]];then
                    while [[ $# -gt 0 ]]; do
                        arguments+=("$1")
                        shift
                    done
                    break
                else
                    arguments+=("$1")
                    shift
                fi
            fi
        esac
    done
    varDump 'End of function setOptions()'
}

# Validasi options yang diinput oleh user pada argument.
# Saat ini baru memvalidasi input style.
#
# Globals:
#   Used: style
#
# Arguments:
#   None
#
# Returns:
#   None
validateOptions() {
    local is_right
    # Variable $style yang dibolehkan adalah 'jump', 'tunnel', atau 'auto'.
    varDump 'Begin of function validateOptions()'
    varDump '<$style before>'"$style"
    is_right=0
    case $style in
        jump) is_right=1 ;;
        tunnel) is_right=1 ;;
        auto)
            is_right=1
            vercomp `getSshVersion` 7.3
            if [[ $? -lt 2 ]];then
                # ssh options -J available
                style=jump
            else
                # ssh options -J not available
                style=tunnel
            fi
    esac
    if [[ $is_right == 0 ]]; then
        error "Argument tidak dikenali pada opsi style: '${style}'."
    fi
    varDump '<$style after>'"$style"
    varDump 'End of function validateOptions()'
}

# Validasi mass argument yang digunakan oleh internal command.
#
# Globals:
#   Used: arguments
#
# Arguments:
#   None
#
# Returns:
#   None
validateArgumentsBeforePopulateRoute() {
    local i j
    for (( i=0; i < ${#arguments[@]} ; i++ )); do
        j=$(( $i + 1 ))
        if [[ ${arguments[$i]} =~ " " ]];then
            error "Error. Argument '${arguments[$i]}' mengandung karakter spasi."
        fi
        if isEven $j ;then
            if [[ ! ${arguments[$i]} == 'via' ]];then
                error "Error. Argument '${arguments[$i]}' tidak didahului dengan 'via'."
            fi
        fi
    done
    if isEven ${#arguments[@]};then
        error "Error. Argument kurang lengkap."
    fi
}

# Validasi jumlah minimal argument.
#
# Globals:
#   Used: arguments
#
# Arguments:
#   None
#
# Returns:
#   None
validateMinimalArgument() {
    if [[ ${#arguments[@]} -lt $1 ]];then
        error "Argument terlalu sedikit. Setidaknya dibutuhkan $1."
    fi
}

# Validasi keberadaan public key.
#
# Globals:
#   Used: public_key
#
# Arguments:
#   None
#
# Returns:
#   None
validatePublicKey() {
    local tester is_exists
    is_exists=0
    if [[ $public_key == 'auto' ]];then
        tester=("$HOME/.ssh/id_rsa.pub" "$HOME/.ssh/id_dsa.pub"
                "$HOME/.ssh/id_ecdsa.pub" "$HOME/.ssh/id_ed25519.pub")
    else
        tester=("$public_key")
    fi
    for string in "${tester[@]}"
    do
        if [ -e "$string" ];then
            public_key="$string"
            is_exists=1
            break
        fi
    done
    if [[ $is_exists == 0 ]];then
        if [[ $public_key == 'auto' ]];then
            error "Public key tidak ditemukan."
        else
            error "Public key '$public_key' tidak ditemukan."
        fi
    fi
}

# Validasi argument port numbering.
#
# Globals:
#   Used: RCM_DIR_PORTS, numbering, route, route_hosts
#
# Arguments:
#   None
#
# Returns:
#   None
validateNumberingOpenPort() {
    local host_port z
    if [[ $numbering == 'auto' ]];then
        return 0
    fi
    if [[ ! $numbering =~ ^[1-9]+[0-9]*$ ]];then
        error "Port number invalid." # Include zero.
    fi
    if [[ $numbering -gt 65535  ]];then
        error "Port number must lower than 65536."
    fi
    if isPortFree ${numbering};then
        z=$(( ${#route[@]} - 1 ))
        last_host=${route_hosts[$z]}
        mkdir -p $RCM_DIR_PORTS
        cd $RCM_DIR_PORTS
        host_port=`ls -U | grep $numbering | head -1 | xargs cat`
        if [[ $host_port == "" ]];then
            echo $last_host > $numbering
        else
            if [[ ! $host_port == $last_host ]];then
                error "Port ${numbering} has been assigned to host '${host_port}'."
            fi
        fi
    else
        error "Port ${numbering} sedang digunakan."
    fi
}

# Mencetak error ke STDERR kemudian exit.
#
# Globals:
#   None
#
# Arguments:
#   $1: String yang akan dicetak
#
# Returns:
#   None
error() {
    echo -e "\e[91m""$1""\e[39m" >&2
    exit 1
}

# Eksekusi berdasarkan (sub) command.
#
# Globals:
#   Used: command
#
# Arguments:
#   None
#
# Returns:
#   None
execute() {
    varDump 'Begin of function execute()'
    varDump command
    case $command in
        login)
            validateMinimalArgument 1
            validateArgumentsBeforePopulateRoute
            populateRoute
            executeLogin
            ;;
        send-key)
            validateMinimalArgument 1
            validatePublicKey
            validateArgumentsBeforePopulateRoute
            populateRoute
            executeSendKey
            ;;
        open-port)
            validateMinimalArgument 2
            prepareFirstArgumentAsPort
            validateArgumentsBeforePopulateRoute
            populateRoute
            validateNumberingOpenPort
            modifyRouteBeforeOpenPort
            executeOpenPort
    esac
    varDump 'End of function execute()'
}

# Eksekusi command login.
#
# Globals:
#   Used: route, style
#         ssh_route_options, ssh_route_mass_arguments
#   Modified: route_tunnel
#
# Arguments:
#   None
#
# Returns:
#   None
executeLogin() {
    varDump 'Begin of function executeLogin()'
    local z last_route ssh_options ssh_mass_arguments
    z=$(( ${#route[@]} - 1 )) # last index of route.
    case $style in
        tunnel)
            route_tunnel=(${route[@]})
            populateTunnel
            writeLinesTunnels
            writeLinesCheckTunnels
            ;;
        jump)
            populateJump
    esac
    ssh_options="${ssh_route_options[$z]}"
    ssh_mass_arguments=${ssh_route_mass_arguments[$z]}
    last_route=${route[$z]}
    writeLinesVerbose 'echo -e "\e[93m'"SSH Connect to ${last_route}"'\e[39m"'
    writeLines "ssh${ssh_options} ${ssh_mass_arguments}"
    generateCode
    varDump 'End of function executeLogin()'
}

# Eksekusi command send-key dengan menggenerate code.
#
# Globals:
#   Used: route, style, tunnel_count, through
#         ssh_route_options, ssh_route_mass_arguments
#         ssh_tunnel_options, ssh_tunnel_mass_arguments
#
# Arguments:
#   None
#
# Returns:
#   None
executeSendKey() {
    local i z destination ssh_options ssh_mass_arguments
    varDump 'Begin of function executeSendKey()'
    case $style in
        tunnel)
            route_tunnel=(${route[@]})
            populateTunnel
            z=$(( ${#route[@]} - 1 ))
            for (( i=0; i < ${#route[@]} ; i++ )); do
                destination=${route[$i]}
                ssh_options=${ssh_route_options[$i]}
                ssh_mass_arguments=${ssh_route_mass_arguments[$i]}
                if [[ ! $i == $z ]];then
                    if [[ $through == "1" ]];then
                        writeLinesSendKey "$destination" "$ssh_options" "$ssh_mass_arguments"
                        writeLines ''
                    fi
                    writeLinesTunnelsCreate $i
                    writeLinesTunnelsDestroy $i post
                else
                    writeLinesCheckTunnels
                    writeLinesSendKey "$destination" "$ssh_options" "$ssh_mass_arguments"
                fi
            done
            ;;
        jump)
            populateJump
            z=$(( ${#route[@]} - 1 ))
            for (( i=0; i < ${#route[@]} ; i++ )); do
                destination=${route[$i]}
                ssh_options=${ssh_route_options[$i]}
                ssh_mass_arguments=${ssh_route_mass_arguments[$i]}
                if [[ ! $i == $z ]];then
                    if [[ $through == "1" ]];then
                        writeLinesSendKey "$destination" "$ssh_options" "$ssh_mass_arguments"
                        writeLines ''
                    fi
                else
                    writeLinesSendKey "$destination" "$ssh_options" "$ssh_mass_arguments"
                fi
            done
    esac
    generateCode
    varDump 'End of function executeSendKey()'
}

# Eksekusi command open-port dengan menggenerate code.
#
# Globals:
#   Used: route, route_hosts, route_ports, style, tunnel_count
#   Modified: ssh_tunnel_options, add_var_tunnel_success
#
# Arguments:
#   None
#
# Returns:
#   None
executeOpenPort() {
    varDump 'Begin of function executeOpenPort()'
    local h i n y z line last y last_host last_port
    local ssh_options ssh_mass_arguments local_port
    z=$(( ${#route[@]} - 1 ))
    y=$(( $z - 1 ))
    last_host=${route_hosts[$z]}
    last_port=${route_ports[$z]}
    case $style in
        tunnel)
            route_tunnel=(${route[@]})
            populateTunnel
            for (( i=0; i < $tunnel_count ; i++ )); do
                writeLinesTunnelsCreate $i pre
            done
            ;;
        jump)
            populateJump
            # Prepare before populateTunnel.
            last_route=${route[$z]}
            second_to_last_route=${route[$y]}
            route_tunnel=("$second_to_last_route" "$last_route")
            ssh_tunnel_options=("${ssh_route_options[$y]}")
            # Create tunnel.
            populateTunnel
            writeLinesTunnelsCreate 0 pre
            ;;
    esac
    writeLinesCheckTunnels
    writeLinesVerbose 'echo -e "\e[93m'"Access to ${last_host} port ${last_port} opened from localhost port \e[95m${destination_port}\e[93m."'\e[39m"'
    if [[ $verbose == 0 ]];then
        # Output minimal ketika quiet adalah result dari open port.
        writeLines 'echo '$destination_port' >&1'
    fi
    generateCode
    varDump 'End of function executeOpenPort()'
}

# Mengisi value dari variable $route* dan lainnya yang terkait.
#
# Globals:
#   Used: arguments
#   Modified: route, route_hosts, route_users, route_ports
#
# Arguments:
#   None
#
# Returns:
#   None
populateRoute() {
    local i z
    local _host _user _port
    varDump 'Begin of function populateRoute()'
    z=$(( ${#arguments[@]} - 1 ))
    for (( i=$z; i >= 0 ; i-- )); do
        if isOdd $i;then
            continue
        fi
        route+=("${arguments[$i]}")
        explodeAddress "${arguments[$i]}"
        route_hosts+=("$_host")
        route_users+=("$_user")
        route_ports+=("$_port")
    done
    varDump route route_hosts route_users route_ports
    varDump 'End of function populateRoute()'
}

# Mengisi value dari variable $ssh_route_jumps dan lainnya yang terkait.
#
# Globals:
#   Used: route
#   Modified: ssh_route_jumps, ssh_route_options, ssh_route_mass_arguments
#
# Arguments:
#   None
#
# Returns:
#   None
populateJump() {
    local h i first second last
    local cmd ssh_options ssh_mass_arguments _host _user _port
    varDump 'Begin of function populateJump()'
    first=0
    second=1
    last=$(( ${#route[@]} - 1 ))
    cmd=
    for (( i=0; i < ${#route[@]} ; i++ )); do
        h=$(( $i - 1 ))
        if [[ $i -gt $first ]];then
            if [[ $i == $second ]];then
                cmd+="${route[$h]}"
            else
                cmd+=",${route[$h]}"
            fi
        fi
        explodeAddress "${route[$i]}" # populate _host _user _port
        ssh_options=''
        ssh_mass_arguments=${_host}
        if [[ ! $_user == "@" ]];then
            ssh_mass_arguments="${_user}@${_host}"
        fi
        if [[ ! ${_port} == 22 ]];then
            ssh_options+=" -p ${_port}"
        fi
        if [[ ! $cmd == '' ]];then
            ssh_options+=" -J ${cmd}"
        fi
        ssh_route_jumps+=("$cmd")
        ssh_route_options+=("$ssh_options")
        ssh_route_mass_arguments+=("$ssh_mass_arguments")
    done
    varDump ssh_route_jumps ssh_route_options ssh_route_mass_arguments
    varDump 'End of function populateJump()'
}

# Mengisi value dari variable $tunnel* dan lainnya yang terkait.
#
# Globals:
#   Used: route_tunnel, ssh_tunnel_options
#   Modified: tunnel_count
#             tunnel_hosts tunnel_users tunnel_ports
#             destination_host destination_user destination_port
#             tunnel_fwd_local_ports
#             tunnel_fwd_target_hosts
#             tunnel_fwd_target_ports
#             ssh_tunnel_command, ssh_tunnel_command_info_route
#             ssh_tunnel_options, ssh_tunnel_mass_arguments
#
# Arguments:
#   None
#
# Returns:
#   None
populateTunnel() {
    local h i j n first_index last_index
    local _host _user _port hosts users ports ssh_options ssh_mass_arguments
    local cmd set_random_port
    varDump 'Begin of function populateTunnel()'
    varDump route_tunnel
    first_index=0
    tunnel_count=$(( ${#route_tunnel[@]} - 1 ))
    last_index=$(( ${#route_tunnel[@]} - 1 )) # Last index of route_tunnel
    varDump 'Populate variable.'
    for (( i=0; i < ${#route_tunnel[@]} ; i++ )); do
        varDump '<$i>'"$i"
        h=$(( $i - 1))
        explodeAddress "${route_tunnel[$i]}"
        if [[ $i == $first_index ]];then
            tunnel_host=$_host
            tunnel_port=$_port
        else
            set_random_port=1
            if [[ $i == $last_index ]];then
                if [[ ! $numbering == 'auto' ]];then
                    set_random_port=0
                    _local_port=$numbering
                fi
            fi
            if [[ $set_random_port == 1 ]];then
                getRandomLocalPorts $_host
            fi
            tunnel_host=localhost
            tunnel_port=$_local_port
            tunnel_fwd_local_ports[$h]=$_local_port
            tunnel_fwd_target_hosts[$h]=$_host
            tunnel_fwd_target_ports[$h]=$_port
        fi
        if [[ ! $i == $last_index ]];then
            tunnel_hosts+=("$tunnel_host")
            tunnel_users+=("$_user")
            tunnel_ports+=("$tunnel_port")
        else
            destination_host="$tunnel_host"
            destination_user="$_user"
            destination_port="$tunnel_port"
        fi
    done
    varDump tunnel_count
    varDump tunnel_hosts tunnel_users tunnel_ports
    varDump destination_host destination_user destination_port
    varDump tunnel_fwd_local_ports tunnel_fwd_target_hosts tunnel_fwd_target_ports
    varDump 'Begin of Pengecekan port.'
    varDump '--'
    varDump tunnel_ports destination_port
    varDump '--'
    # Populate ssh for tunnel and make sure port not used.
    last_index=$(( $tunnel_count - 1 )) # Last index of tunnel.
    for (( i=0; i < $tunnel_count ; i++ )); do
        varDump '<$i Line 1032>'"$i"
        j=$(( $i+1 ))
        constructSshTunnelCommand $i
        pid=`getPid "${_command}"`
        varDump '<$pid>'"$pid"
        if [[ $pid == '' ]];then
            n=1
            max=10
            port_used=1
            port_changed=0
            while :
            do
                if [[ ${tunnel_fwd_local_ports[$i]} == $numbering ]];then
                    # Jika option -n didefinisikan, maka auto correct off.
                    port_used=0
                    break
                fi
                pid=`getPid "${_command}"`
                varDump '<$pid>'"$pid"
                if [[ ! $pid == '' ]];then
                    port_used=0
                    break
                fi
                if isPortFree ${tunnel_fwd_local_ports[$i]};then
                    port_used=0
                    break
                fi
                port_changed=1
                getRandomLocalPorts ${tunnel_fwd_target_hosts[$i]}
                tunnel_fwd_local_ports[$i]=$_local_port
                constructSshTunnelCommand $i
                let n++
                if [[ $n -gt $max ]];then
                    break
                fi
            done
            varDump '<$n>'"$n"
            varDump '<$port_used>'"$port_used"
            varDump '<$port_changed>'"$port_changed"
            varDump '<$command (final)>'"$_command"
            if [[ $port_used == 1 ]];then
                error "Local port untuk koneksi ke ${tunnel_fwd_target_hosts[$i]} tidak dapat diciptakan. Pengecekan $max kali."
            fi
            if [[ $port_changed == 1 ]];then
                if [[ ! $last_index == $i ]];then
                    tunnel_ports[$j]=$_local_port
                else
                    destination_port=$_local_port
                fi
            fi
        fi
        ssh_tunnel_command+=("$_command")
        ssh_tunnel_mass_arguments+=("$_ssh_mass_arguments")
        ssh_tunnel_options+=("$_ssh_options")
        ssh_tunnel_command_info_route+=(${route_tunnel[$i]})
    done
    # Populate ssh for destination.
    # maybe gak diperlukan lagi.
    varDump 'Hasil final port tersedia.'
    varDump '--'
    varDump tunnel_ports destination_port
    varDump '--'
    varDump 'End of Pengecekan port.'
    varDump ssh_tunnel_options ssh_tunnel_mass_arguments
    varDump ssh_tunnel_command ssh_tunnel_command_info_route


    # Populate ssh_route_options, ssh_route_mass_arguments.
    last_index=$(( ${#route_tunnel[@]} - 1 )) # Last index of route_tunnel.
    for (( i=0; i < ${#route_tunnel[@]} ; i++ )); do
        ssh_options=''
        ssh_mass_arguments=''
        if [[ ! $i == $last_index ]];then
            _host=${tunnel_hosts[$i]}
            _user=${tunnel_users[$i]}
            _port=${tunnel_ports[$i]}
        else
            _host=$destination_host
            _user=$destination_user
            _port=$destination_port
        fi
        ssh_mass_arguments=$_host
        if [[ ! $_user == "@" ]];then
            ssh_mass_arguments=${_user}@${_host}
        fi
        if [[ ! $_port == 22 ]];then
            ssh_options+=" -p ${_port}"
        fi
        ssh_route_options+=("$ssh_options")
        ssh_route_mass_arguments+=("$ssh_mass_arguments")
    done
    varDump ssh_route_options ssh_route_mass_arguments
    varDump 'End of function populateTunnel()'
}

# Mengisi variable $local_port berdasarkan host.
#
# Globals:
#   Used: RCM_DIR_PORTS
#   Modified: _local_port, local_ports
#
# Arguments:
#   $1: Host yang akan diberikan nomor local port
#
# Returns:
#   None
#
# Port dimulai dari angka $RCM_PORT_START dan terus sampai mentok.
# Satu host bisa memiliki banyak local port tergantung kebutuhan pembuatan
# tunnel. Oleh karena itu dibuat global variable $local_ports sebagai
# penyimpanan referensi berbagai local port yang telah dibuat.
getRandomLocalPorts() {
    varDump 'Begin of function getRandomLocalPorts()'
    local string files port file
    mkdir -p "${RCM_DIR_PORTS}"
    cd "${RCM_DIR_PORTS}"
    varDump '<$1>'"$1"
    files=(`grep -r $1 | cut -d: -f1 | sort -n`)
    varDump files
    port=
    for string in "${files[@]}"
    do
        if inArray $string "${local_ports[@]}";then
            continue
        else
            port=$string
            break
        fi
    done
    if [[ $port == "" ]];then
        file=$RCM_PORT_START
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
    _local_port="$port"
    local_ports+=("$port")
    varDump _local_port local_ports
    varDump 'End of function getRandomLocalPorts()'
}

# Mempersiapkan kondisi jika argument pertama diketahui sebagai port.
#
# Globals:
#   Used: arguments
#   Modified: _argument_port, arguments
#
# Arguments:
#   None
#
# Returns:
#   None
prepareFirstArgumentAsPort() {
    varDump 'Begin of function prepareFirstArgumentAsPort() '
    set -- ${arguments[@]}
    if [[ $1 =~ ^[0-9]+$ ]];then
        _argument_port="$1"
        shift
        arguments=()
        while [[ $# -gt 0 ]]; do
            arguments+=("$1")
            shift
        done
    fi
    varDump '<$_argument_port>'"$_argument_port" arguments
    varDump 'End of function prepareFirstArgumentAsPort() '
}

# Melakukan modifikasi rute terkait subcommand open-port.
#
# Globals:
#   Used: _argument_port, route
#   Modified: route, route_hosts, route_users, route_ports
#
# Arguments:
#   None
#
# Returns:
#   None
modifyRouteBeforeOpenPort() {
    varDump 'Begin of function modifyRouteBeforeOpenPort() '
    local last_index _host _port _user next
    if [[ ! $_argument_port == '' ]];then
        last_index=$(( ${#route[@]} -1 ))
        last_route=${route[$last_index]}
        explodeAddress "$last_route"
        _port=$_argument_port
        next=`implodeAddress "$_host" "$_user" "$_port"`
        route+=("$next")
        route_hosts+=("$_host")
        route_users+=("$_user")
        route_ports+=("$_port")
        varDump route route_hosts route_users route_ports
    fi
    varDump 'End of function modifyRouteBeforeOpenPort() '
}

# Memecah address dengan format [USER@]HOST[:PORT] dengan mengisi variable
# terkait yakni $_user, $_host, $_port.
#
# Globals:
#   Modified: _user, _host, _port
#
# Arguments:
#   $1: address dengan format [USER@]HOST[:PORT]
#
# Returns:
#   None
explodeAddress() {
    _host="$1"
    _user=$(echo $_host | grep -E -o '^[^@]+@')
    if [[ $_user == "" ]];then
        _user=@
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
}

# Merakit kemudian mencetak address dari element user, host, port.
#
# Globals:
#   None
#
# Arguments:
#   $1: Host
#   $2: User
#   $3: Port
#
# Returns:
#   None
implodeAddress() {
    local host user port
    host=$1
    user=$2
    port=$3
    if [[ ! $user == "" ]];then
        if [[ ! $user == "@" ]];then
            host="${user}@${host}"
        fi
    fi
    if [[ ! $port == "" ]];then
        if [[ ! $port == "22" ]];then
            host="${host}:${port}"
        fi
    fi
    echo $host
}

# Merakit kemudian mencetak ssh command untuk membuat tunnel.
#
# Globals:
#   Used: tunnel_users, tunnel_hosts, tunnel_ports
#         tunnel_fwd_local_ports
#         tunnel_fwd_target_hosts
#         tunnel_fwd_target_ports
#   Modified: _command, _ssh_mass_arguments, _ssh_options
#
# Arguments:
#   $1: key index dari array tunnel_*.
#
# Returns:
#   None
constructSshTunnelCommand() {
    local i
    varDump 'Begin of function constructSshTunnelCommand()'
    varDump '<Tunnel index $1>'"$1"
    # Reset.
    _ssh_options=
    _ssh_mass_arguments=
    i=$1
    _ssh_options=${ssh_tunnel_options[$i]}
    if [[ ! ${tunnel_users[$i]} == '@' ]];then
        _ssh_mass_arguments+="${tunnel_users[$i]}"@
    fi
    _ssh_mass_arguments+="${tunnel_hosts[$i]}"
    if [[ ! ${tunnel_ports[$i]} == '22' ]];then
        _ssh_options+=" -p ${tunnel_ports[$i]}"
    fi
    _ssh_options+=" -fN -L ${tunnel_fwd_local_ports[$i]}:${tunnel_fwd_target_hosts[$i]}:${tunnel_fwd_target_ports[$i]}"
    _command="ssh${_ssh_options} ${_ssh_mass_arguments}"
    varDump _command _ssh_options _ssh_mass_arguments
    varDump 'End of function constructSshTunnelCommand()'
}

# Menulis baris-baris code (ssh command) untuk membuat dan menghapus tunnel.
# Hasil code disimpan di variable $lines*.
#
# Globals:
#   Used: tunnel_count
#
# Arguments:
#   $1: key index dari array tunnel_*
#   $2: position dari variable lines (pre, post, "")
#
# Returns:
#   None
writeLinesTunnels() {
    local i
    for (( i=0; i < $tunnel_count ; i++ )); do
        writeLinesTunnelsCreate $i pre
        writeLinesTunnelsDestroy $i post
    done
}

# Menulis baris-baris code (ssh command) untuk membuat tunnel.
# Hasil code disimpan di variable $lines*.
#
# Globals:
#   Used: ssh_tunnel_command, ssh_tunnel_command_info_route
#   Modified: add_func_get_pid_cygwin
#
# Arguments:
#   $1: key index dari array tunnel_*
#   $2: position dari variable lines (pre, post, "")
#
# Returns:
#   None
writeLinesTunnelsCreate() {
    local i
    local position port pid command
    i=$1
    if [[ $i == '' ]];then
        i=0
    fi
    position=$2
    writeLinesVerbose   'echo -e "\e[93m'"SSH Connect. Create tunnel on ${ssh_tunnel_command_info_route[$i]}."'\e[39m"' $position
    command="${ssh_tunnel_command[$i]}"
    pid=`getPid "${command}"`
    if [[ $pid == "" ]];then
        add_var_tunnel_success=1
        writeLines          "${ssh_tunnel_command[$i]}" $position
        if isCygwin;then
            add_func_get_pid_cygwin=1
            writeLines      "pid=\$(getPidCygwin \"${ssh_tunnel_command[$i]}\")" $position
        else
            writeLines      "pid=\$(ps aux | grep \"${ssh_tunnel_command[$i]}\" | grep -v grep | awk '{print \$2}')" $position
        fi
        writeLines          "if [[ \$pid == '' ]];then" $position
        writeLines          "    tunnel_success=0" $position
        writeLinesVerbose   '    echo -e "\e[93m- \e[91mFailed\e[93m.\e[39m"' $position
        writeLinesVerbose   "else" $position
        writeLinesVerbose   '    echo -e "\e[93m- \e[92mSuccess\e[93m. Process id: \e[95m${pid}\e[93m.\e[39m"' $position
        writeLines          "fi" $position
        writeLines          '' $position
    else
        writeLinesVerbose   'echo -e "\e[93m'"- Exists. Process id: \e[95m${pid}\e[93m."'\e[39m"' $position
        writeLinesVerbose '' $position
    fi
}

# Menulis baris-baris code (ssh command) untuk menghapus tunnel.
# Hasil code disimpan di variable $lines*.
#
# Globals:
#   Used: tunnel_count, ssh_tunnel_command, ssh_tunnel_command_info_route
#   Modified: add_func_get_pid_cygwin
#
# Arguments:
#   $1: key index dari array tunnel_*
#   $2: position dari variable lines (pre, post, "")
#
# Returns:
#   None
writeLinesTunnelsDestroy() {
    local i position last_index
    i=$1
    position=$2
    last_index=$(( $tunnel_count - 1 ))
    i=$(( $last_index - $i ))
    writeLines '' $position
    writeLinesVerbose   'echo -e "\e[93m'"Destroy tunnel on ${route[$i]}."'\e[39m"' $position
    if isCygwin;then
        add_func_get_pid_cygwin=1
        writeLines "kill \$(getPidCygwin \"${ssh_tunnel_command[$i]}\")" $position
    else
        writeLines "kill \$(ps aux | grep \"${ssh_tunnel_command[$i]}\" | grep -v grep | awk '{print \$2}')" $position
    fi
}

# Menulis baris-baris code (ssh command) untuk mengecek status tunnel.
# Hasil code disimpan di variable $lines*.
#
# Globals:
#   Used: add_var_tunnel_success
#   Modified: lines_define
#
# Arguments:
#   $1: position dari variable lines (pre, post, "")
#
# Returns:
#   None
writeLinesCheckTunnels() {
    position="$1"
    if [[ $add_var_tunnel_success == 1 ]];then
        lines_define+=("tunnel_success=1")
        writeLines        'if [[ $tunnel_success == 0 ]];then' $position
        writeLinesVerbose '    echo -e "\e[93m'"Tunnel gagal dibuat, proses dihentikan."'\e[39m"' $position
        writeLines        '    exit 1' $position
        writeLines        'fi' $position
        writeLines        '' $position
    fi
}

# Menulis baris-baris code untuk menyertakan fungsi getPidCygwin.
# Hasil code disimpan di variable $lines_function.
#
# Globals:
#   None
#
# Arguments:
#   None
#
# Returns:
#   None
writeLinesAddGetPidCygwin() {
    lines_function+=("getPidCygwin() {")
    lines_function+=("    local pid command ifs")
    lines_function+=("    ifs=\$IFS")
    lines_function+=("    ps -s | grep ssh | awk '{print \$1}' | while IFS= read -r pid; do\\")
    lines_function+=("        command=\$(cat /proc/\${pid}/cmdline | tr '\0' ' ')")
    lines_function+=("        command=\$(echo \"\$command\" | sed 's/\ \$//')")
    lines_function+=("        if [[ \"\$command\" == \"\$1\" ]];then")
    lines_function+=("            echo \$pid")
    lines_function+=("            break")
    lines_function+=("        fi")
    lines_function+=("    done")
    lines_function+=("    IFS=\$ifs")
    lines_function+=("}")
}

# Menyimpan code kedalam variable $lines*
#
# Globals:
#   None
#
# Arguments:
#   $1: Position dari variable lines (pre, post, "")
#   $2: Code yang akan digenerate
#
# Returns:
#   None
writeLines() {
    case $2 in
        pre) lines_pre+=("$1") ;;
        post) lines_post+=("$1") ;;
        *) lines+=("$1")
    esac
}

# Menyimpan code kedalam variable $lines* jika verbose aktif.
#
# Globals:
#   None
#
# Arguments:
#   $1: Position dari variable lines (pre, post, "")
#   $2: Code yang akan digenerate
#
# Returns:
#   None
writeLinesVerbose() {
    if [[ $verbose == 1 ]];then
        writeLines "$1" "$2"
    fi
}

# Menulis baris-baris code untuk mengirim public key.
# Hasil code disimpan di variable $lines*.
#
# Globals:
#   Used: tunnel_count, ssh_tunnel_command, ssh_tunnel_command_info_route
#   Modified: add_func_get_pid_cygwin
#
# Arguments:
#   $1: destination
#   $2: options
#   $3: mass_arguments
#
# Returns:
#   None
writeLinesSendKey() {
    local destination _options options mass_arguments line
    destination="$1"
    options="$2"
    mass_arguments="$3"
    _options="$options"
    options+=" -o PreferredAuthentications=publickey -o PasswordAuthentication=no"
    writeLinesVerbose 'echo -e "\e[93mTest SSH connect to '"${destination}"' using key.\e[39m"'
    writeLines        "if [[ ! \$(ssh${options} ${mass_arguments} 'echo 1' 2>/dev/null) == 1 ]];then"
    writeLinesVerbose '    echo -e "\e[93m- SSH connect using key is failed. It means process continues.\e[39m"'
    writeLinesVerbose '    echo -e "\e[93m- You need input password twice to sending public key.\e[39m"'
    writeLinesVerbose '    echo -e "\e[93mFirstly, SSH connect to make sure ~/.ssh/authorized_keys on '"${destination}"' exits.\e[39m"'
    options=$_options
    line="ssh${options} ${mass_arguments}"
    writeLines        "    ${line} 'mkdir -p .ssh && chmod 700 .ssh && touch .ssh/authorized_keys && chmod 640 .ssh/authorized_keys'"
    writeLinesVerbose '    echo -e "\e[93mSecondly, SSH connect again to sending public key to '"${destination}"'.\e[39m"'
    writeLines        "    cat ${public_key} | ${line} 'cat >> .ssh/authorized_keys'"
    writeLinesVerbose '    echo -e "\e[93mRetest SSH connect to '"${destination}"' using key.\e[39m"'
    options=$_options
    options+=" -o PreferredAuthentications=publickey -o PasswordAuthentication=no"
    writeLinesVerbose "    if [[ ! \$(ssh${options} ${mass_arguments} 'echo 1' 2>/dev/null) == 1 ]];then"
    writeLinesVerbose '        echo -e "\e[93m- \e[91mFailed\e[93m.\e[39m"'
    writeLinesVerbose '    else'
    writeLinesVerbose '        echo -e "\e[93m- \e[92mSuccess\e[93m.\e[39m"'
    writeLinesVerbose '    fi'
    writeLinesVerbose 'else'
    writeLinesVerbose '    echo -e "\e[93m- SSH connect using key is successful thus sending key is not necessary.\e[39m"'
    writeLines        'fi'
}

# Generate code kemudian preview atau eksekusi.
#
# Globals:
#   Used: RCM_ROOT, RCM_EXE, add_func_get_pid_cygwin, add_var_tunnel_success
#         lines_define, lines_function, lines_pre, lines, lines_post
#         preview
#
# Arguments:
#   None
#
# Returns:
#   None
generateCode() {
    local execute=1 string compileLines
    varDump 'Begin of function generateCode()'
    if [[ $add_func_get_pid_cygwin == 1 ]];then
        writeLinesAddGetPidCygwin
    fi
    compileLines=()
    if [[ ${#lines_define[@]} -gt 0 ]];then
        lines_define+=("") # Beri space.
    fi
    for string in "${lines_define[@]}"
    do
        compileLines+=("$string")
    done
    for string in "${lines_function[@]}"
    do
        compileLines+=("$string")
    done
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
    if [[ $preview == 1 ]];then
        execute=0
        echo -ne "\e[32m"
        echo "#!/bin/bash"
        for string in "${compileLines[@]}"
        do
            echo "$string"
        done
        echo -ne "\e[39m"
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
    varDump 'End of function generateCode()'
}

# Jika dari terminal. Contoh: `rcm ssh user@localhost`.
if [ -t 0 ]; then
    # Process Reguler via terminal.
    # Jika tidak ada argument.
    if [[ $1 == "" ]];then
        # clear
        # Coming Soon.
        exit
    fi
# Jika dari standard input. Contoh: `echo ssh user@localhost | rcm`.
else
    set -- ${@:-$(</dev/stdin)}
    # Process Standard Input.
fi
# Parse options (locate between rcm and command).
while [[ $# -gt 0 ]]; do
    # varDump '<$1>'"$1"
    arguments+=("$1")
    shift
done
# varDump arguments
setOptions once
# varDump arguments
set -- ${arguments[@]}
if [[ $# == 0 ]];then
    error "Command not found."
fi
case "$1" in
    login|send-key|push|pull|manage|open-port|mount)
        command="$1"
        shift
        ;;
    *)
        error "Command unknown: '$1'."
esac
# Parse options (locate after command).
arguments=("$@")
varDump arguments
setOptions
varDump arguments
varDump verbose preview through style public_key numbering
validateOptions
varDump arguments
execute
