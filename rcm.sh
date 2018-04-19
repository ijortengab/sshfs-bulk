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

# Developer only. Flag untuk mengaktifkan fungsi varDump.
debug=0

# Lines untuk menjadi storage baris-baris generated code.
lines_define=()
lines_function=()
lines_pre=()
lines=()
lines_post=()

# $command_type terbagi menjadi dua: external dan internal.
# External command adalah apapun command di Linux yang menggunakan remote host.
# RCM didisain untuk memudahkan bekerja melalui tunnel, maka remote host yang
# menjadi argument pada external command akan direplace menjadi localhost
# setelah tunnel di-create.
# Contoh external command yang menggunakan remote host adalah:
# - ssh host
# - rsync host
# - sshfs host
# - wget host
# Internal_command adalah command internal yang dimiliki oleh rcm untuk tugas
# dan fungsi tertentu yang sudah baku. Contoh: login, send-key.
command_type=
command=
command_arguments=()
command_full=

# *mass_arguments* adalah array penampungan semua argument diluar command.
# Contoh:
# ```
# rcm -iq send-key -option --long-option satu dua ti\ ga
# ```
# Dari contoh diatas, maka nilai dari variable ini sama dengan
# mass_arguments=(satu dua "ti ga")
mass_arguments=()

# $destination merupakan variable penyimpanan dari option -d atau --destination.
# $destination_sanitize merupakan nilai dari $destination yang telah dihilangkan
# informasi :port. Contoh:
# ```
# $destination=ijortengab@systemix.id:8080
# $destination_sanitize=ijortengab@systemix.id
# ```
# $destination_sanitize di-populate oleh validateDestination() dan digunakan
# oleh fungsi executeCommand() untuk me-replace $command_full.
destination=
destination_sanitize=

# $tunnels merupakan variable penyimpanan dari option -t atau --tunnel.
# tunnels_command_* adalah command ssh untuk membuat/menutup tunnel beserta
# informasi penjelasan.
tunnels=()

# Variable $route adalah kumpulan dari host yang dilalui dimana element pertama
# adalah tunnel pertama, element terakhir adalah destination.
# Tiap element menggunakan format: [USER@]HOST[:PORT].
# Variable lainnya dibangun perdasarkan $route.
# Contoh:
# ```
# rcm -p login guest@virtualmachine.vm via ijortengab@office.lan:2223 via staff-it@company.com:80
# ```
# maka,
# $route = ( "staff-it@company.com:80" "ijortengab@office.lan:2223" "guest@virtualmachine.vm" )
# $hosts = ( "company.com" "office.lan" "virtualmachine.vm" )
# $users = ( "staff-it" "ijortengab" "guest" )
# $ports = ( "80" "2223" "22" )
# $hosts_actual = ( "company.com" "localhost" "localhost" )
# $ports_actual = ( "80" "50011" "50020" )
# $route_actual = ( "staff-it@company.com" "ijortengab@localhost" "guest@localhost" )
# $tunnels_command_create = (
#     "ssh -fN -L 50011:office.lan:2223 -p 80 staff-it@company.com"
#     "ssh -fN -L 50020:virtualmachine.vm:22 -p 50011 ijortengab@localhost"
# )
# $tunnels_command_create_info = (
#     "SSH Connect. Create tunnel on staff-it@company.com:80."
#     "SSH Connect. Create tunnel on ijortengab@office.lan:2223."
# )
route=()
route_actual=()
hosts=()
ports=()
users=()
hosts_actual=()
ports_actual=()
tunnels_command_create=()
tunnels_command_create_info=()
tunnels_command_destroy=()
tunnels_command_destroy_info=()

