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
# - temporary variable prefix with _underscore.
# - function is camelCase.
# - indent is 4 spaces.

# Define.
RCM_ROOT=$HOME/.config/rcm
RCM_DIR_PORTS=$RCM_ROOT/ports
RCM_EXE=$RCM_ROOT/exe

# Default value of options.
options=()
verbose=1
interactive=0
preview=0
through=1
style=auto

# Developer only. Flag untuk mengaktifkan fungsi varDump.
debug=0

# Informasi Global Variables.
#
# Lines untuk menjadi storage baris-baris generated code.
#
# lines_define=()
# lines_function=()
# lines_pre=()
# lines=()
# lines_post=()
#
#
# $arguments adalah array penampungan terhadap argument. Flexible, value dari
# variable ini dapat berubah-ubah.
#
# Contoh:
#
# ```
# rcm -iq send-key -option --long-option satu dua ti\ ga
# ```
#
# Dari contoh diatas, maka nilai dari variable ini sama dengan
# arguments=("-iq" "send-key" "-option" "--long-opition" satu dua "ti ga")
#
# Variable $route adalah kumpulan dari host yang dilalui dimana element pertama
# adalah tunnel/jump pertama, element terakhir adalah destination.
# Tiap element menggunakan format: [USER@]HOST[:PORT].
# Variable lainnya dibangun perdasarkan $route.
#
# Contoh:
#
# ```
# rcm -p login guest@virtualmachine.vm via ijortengab@office.lan:2223 via staff-it@company.com:80
# ```
#
# maka,
# $route = ( "staff-it@company.com:80" "ijortengab@office.lan:2223" "guest@virtualmachine.vm" )
# $route_hosts = ( "company.com" "office.lan" "virtualmachine.vm" )
# $route_users = ( "staff-it" "ijortengab" "guest" )
# $route_ports = ( "80" "2223" "22" )
# $route_ssh_options = (
#     " -p 80" " -p 2223 -J staff-it@company.com:80"
#     " -J staff-it@company.com:80,ijortengab@office.lan:2223"
# )
# $route_ssh_mass_arguments = ( "staff-it@company.com" "ijortengab@office.lan" "guest@virtualmachine.vm" )
# $route_tunnel_hosts = ( "company.com" "localhost" )
# $route_tunnel_ports = ( "80" "50002" )
# $route_ssh_tunnel_mass_arguments = ( "staff-it@company.com" "ijortengab@localhost" )
# $route_ssh_tunnel_options = ( " -p 80" " -p 50002" )
# $route_last_host = "localhost"
# $route_last_user = "guest"
# $route_last_port = "50003"
# $route_last_ssh_options = " -p 50003"
# $route_last_ssh_mass_arguments = "guest@localhost"
# $ssh_tunnel_create_info = (
#     "SSH Connect. Create tunnel on staff-it@company.com:80."
#     "SSH Connect. Create tunnel on ijortengab@office.lan:2223."
# )
# $ssh_tunnel_create = (
#     "ssh -p 80 -fN -L 50002:office.lan:2223 -o ServerAliveInterval=30 staff-it@company.com"
#     "ssh -p 50002 -fN -L 50003:virtualmachine.vm:22 -o ServerAliveInterval=30 ijortengab@localhost"
# )
# $ssh_tunnel_destroy_info = (
#     "Destroy tunnel on ijortengab@office.lan:2223."
#     "Destroy tunnel on staff-it@company.com:80."
# )
# $ssh_tunnel_destroy = (
#     "kill $(ps aux | grep "$ssh_tunnel_create[1]" | grep -v grep | awk '{print $2}')"
#     "kill $(ps aux | grep "$ssh_tunnel_create[0]" | grep -v grep | awk '{print $2}')"
# )
#
# *local_ports* merupakan array yang menjadi penyimpanan sementara sebagai
# referensi local port forwarding untuk kebutuhan tunneling berdasarkan
# informasi pada variable $destination dan $tunnels. Contoh, jika:
#
# ```
# rcm login user@virtualmachine via foo@office.lan via proxy@company.com
# ```
#
# Maka,
# host company.com tidak perlu local port forwarding karena dia menjadi koneksi
# langsung.
# host virtualmachine akan diset local port forwarding misalnya 50000
# host office.lan akan diset local port forwarding misalnya 50001
# Sehingga hasil akhir menjadi:
#
# ```
# local_ports=(50000 50001)
# ```
#
# Variable ini akan diisi oleh fungsi getLocalPortBasedOnHost().
# Penggunaan local port seperti pada command berikut:
#
# ```
# ssh -fN proxy@company.com -L 50001:office.lan:22
# ssh -fN foo@localhost -p 50001 -L 50000:virtualmachine:22
# ssh user@localhost -p 50000
# ```
#
# local_ports=()

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
populateTemplate() {
    local execute=1
    local string
    local compileLines
    compileLines=()
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
    if [[ $interactive == 1 ]];then
        preview=1
    fi
    if [[ $preview == 1 ]];then
        execute=0
        echo -ne "\e[32m"
        echo "#!/bin/bash"
        for string in "${compileLines[@]}"
        do
            # if [[ "$string" =~ echo\ \-e\ \"\\e\[[0-9]+m ]];then
                # echo -n "$(echo ${string} | sed -n -E 's/^(\s*)(echo\s-e\s"\\e\[[0-9]+m)(.*)(\\e\[[0-9]+m")/\2/p')"
                # echo -ne "\e[92m"
                # echo -n "$(echo $string | sed -n -E 's/^(\s*)(echo\s-e\s"\\e\[[0-9]+m)(.*)(\\e\[[0-9]+m")/\3/p')"
                # echo -ne "\e[32m"
                # echo -n "$(echo $string | sed -n -E 's/^(\s*)(echo\s-e\s"\\e\[[0-9]+m)(.*)(\\e\[[0-9]+m")/\4/p')"
                # echo
            # else
                echo "$string"
            # fi
        done
        echo -ne "\e[39m"
    fi
    if [[ $interactive == 1 ]];then
        read -p "Do you want to execute (y/N): " option
        case $option in
            n|N|no) execute=0 ;;
            y|Y|yes) execute=1 ;;
            *) execute=0 ;;
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
    varDump 'execute()'
    case $command in
        login)
            validateArgumentsPreparePopulateRoute
            populateRoute
            executeLogin
            ;;
        send-key)
            validateArgumentsPreparePopulateRoute
            populateRoute
            executeSendKey
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