# *local_ports* merupakan array yang menjadi penyimpanan sementara sebagai
# referensi local port forwarding untuk kebutuhan tunneling berdasarkan
# informasi pada variable $destination dan $tunnels. Contoh, jika:
# ```
# rcm login user@virtualmachine via foo@office.lan via proxy@company.com
# ```
# Maka,
# host company.com tidak perlu local port forwarding karena dia menjadi koneksi
# langsung.
# host virtualmachine akan diset local port forwarding misalnya 50000
# host office.lan akan diset local port forwarding misalnya 50001
# Sehingga hasil akhir menjadi:
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
            if [[ "$string" =~ echo\ \-e\ \"\\e\[[0-9]+m ]];then
                echo -n "$(echo "$string" | sed -n -E 's/\s*(echo\s-e\s"\\e\[[0-9]+m)(.*)(\\e\[[0-9]+m")/\1/p')"
                echo -ne "\e[92m"
                echo -n "$(echo "$string" | sed -n -E 's/\s*(echo\s-e\s"\\e\[[0-9]+m)(.*)(\\e\[[0-9]+m")/\2/p')"
                echo -ne "\e[32m"
                echo -n "$(echo "$string" | sed -n -E 's/\s*(echo\s-e\s"\\e\[[0-9]+m)(.*)(\\e\[[0-9]+m")/\3/p')"
                echo
            else
                echo "$string"
            fi
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
    readOptions
    case $command in
        login)
            validateInternalCommandOptions
            validateInternalCommandMassArgument
            populateRoute mass-arguments
            parseRoutePopulateArrays
            executeLogin
            ;;
        send-key)
            validateInternalCommandOptions
            validateInternalCommandMassArgument
            populateRoute mass-arguments
            parseRoutePopulateArrays
            executeSendKey
            ;;
        ssh)
            validateDestination
            populateRoute tunnels-destination
            parseRoutePopulateArrays
            executeCommand
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
    for (( i=0; i < ${#tunnels_command_create[@]} ; i++ )); do
        writeLinesVerbose 'echo -e "\e[93m'"${tunnels_command_create_info[$i]}"'\e[39m"' pre
        lines_pre+=("${tunnels_command_create[$i]}")
    done
    for (( i=0; i < ${#tunnels_command_destroy[@]} ; i++ )); do
        writeLinesVerbose 'echo -e "\e[93m'"${tunnels_command_destroy_info[$i]}"'\e[39m"' post
        lines_post+=("${tunnels_command_destroy[$i]}")
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

# Fungsi untuk mendapatkan informasi port dari command line ssh.
# Posisi argument port pada command ssh bisa sebagai berikut
# -p 23
# -p23
# -vvvp 23
# -vvvp23
# Contoh: `ssh ijortengab@host`, maka port=22.
# Contoh: `ssh -p 2223 ijortengab@host`, maka port=2223.
# Contoh: `ssh -v4p2221 ijortengab@host`, maka port=2221.
getPortFromSshCommand() {
    local port
    port=$(echo "$1" | grep -o -P '\s\-p\s*\K([0-9]+)\s')
    if [[ $port == "" ]];then
        port=$(echo "$1" | grep -o -P '\s\-[0-9a-zA-Z]+p\s*\K([0-9]+)\s')
    fi
    if [[ ! $port == "" ]];then
        echo $port
    else
        echo 22
    fi
}

# Fungsi untuk membaca variable $options dan kemudian mengeset variable yang
# terkait.
readOptions() {
    varDump 'readOptions() before'
    varDump options
    # Reset builtin function getopts.
    OPTIND=1
    # Options yang berlaku untuk semua.
    while getopts ":piq" opt ${options[@]}; do
        case $opt in
            p) preview=1 ;;
            i) interactive=1 ;;
            q) verbose=0 ;;
        esac
    done
    # Reset builtin function getopts.
    OPTIND=1
    # Options yang berlaku spesifik per command.
    case $command in
        send-key)
            while getopts ":l" opt ${options[@]}; do
                case $opt in
                    l) through=0 ;;
                esac
            done
            ;;
    esac
    varDump 'readOptions() after'
    varDump interactive verbose through preview
}

# Fungsi untuk mem-populate variable $route.
populateRoute() {
    case $1 in
        mass-arguments)
            last_index=$(( ${#mass_arguments[@]} - 1 ))
            for (( i=$last_index; i >= 0 ; i-- )); do
                if isOdd $i;then
                    continue
                fi
                route+=("${mass_arguments[$i]}")
            done
            ;;
        tunnels-destination)
            last_index=$(( ${#tunnels[@]} - 1 ))
            for (( i=$last_index; i >= 0 ; i-- )); do
                route+=("${tunnels[$i]}")
            done
            route+=("$destination")
            ;;
    esac
}

# Fungsi untuk mengisi berbagai global variable berdasarkan variable $route.
parseRoutePopulateArrays() {
    flag=0
    for (( i=0; i < ${#route[@]} ; i++ )); do
        j=$(( $i + 1 ))
        _host=${route[$i]}
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

    for (( i=0; i < ${#tunnels_actual[@]} ; i++ )); do
        options=
        options+="-fN -L ${tunnels_actual[$i]} "
        tunnels_command_create_info+=("SSH Connect. Create tunnel on ${route[$i]}.")
        if [[ ! ${ports_actual[$i]} == 22 ]];then
            options+="-p ${ports_actual[$i]} "
        fi
        tunnels_command_create+=("ssh ${options}${route_actual[$i]}")
    done
    z=$(( ${#tunnels_actual[@]} - 1 ))
    for (( i=$z; i >= 0 ; i-- )); do
        tunnels_command_destroy_info+=("Destroy tunnel on ${route[$i]}.")
        if isCygwin;then
            tunnels_command_destroy+=("kill \$(getPidCygwin \"${tunnels_command_create[$i]}\")")
        else
            tunnels_command_destroy+=("kill \$(ps aux | grep \"${tunnels_command_create[$i]}\" | grep -v grep | awk '{print \$2}')")
        fi
    done
    varDump route hosts users ports hosts_actual ports_actual tunnels_actual
    varDump route_actual
    varDump tunnels_command_create tunnels_command_create_info
    varDump tunnels_command_destroy tunnels_command_destroy_info
}

# Verifikasi khusus internal command.
validateInternalCommandOptions() {
    # Internal command tidak membutuhkan argument -t maupun argument -d yang
    # mengisi array $tunnels.
    if [[ ${#tunnels[@]} -gt 0 ]];then
        error "Internal command tidak membutuhkan option -t maupun -d."
    fi
}

# Validasi mass argument yang digunakan oleh internal command.
validateInternalCommandMassArgument() {
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
}

# Fungsi untuk memvalidasi variable $destination.
# Port yang tertera pada destination harus juga berada pada $command_full.
# Contoh:`rcm -d user@host:2223 $command_full`,
# maka pada $command_full setidaknya harus contains
# sebagai berikut, misal: `ssh -p 2223 user@host`.
validateDestination() {
    # Hilangkan dulu karakter `:2223` pada destination.
    destination_sanitize=$destination
    _port=$(echo $destination_sanitize | grep -E -o ':[0-9]+$')
    if [[ $_port == "" ]];then
        _port=22
    else
        destination_sanitize=$(echo $destination_sanitize | sed 's/'$_port'$//' )
        _port=$(echo $_port | grep -E -o '[0-9]+')
    fi
    include=0
    for (( i=0; i < ${#command_arguments[@]} ; i++ )); do
        if [[ ${command_arguments[$i]} == $destination_sanitize ]];then
            include=1
            break
        fi
    done
    varDump '<$destination>'"$destination"
    varDump '<$destination_sanitize>'"$destination_sanitize"
    if [[ $include == 0 ]];then
        error "The destination '${destination_sanitize}' not include in command '${command_full}'"
    fi
    # Jika port selain 22, maka perlu ada informasinya di $command_full berupa
    # options -p 2223.
    if [[ ! $_port == "22" ]];then
        found=0
        if [[ "$command_full" =~ -p\ ?$_port ]];then
            found=1
        elif [[ "$command_full" =~ -[0-9a-zA-Z]+p\ ?$_port ]];then
            found=1
        fi
        if [[ $found == 0 ]];then
            _port_command=$(getPortFromSshCommand "$command_full")
            error "Port berbeda antara destination '${_port}' dengan command '${_port_command}'."
        fi
    fi
}

# Eksekusi internal command login.
executeLogin () {
    local z
    local options _tunnels flag
    writeLinesAddTunnels
    z=$(( ${#route[@]} - 1 ))
    last_route=${route[$z]}
    last_hosts_actual=${hosts_actual[$z]}
    last_ports_actual=${ports_actual[$z]}
    last_users=${users[$z]}
    options=
    if [[ ! ${last_ports_actual} == 22 ]];then
        options+="-p ${last_ports_actual} "
    fi
    if [[ ! $last_users == "---" ]];then
        last_hosts_actual=${last_users}@${last_hosts_actual}
    fi
    writeLinesVerbose 'echo -e "\e[93m'"SSH Connect to ${last_route}"'\e[39m"'
    lines+=("ssh ${options}${last_hosts_actual}")
    populateTemplate
}

# Eksekusi internal command send-key.
executeSendKey() {
    z=$(( ${#route[@]} - 1 )) # Last index of $route.
    varDump $last_route $last_hosts_actual $last_ports_actual $last_users
    for (( i=0; i < ${#tunnels_command_create[@]} ; i++ )); do
        if [[ $through == "1" ]];then
            writeLinesSendKey $i
        fi
        writeLinesVerbose 'echo -e "\e[93m'"${tunnels_command_create_info[$i]}"'\e[39m"'
        lines+=("${tunnels_command_create[$i]}")
    done
    for (( i=0; i < ${#tunnels_command_destroy[@]} ; i++ )); do
        writeLinesVerbose 'echo -e "\e[93m'"${tunnels_command_destroy_info[$i]}"'\e[39m"' post
        lines_post+=("${tunnels_command_destroy[$i]}")
    done
    if isCygwin;then
        writeLinesAddGetPidCygwin
    fi
    writeLinesSendKey $z
    populateTemplate
}

# Fungsi untuk eksekusi command yang didalamnya mengandung remote host.
executeCommand() {
    local i options
    z=$(( ${#route[@]} - 1 ))
    last_route=${route[$z]}
    last_hosts_actual=${hosts_actual[$z]}
    last_ports_actual=${ports_actual[$z]}
    last_users=${users[$z]}
    # Tunnels.
    writeLinesAddTunnels
    # Replacement host.
    if [[ ! $last_users == "---" ]];then
        last_hosts_actual=${last_users}@${last_hosts_actual}
    fi
    command_replacement=$(echo "$command_full" | sed 's/'$destination_sanitize'/'$last_hosts_actual'/')
    # Modifikasi tergantung pada command.
    # Command yang saat ini disupport adalah sebagai berikut:
    case $command in
        ssh)
            # Jika pada $command_full terdapat argument -p, maka replace
            # dengan port yang saat ini.
            if [[ "$command_replacement" =~ -p\ ?[0-9]+\  ]];then
                command_replacement=$(echo "$command_replacement" | sed -nE 's/-p(\s*)[0-9]+\s/-p\1'$last_ports_actual' /p')
            elif [[ "$command_replacement" =~ -[0-9a-zA-Z]+p\ ?[0-9]+\  ]];then
                command_replacement=$(echo "$command_replacement" | sed -nE 's/-([0-9a-zA-Z]+)p(\s*)[0-9]+\s/-\1p\2'$last_ports_actual' /p')
            else
                command_replacement=$(echo "$command_replacement" | sed -nE 's/ssh/ssh -p '$last_ports_actual'/p')
            fi
            ;;
        rsync)
            echo
            ;;
    esac
    writeLinesVerbose 'echo -e "\e[93m'"Execute '${command}' command on '${last_route}'."'\e[39m"'
    lines+=("$command_replacement")
    populateTemplate
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

# Parse options (locate between rcm and command) that using style
# --long-options or options that require argument.
while [[ $# -gt 0 ]]; do
    case $1 in
        # Flag options pass to $options.
        --preview|-p| --interactive|-i|--quiet|-q)
            options+=("$1")
            shift
            ;;
        -d) destination=$2; shift 2 ;;
        --destination=*) destination=("$(echo $1 | cut -c15-)"); shift ;;
        -t) tunnels+=("$2"); shift 2 ;;
        --tunnel=*) tunnels+=("$(echo $1 | cut -c10-)"); shift ;;
        *)
            if [[ $1 =~ ^- ]];then
                # Pass to $options.
                # Contoh kasus options -d yang menempel pada options lainnya:
                # rcm -iqd host ssh host
                while getopts ":piqt:d:" opt; do
                    case $opt in
                        p|i|q)
                            options+=("-$opt")
                            ;;
                        t) tunnels+=("$OPTARG") ;;
                        d) destination="$OPTARG" ;;
                        \?) echo "Invalid option: -$OPTARG" >&2 ;;
                        :) echo "Option -$OPTARG requires an argument." >&2 ;;
                    esac
                done
                shift $((OPTIND-1))
            fi
            # Jika ketemu mass argument, maka break.
            break
    esac
done

if [[ $# == 0 ]];then
    error "Command not found."
fi

case "$1" in
    login|send-key|push|pull|manage|open-port|mount)
        command_type=internal_command
        command="$1"
        shift
        ;;
    *)
        command_type=external_command
        command="$1"
        command_full="$@"
        shift
        ;;
esac

case $command_type in
    # Pada internal command, options bisa berada pada posisi buntut.
    internal_command)
        while [[ $# -gt 0 ]]; do
            if [[ $1 =~ ^- ]];then
                options+=("$1")
            else
                mass_arguments+=("$1")
            fi
            shift
        done
        ;;
    external_command)
        while [[ $# -gt 0 ]]; do
            command_arguments+=("$1")
            shift
        done
esac

varDump destination tunnels
varDump interactive verbose through preview
varDump command_type command command_full command_arguments
varDump options mass_arguments
execute