# Fungsi untuk memasukkan standard create and destroy tunnel pada lines
# template.
# Digunakan pada kondisi default seperti executeLogin(), executeCommand().
# Pada kondisi khusus seperti executeSendKey(), maka body dalam fungsi ini
# digunakan untuk kemudian dimanipulasi sesuai kebutuhan.
writeLinesAddTunnels() {
    for (( i=0; i < ${#ssh_tunnel_create[@]} ; i++ )); do
        writeLinesVerbose 'echo -e "\e[93m'"${ssh_tunnel_create_info[$i]}"'\e[39m"' pre
        lines_pre+=("${ssh_tunnel_create[$i]}")
    done
    for (( i=0; i < ${#ssh_tunnel_destroy[@]} ; i++ )); do
        writeLinesVerbose 'echo -e "\e[93m'"${ssh_tunnel_destroy_info[$i]}"'\e[39m"' post
        lines_post+=("${ssh_tunnel_destroy[$i]}")
    done
    if isCygwin;then
        writeLinesAddGetPidCygwin
    fi
}

# Fungsi untuk menambah baris fungsi getPidCygwin pada variable $lines_pre
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

# Fungsi untuk menulis pada variable $lines hanya jika verbose aktif.
writeLinesVerbose() {
    if [[ $verbose == 1 ]];then
        case $2 in
            pre) lines_pre+=("$1") ;;
            post) lines_post+=("$1") ;;
            *) lines+=("$1")
        esac
    fi
}

# Fungsi untuk menulis pada variable $lines terkait command send-key.
writeLinesSendKey() {
    local _options options
    _options=$ssh_options
    options=$_options
    options+=" -o PreferredAuthentications=publickey -o PasswordAuthentication=no"
    writeLinesVerbose 'echo -e "\e[93mTest SSH connect to '${route[$i]}' using key.\e[39m"'
    lines+=("if [[ ! \$(ssh${options} ${mass_arguments} 'echo 1' 2>/dev/null) == 1 ]];then")
    writeLinesVerbose '    echo -e "\e[93m- SSH connect using key is failed. It means process continues.\e[39m"'
    writeLinesVerbose '    echo -e "\e[93m- You need input password twice to sending public key.\e[39m"'
    writeLinesVerbose '    echo -e "\e[93mFirstly, SSH connect to make sure ~/.ssh/authorized_keys on '${route[$i]}' exits.\e[39m"'
    options=$_options
    line="ssh${options} ${mass_arguments}"
    lines+=("    ${line} 'mkdir -p .ssh && chmod 700 .ssh && touch .ssh/authorized_keys && chmod 640 .ssh/authorized_keys'")
    writeLinesVerbose '    echo -e "\e[93mSecondly, SSH connect again to sending public key to '${route[$i]}'.\e[39m"'
    lines+=("    cat ~/.ssh/id_rsa.pub | ${line} 'cat >> .ssh/authorized_keys'")
    writeLinesVerbose '    echo -e "\e[93mRetest SSH connect to '${route[$i]}' using key.\e[39m"'
    options=$_options
    options+=" -o PreferredAuthentications=publickey -o PasswordAuthentication=no"
    writeLinesVerbose "    if [[ ! \$(ssh${options} ${mass_arguments} 'echo 1' 2>/dev/null) == 1 ]];then"
    writeLinesVerbose '        echo -e "\e[93m- \e[91mFailed.\e[39m"'
    writeLinesVerbose '    else'
    writeLinesVerbose '        echo -e "\e[93m- \e[92mSuccess.\e[39m"'
    writeLinesVerbose '    fi'
    writeLinesVerbose 'else'
    writeLinesVerbose '    echo -e "\e[93m- SSH connect using key is successful thus sending key is not necessary.\e[39m"'
    lines+=("fi")
}

# Fungsi untuk membaca variable $options dan kemudian mengeset variable yang
# terkait.
setOptions() {
    local which residual
    which=$1
    loop=$2
    # Jadikan variable berdasarkan array.
    # set -- ${arguments[@]}
    # set -- ${options[@]}
    eval set -- \$\{$which\[\@\]\}
    eval $which=\(\)
    # Set options.
    residual=()
    while [[ $# -gt 0 ]]; do
        varDump '<$1>'"$1"
        case $1 in
        --preview|-p) preview=1 ; shift;;
        --interactive|-i) interactive=1 ; shift;;
        --quiet|-q) verbose=0 ; shift;;
        --last|-l) through=0 ; shift;;
        --style=*) style="$(echo $1 | cut -c9-)"; shift ;;
        -s) style=$2; shift 2 ;;
        *)
            if [[ $1 =~ ^- ]];then
                # Reset builtin function getopts.
                OPTIND=1
                while getopts ":piqls:" opt; do
                    varDump '<$opt>'"$opt"
                    case $opt in
                        p) preview=1 ;;
                        i) interactive=1 ;;
                        q) verbose=0 ;;
                        l) through=0 ;;
                        s) style="$OPTARG" ;;
                        # \?) echo "Invalid option: -$OPTARG" >&2 ;;
                        :) echo "Option -$OPTARG requires an argument." >&2 ;;
                    esac
                done
                shift $((OPTIND-1))
            else
                # Mass arguments dikembalikan ke variable semula.
                if [[ $loop == once ]];then
                    while [[ $# -gt 0 ]]; do
                        eval $which\+\=\(\"$1\"\)
                        shift
                    done
                    break
                else
                    eval $which\+\=\(\"$1\"\)
                    shift
                fi
            fi
        esac
    done
}

# Fungsi untuk memvalidasi variable $options.
validateOptions() {
    # Variable $style yang dibolehkan adalah 'jump', 'tunnel', atau 'auto'.
    varDump style
    right=0
    case $style in
        jump) right=1 ;;
        tunnel) right=1 ;;
        auto)
            right=1
            vercomp `getCurrentSshProgramVersion` 7.3
            if [[ $? -lt 2 ]];then
                # ssh options -J available
                style=jump
            else
                # ssh options -J not available
                style=tunnel
            fi
    esac
    if [[ $right == 0 ]]; then
        error "Argument tidak dikenali pada opsi style: '${style}'."
    fi
    varDump style
}

# Fungsi untuk mem-populate variable $route.
populateRoute() {
    varDump 'populateRoute()'
    last_index=$(( ${#arguments[@]} - 1 ))
    for (( i=$last_index; i >= 0 ; i-- )); do
        if isOdd $i;then
            continue
        fi
        route+=("${arguments[$i]}")
    done
    varDump route
}

# Expand variable dengan prefix route_ terkait dengan $style tunnel.
expandRoutePrepareTunnel() {
    local i cmd first last
    local last_index options mass_arguments
    local route_host route_user route_port
    varDump 'expandRoutePrepareTunnel()'
    first=0
    last=$(( ${#route[@]} - 1 ))
    for (( i=0; i < ${#route[@]} ; i++ )); do
        cmd=
        route_host=${route[$i]}
        route_user=$(echo $route_host | grep -E -o '^[^@]+@')
        cmd+=$route_user
        if [[ $route_user == "" ]];then
            route_user=@
        else
            route_host=$(echo $route_host | sed 's/^'$route_user'//' )
            route_user=$(echo $route_user | grep -E -o '[^@]+')
        fi
        route_port=$(echo $route_host | grep -E -o ':[0-9]+$')
        if [[ $route_port == "" ]];then
            route_port=22
        else
            route_host=$(echo $route_host | sed 's/'$route_port'$//' )
            route_port=$(echo $route_port | grep -E -o '[0-9]+')
        fi
        route_hosts+=("$route_host")
        route_users+=("$route_user")
        route_ports+=("$route_port")
        if [[ $i == $first ]];then
            route_tunnel_host=$route_host
            route_tunnel_port=$route_port
        else
            route_tunnel_host=localhost
            route_tunnel_port=$(getLocalPortBasedOnHost $route_host)
            local_ports+=($route_tunnel_port)
        fi
        if [[ ! $i == $last ]];then
            route_tunnel_hosts+=("$route_tunnel_host")
            route_tunnel_ports+=("$route_tunnel_port")
            cmd+=$route_tunnel_host
            route_ssh_tunnel_mass_arguments+=("$cmd")
            cmd=''
            if [[ ! $route_tunnel_port == 22 ]];then
                cmd+=" -p ${route_tunnel_port}${cmd}"
            fi
            route_ssh_tunnel_options+=("$cmd")
        else
            route_last_host="$route_tunnel_host"
            route_last_user="$route_user"
            route_last_port="$route_tunnel_port"
        fi
    done
    route_last_ssh_options=''
    route_last_ssh_mass_arguments="${route_last_host}"
    if [[ ! $route_last_user == "@" ]];then
        route_last_ssh_mass_arguments="${route_last_user}@${route_last_host}"
    fi
    if [[ ! ${route_last_port} == 22 ]];then
        route_last_ssh_options+=" -p ${route_last_port}"
    fi
    for (( i=0; i < ${#route_ssh_tunnel_mass_arguments[@]} ; i++ )); do
        j=$(( $i + 1))
        options=${route_ssh_tunnel_options[$i]}
        mass_arguments=${route_ssh_tunnel_mass_arguments[$i]}
        options+=" -fN -L ${local_ports[$i]}:${route_hosts[$j]}:${route_ports[$j]}"
        options+=" -o ServerAliveInterval=30"
        ssh_tunnel_create+=("ssh${options} ${mass_arguments}")
        ssh_tunnel_create_info+=("SSH Connect. Create tunnel on ${route[$i]}.")
    done
    last_index=$(( ${#route_ssh_tunnel_mass_arguments[@]} - 1 ))
    for (( i=$last_index; i >= 0 ; i-- )); do
        ssh_tunnel_destroy_info+=("Destroy tunnel on ${route[$i]}.")
        if isCygwin;then
            ssh_tunnel_destroy+=("kill \$(getPidCygwin \"${ssh_tunnel_create[$i]}\")")
        else
            ssh_tunnel_destroy+=("kill \$(ps aux | grep \"${ssh_tunnel_create[$i]}\" | grep -v grep | awk '{print \$2}')")
        fi
    done
    varDump local_ports
    varDump route_hosts route_users route_ports
    varDump route_tunnel_hosts route_tunnel_ports
    varDump route_ssh_tunnel_mass_arguments route_ssh_tunnel_options
    varDump route_last_host route_last_user route_last_port
    varDump route_last_ssh_options route_last_ssh_mass_arguments
    varDump ssh_tunnel_create_info ssh_tunnel_create
    varDump ssh_tunnel_destroy_info ssh_tunnel_destroy
}

# Expand variable dengan prefix route_ terkait dengan $style jump.
expandRoutePrepareJump() {
    local i options mass_arguments
    varDump 'expandRoutePrepareJump()'
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
        route_host=${route[$i]}
        route_user=$(echo $route_host | grep -E -o '^[^@]+@')
        if [[ $route_user == "" ]];then
            route_user=@
        else
            route_host=$(echo $route_host | sed 's/^'$route_user'//' )
            route_user=$(echo $route_user | grep -E -o '[^@]+')
        fi
        route_port=$(echo $route_host | grep -E -o ':[0-9]+$')
        if [[ $route_port == "" ]];then
            route_port=22
        else
            route_host=$(echo $route_host | sed 's/'$route_port'$//' )
            route_port=$(echo $route_port | grep -E -o '[0-9]+')
        fi
        route_hosts+=("$route_host")
        route_users+=("$route_user")
        route_ports+=("$route_port")
        options=''
        mass_arguments=${route_host}
        if [[ ! $route_user == "@" ]];then
            mass_arguments="${route_user}@${route_host}"
        fi
        if [[ ! ${route_port} == 22 ]];then
            options+=" -p ${route_port}"
        fi
        if [[ ! $cmd == '' ]];then
            options+=" -J ${cmd}"
        fi
        route_ssh_options+=("$options")
        route_ssh_mass_arguments+=("$mass_arguments")
    done
    varDump route_hosts route_users route_ports
    varDump route_ssh_options route_ssh_mass_arguments
}

# Validasi mass argument yang digunakan oleh internal command.
validateArgumentsPreparePopulateRoute() {
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

# Eksekusi internal command login.
executeLogin() {
    varDump 'executeLogin()'
    local i last_route
    i=$(( ${#route[@]} - 1 ))
    varDump '<$i>'"$i"
    last_route=${route[$i]}
    case $style in
        tunnel)
            expandRoutePrepareTunnel
            ssh_options=$route_last_ssh_options
            ssh_mass_arguments=$route_last_ssh_mass_arguments
            writeLinesAddTunnels
            ;;
        jump)
            expandRoutePrepareJump
            # varDump route_ssh_mass_arguments
            ssh_options="${route_ssh_options[$i]}"
            ssh_mass_arguments=${route_ssh_mass_arguments[$i]}
    esac
    writeLinesVerbose 'echo -e "\e[93m'"SSH Connect to ${last_route}"'\e[39m"'
    lines+=("ssh${ssh_options} ${ssh_mass_arguments}")
    populateTemplate
}

# Eksekusi internal command send-key.
executeSendKey() {
    varDump 'executeSendKey()'
    local i last_key
    last_key=$(( ${#route[@]} - 1 ))
    case $style in
        tunnel)
            expandRoutePrepareTunnel
            for (( i=0; i < ${#ssh_tunnel_create[@]} ; i++ )); do
                if [[ $through == "1" ]];then
                    # Build options and arguments.
                    ssh_options=${route_ssh_tunnel_options[$i]}
                    mass_arguments=${route_ssh_tunnel_mass_arguments[$i]}
                    writeLinesSendKey
                fi
                writeLinesVerbose 'echo -e "\e[93m'"${ssh_tunnel_create_info[$i]}"'\e[39m"'
                lines+=("${ssh_tunnel_create[$i]}")
            done
            for (( i=0; i < ${#ssh_tunnel_destroy[@]} ; i++ )); do
                writeLinesVerbose 'echo -e "\e[93m'"${ssh_tunnel_destroy_info[$i]}"'\e[39m"' post
                lines_post+=("${ssh_tunnel_destroy[$i]}")
            done
            if isCygwin;then
                writeLinesAddGetPidCygwin
            fi
            ssh_options=$route_last_ssh_options
            mass_arguments=$route_last_ssh_mass_arguments
            writeLinesSendKey
            ;;
        jump)
            expandRoutePrepareJump
            for (( i=0; i < ${#route[@]} ; i++ )); do
                ssh_options=${route_ssh_options[$i]}
                mass_arguments=${route_ssh_mass_arguments[$i]}
                if [[ ! $i == $last_key ]];then
                    if [[ $through == "1" ]];then
                        writeLinesSendKey
                    fi
                else
                    writeLinesSendKey
                fi
            done
    esac
    populateTemplate
}

# Fungsi untuk meng-compare version antara dua string.
# Penggunaan: vercomp 7.0 8.0
# Hasilnya dapat diperoleh dari variable $?
# dimana 0 = sama, 1 = lebih besar, 2 = lebih kecil
# Credit: https://stackoverflow.com/a/4025065/7074586
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

# Fungsi untuk mengembalikan versi dari program ssh yang sekarang sedang
# digunakan. Memparse output dari ssh -V mengembalikan nilai float.
# Contoh output: 7.2, 7.4
getCurrentSshProgramVersion() {
    echo $(ssh -V 2>&1 | grep -o -P 'OpenSSH_\K([0-9]+\.[0-9]+)')
}

# Fungsi untuk mencetak error dan exit.
error() {
    echo "$1" >&2
    echo Force to exit. >&2
    exit 1
}

# Fungsi untuk debug. Mencetak variable.
varDump() {
    if [[ $debug == 0 ]];then
        return
    fi
    local globalVarName globalVarValue
    local normal red yellow cyan
    normal="$(tput sgr0)"
    red="$(tput setaf 1)"
    yellow="$(tput setaf 3)"
    cyan="$(tput setaf 6)"
    while [[ $# -gt 0 ]]; do
        # Argument internal untuk var dump variable non global
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
            printf "${yellow}$1${normal}\n"
            shift
            continue
        fi
        if [[ $1 =~ [^a-zA-Z_] ]];then
            printf "${yellow}$1${normal}\n"
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
# Parse options (locate between rcm and command).
while [[ $# -gt 0 ]]; do
    varDump '<$1>'"$1"
    arguments+=("$1")
    shift
done
varDump arguments
setOptions arguments once
varDump arguments
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
setOptions arguments
varDump arguments
varDump options verbose interactive preview through style
validateOptions
execute
