#!/bin/bash
if readlink /proc/$$/exe | grep -qs "dash"; then
  echo "This script needs to be run with bash, not sh"
  exit 1
fi
bulkconnection () {
echo ""
if [[ ! -e ~/.config/sshfs_bulk/enabled ]]; then
  echo Direktori not found: \'~/.config/sshfs_bulk/enabled\'.
  echo Try to \'Generate a new sshfs script\'
  echo ""
  exit
fi
if [[ ! "$EUID" -ne 0 ]]; then
  echo You are root.
  echo Every time \'sshfs\' connected successfully,
  echo Samba configuration will be adapted \(if any\).
  echo ""
fi
echo Scanning directory: ~/.config/sshfs_bulk/enabled
echo ""
declare -a sshfssuccess=()
count=0
cd ~/.config/sshfs_bulk/enabled
for file in *.sshfs.sh; do
  echo Found: \'$file\'.
  echo \ \ Check the contents of file...
  COMMAND=$(cat $file | grep -E '^sshfs\s+')
  ADDR=$(cat $file | grep  -E -o '[^ @]+@[^: ]+:')
  ADDR=$(echo $ADDR | grep -E -o '[^:]+')
  TARGETDIRMOUNT=$(cat $file | grep -E -o '\S+$')
  # echo
  if [[ "$ADDR" = "" ||  "$COMMAND" = "" ]]; then
    echo \ \ File contents don not contain \'sshfs\' command or is incorrect.
    echo \ \ Skip.
  else
    echo \ \ File contents is correct.
    CONTENT=$(cat $file)
    echo \ \ The contents of file:
    echo \ \ $CONTENT
    HASEXECUTE=$(/bin/ps x | grep -E 'sshfs.*'${ADDR}'.*'${TARGETDIRMOUNT} | grep -v grep)
    if [[ ! "$HASEXECUTE" = "" ]]; then
      PID=$(echo $HASEXECUTE | grep -E -o '^\S+')
      echo \ \ That command has been executed before and still running. Process ID $PID.
      echo \ \ Skip.
      echo \ \ If you want disconnect from that remote directory, execute this command:
      if [[ "$EUID" -ne 0 ]]; then
        echo \ \ fusermount -u $TARGETDIRMOUNT
      else
        echo \ \ umount -l $TARGETDIRMOUNT
      fi
      sshfssuccess[$count]=$file
      count=$(( $count + 1 ))
    else
      echo \ \ Check if the target server \($ADDR\) is on...
      ISRUN=$(echo -o "'ConnectTimeout 2'" $ADDR echo 1 | xargs ssh 2>/dev/null)
      if [[ "$ISRUN" = "" ]]; then
        echo \ \ The target server is off.
        echo \ \ Skip.
      else
        echo \ \ The target server is on.
        echo \ \ Execute command: .\/$file
        ./$file 2>~/.config/sshfs_bulk/leb3fooboodok2aikoopoo6c
        # >~/.config/sshfs_bulk/leb3fooboodok2aikoopoo6c
        ERROR=$(cat ~/.config/sshfs_bulk/leb3fooboodok2aikoopoo6c)
        rm ~/.config/sshfs_bulk/leb3fooboodok2aikoopoo6c
        if [[ ! $ERROR = "" ]]; then
          echo \ \ Error found while executing command \'sshfs\'.
          echo \ \ $ERROR
          echo \ \ Skip.
        else
          HASEXECUTE=$(/bin/ps x | grep -E 'sshfs.*'${ADDR}'.*'${TARGETDIRMOUNT} | grep -v grep)
          PID=$(echo $HASEXECUTE | grep -E -o '^\S+')
          echo \ \ Connection successful. Process ID $PID.
          echo \ \ If you want disconnect from that remote directory, execute this command:
          if [[ "$EUID" -ne 0 ]]; then
            echo \ \ fusermount -u $TARGETDIRMOUNT
          else
            echo \ \ umount -l $TARGETDIRMOUNT
          fi
          sshfssuccess[$count]=$file
          count=$(( $count + 1 ))
        fi
      fi
    fi
  fi
  echo ""
done
if [[ "$EUID" -ne 0 ]]; then
  # Not root.
  exit 1
fi
if [[ ${#sshfssuccess[@]} = 0 ]]; then
  # None sshfs execution.
  exit 3
fi
echo "There are ${#sshfssuccess[@]} successful connection(s)"
echo "Checking the file(s) to be included in Samba Configuration (if any)"
echo ""
# if [[ ! -e /etc/samba/smb.conf ]]; then
  # echo Samba configuration not found: \'/etc/samba/smb.conf\'.
  # echo Skip.
  # exit 2
# fi
needreload=0
for f in "${sshfssuccess[@]}"
do
  file=$(echo $f | sed 's/\.sshfs\.sh$/.smb.conf/')
  if [[ -e ~/.config/sshfs_bulk/available/$file ]]; then
    echo Found: \'$file\'.
    lineexist=$(echo \'include = $HOME/.config/sshfs_bulk/available/$file\' \'/etc/samba/smb.conf\' | xargs grep)
    if [[ "$lineexist" = "" ]]; then
      echo include = $HOME/.config/sshfs_bulk/available/$file >> /etc/samba/smb.conf
      echo \ \ Success included in \'/etc/samba/smb.conf\'
      needreload=1
    else
      echo \ \ File has been included before in \'/etc/samba/smb.conf\'
      echo \ \ Skip.
    fi
  fi
  echo ""
done
if [[ "$needreload" = "1" ]]; then
  echo Reloading Samba...
  killall -HUP smbd
  echo \ \ Samba Reloaded.
  echo ""
fi
}
if [[ "$1" = "start" ]]; then
  bulkconnection
  exit
fi
if [[ "$1" = "" ]]; then
  while :
  do
  clear
    echo 'Welcome to Bulk SSHFS Connection'
    echo ""
    echo "What do you want to do?"
    echo "   1) Bulk connect all sshfs scripts now"
    echo "   2) Generate a new sshfs script"
    echo "   3) Modify (enable/disable/delete) a file sshfs script"
    echo "   4) Exit"
    read -p "Select an option [1-4]: " option
    case $option in
      1)
      if [[ ! -e ~/.config/sshfs_bulk/enabled ]]; then
        echo ""
        echo Direktori not found: \'~/.config/sshfs_bulk/enabled\'
        echo Try to \'Generate a new sshfs script\'
        echo ""
        exit
      fi
      bulkconnection
      exit
      ;;
      2)
      echo ""
      echo "Tell me a Remote Server information"
      read -p "Domain or IP Address: " -e HOST
      read -p "Username: " -e USERNAME
      if [[ "$USERNAME" = "root" ]]; then
        SUGGESTTARGETDIR=/root
      else
        SUGGESTTARGETDIR=$(echo /home/$USERNAME)
      fi
      read -p "Target Directory: " -e -i $SUGGESTTARGETDIR TARGETDIR
      echo ""
      echo "Tell me a local directory name as target mounting"
      HOSTCLEAN=$(echo $HOST | sed 's/[^0-9a-zA-Z\.]//g')
      if [[ "$HOSTCLEAN" = "" ]]; then
        HOSTCLEAN=$USERNAME
      fi
      SUGGESTDIR=${USERNAME}@${HOSTCLEAN}
      if [[ "$EUID" -ne 0 ]]; then
        SUGGESTPATH=$(echo $HOME/mnt/$SUGGESTDIR)
      else
        SUGGESTPATH=/mnt/${SUGGESTDIR}
      fi
      read -p "Directory name: " -e -i $SUGGESTPATH PATH
      if [ ! -d "$PATH" ]; then
        echo ""
        read -p "Do you want to create mounting directory now? [y/*]: " -e -i y ASKCREATEDIR
        if [[ "$ASKCREATEDIR" = "y" ]]; then
          /bin/mkdir -p $PATH
        fi
      fi
      SUGGESTSSHFS=${SUGGESTDIR}.sshfs.sh
      echo ""
      while :
        do
          read -p "Scipt filename = " -e -i $SUGGESTSSHFS SSHFS
          if [[ "$SSHFS" = "" ]]; then
            continue
          fi
          if ! echo $SSHFS | /bin/grep -E '\.sshfs\.sh$' 1>/dev/null; then
            echo ""
            echo Must have extention: .sshfs.sh
            echo ""
            continue
          fi
          if [[ -e  ~/.config/sshfs_bulk/available/${SSHFS} ]] ;then
            echo ""
            echo File has been exists.
            read -p "Do you want overwrite? [y/*]: " -e -i y OVERWRITE
            if [[ ! "$OVERWRITE" = "y" ]]; then
              echo ""
              continue
            fi
            break
          fi
          break
        done
      echo ""
      SSHFSPATH=~/.config/sshfs_bulk/available/${SSHFS}
      # echo $SSHFSPATH
      /bin/mkdir -p ~/.config/sshfs_bulk/available
      /bin/mkdir -p ~/.config/sshfs_bulk/enabled
      if [[ "$EUID" -ne 0 ]]; then
        echo sshfs -o reconnect $USERNAME@$HOST:$TARGETDIR $PATH > $SSHFSPATH
      else
        echo sshfs -o allow_other,reconnect $USERNAME@$HOST:$TARGETDIR $PATH > $SSHFSPATH
      fi
      /bin/chmod u+x $SSHFSPATH
      /bin/ln -s $SSHFSPATH ~/.config/sshfs_bulk/enabled/${SSHFS}
      echo "File executable added and available at ~/.config/sshfs_bulk"
      if [[ "$EUID" -ne 0 ]]; then
        echo ""
        echo "Finish. You can bulk connect now."
        echo ""
        exit
      fi
      echo ""
      echo You are root. If you want, when successfully connected with sshfs,
      echo your mounting directory \'$PATH\'
      echo can automatically to be a sharing folder in your Samba network.
      echo ""
      read -p "Do you want to continue? [y/*]: " -e -i y ASKSAMBA
      if [[ ! "$ASKSAMBA" = "y" ]]; then
        echo ""
        echo "Finish. You can bulk connect now."
        echo ""
        exit
      fi
      echo ""
      echo "Tell me a name for sharing directory"
      read -p "Directory name: " -e -i $SUGGESTDIR SAMBADIR
      echo ""
      echo "Tell me some directive configuration"
      read -p "path = " -e -i $PATH SAMBAPATH
      read -p "available = " -e -i yes SAMBAAVAILABLE
      read -p "valid users = " -e -i $USERNAME SAMBAVALIDUSERS
      read -p "admin users = " -e -i $SAMBAVALIDUSERS SAMBAADMINUSERS
      read -p "read only = " -e -i no SAMBAREADONLY
      read -p "browsable = " -e -i yes SAMBABROWSABLE
      read -p "public = " -e -i yes SAMBAPUBLIC
      read -p "writable = " -e -i yes SAMBAWRITABLE
      SAMBACONF=$(echo $SSHFS | /bin/sed 's/\.sshfs\.sh$/.smb.conf/')
      SAMBACONFPATH=~/.config/sshfs_bulk/available/${SAMBACONF}
      echo \[$SAMBADIR\] >> $SAMBACONFPATH
      echo \ \ path = $SAMBAPATH >> $SAMBACONFPATH
      echo \ \ available = $SAMBAAVAILABLE >> $SAMBACONFPATH
      echo \ \ valid users = $SAMBAVALIDUSERS >> $SAMBACONFPATH
      echo \ \ admin users = $SAMBAADMINUSERS >> $SAMBACONFPATH
      echo \ \ read only = $SAMBAREADONLY >> $SAMBACONFPATH
      echo \ \ browsable = $SAMBABROWSABLE >> $SAMBACONFPATH
      echo \ \ public = $SAMBAPUBLIC >> $SAMBACONFPATH
      echo \ \ writable = $SAMBAWRITABLE >> $SAMBACONFPATH
      echo ""
      echo "File executable added and available at ~/.config/sshfs_bulk"
      echo ""
      echo "Finish. You can bulk connect now."
      exit
      ;;
      3)
      count=$(ls ~/.config/sshfs_bulk/available | grep -E '\.sshfs\.sh$' | wc -l)
      if [[ $count = 0 ]];then
        echo File sshfs script not found.
        echo ""
        exit
      fi
      list=( `ls ~/.config/sshfs_bulk/available | grep -E '\.sshfs\.sh$' `)
      listc=()
      count=1
      for t in "${list[@]}"
        do
          if [[ -e ~/.config/sshfs_bulk/enabled/$t ]]; then
            status='enabled'
          else
            status='disabled'
          fi
          line="| ${count} | [${status}] ${t}"
          count=$(( $count + 1 ))
          listc=("${listc[@]}" "$line")
      done
      NUMBEROFFILE=${#list[@]}
      echo ""
      echo "Guide:"
      echo " - Type command 'a' to show all scripts filename"
      echo " - Type command 'grep foo' to filter all files filename that contains word 'foo'"
      echo ""
      first=1
      while :
      do
        while :
        do
          if [[ "$NUMBEROFFILE" = '1' ]]; then
            helper="Type command or select one file [1]: "
          else
            helper="Type command or select one file [1-$NUMBEROFFILE]: "
          fi
          if [[ $first = 1 ]];then
            helper="Type command: "
          fi
          read -p "$helper" INPUT
          # read -p "Select file [] = " INPUT
          if [[ "$INPUT" = "" ]]; then
            continue
          else
            break
          fi
        done
        first=0
        if [[ "$INPUT" = "a" ]]; then
          echo ""
          echo "Show all files:"
          echo ""
          for t in "${listc[@]}"
            do
              echo $t
          done
          echo ""
          continue
        fi
        GREP=$(echo $INPUT | grep -E '^\s*grep\s+')
        if [[ ! "$GREP" = "" ]]; then
          echo ""
          echo "Show files filtered by:" $GREP
          echo ""
          for t in "${listc[@]}"
          do
            # Do not delete this line. echo $t | grep -E -o '\s+\S+$' | ${GREP}
            clean=$(echo $t | grep -E -o '\S+$'  | $GREP)
            if [[ ! "$clean" = "" ]];then
              echo $t
            fi
          done
          echo ""
          continue
        fi
        # if [[ ! $var =~ ^[0-9]+$ ]];then
        # if [ ! "$INPUT" -eq "$INPUT" ];then
        if [[ ! $INPUT =~ ^[0-9]+$ ]];then
          echo "Harap masukkan angka nomor urut dari file."
          echo ""
          continue
        fi
        if (("$INPUT" > "$NUMBEROFFILE"));then
          echo "Angka tidak boleh lebih besar dari $NUMBEROFFILE"
          echo ""
          continue
        fi
        index=$(( $INPUT - 1 ))
        line="${listc[${index}]}"
        # echo $line
        clean=$(echo $line | grep -E -o '\S+$')
        # echo $clean
        status=$(echo $line | grep -E -o '(enabled|disabled)')
        kontrastatus="Enabled"
        if [[ "$status" = "enabled" ]];then
          kontrastatus="Disabled"
        fi
        # echo $status
        PATHSCRIPT=~/.config/sshfs_bulk/available/${clean}
        if [[ ! -e $PATHSCRIPT ]]; then
          echo ""
          echo "File not found:" $PATHSCRIPT
          echo "You need reload this script."
          sleep 1
          echo ""
          continue
        fi
        break
      done
      echo ""
      echo "Selected file ${clean}"
      echo ""
      echo "What's next?"
      echo "   1) ${kontrastatus}"
      echo "   2) Delete"
      echo "   3) Cancel"
      echo ""
      while :
      do
        read -p "Select an option [1-3]: " option2
        echo ""
        case $option2 in
          1)
          # File Link
          if [[ "$kontrastatus" = "Disabled" ]];then
            /bin/rm ~/.config/sshfs_bulk/enabled/${clean}
            echo ${kontrastatus} successful.
            echo ""
          fi
          ## Samba.
          if [[ "$kontrastatus" = "Disabled" ]];then
            if [[ ! "$EUID" -ne 0 ]]; then
              needreload=0
              file=$(echo $clean | sed 's/\.sshfs\.sh$/.smb.conf/')
              if [[ -e ~/.config/sshfs_bulk/available/$file ]]; then
                lineexist=$(echo \'include = $HOME/.config/sshfs_bulk/available/$file\' \'/etc/samba/smb.conf\' | xargs grep)
                if [[ ! "$lineexist" = "" ]]; then
                  sed -i "/include = "$(echo $HOME | sed -e 's/\//\\\//g')"\/.config\/sshfs_bulk\/available\/"${file}"/d" /etc/samba/smb.conf
                  needreload=1
                fi
                read -p "Do you want to cancel this script to be integrate with Samba? [y/*]: " -e -i n askingcancelsamba
                echo ""
                if [[ "$askingcancelsamba" = "y" ]]; then
                  rm ~/.config/sshfs_bulk/available/$file
                  echo File to be included has been deleted.
                  echo ""
                fi
              fi
              if [[ $needreload = 1 ]]; then
                echo This script linked with Samba Configuration and has been cleaned.
                read -p "Do you want disconnect mounting directory from Samba Network? [y/*]: " -e -i y askingdcsamba
                echo ""
                if [[ "$askingdcsamba" = "y" ]]; then
                  killall -HUP smbd
                  echo Disconnect successful.
                  echo ""
                fi
              fi
            fi
          fi
          ## SSH Connection.
          if [[ "$kontrastatus" = "Disabled" ]];then
            content=$(cat ~/.config/sshfs_bulk/available/${clean})
            ADDR=$(echo $content | grep  -E -o '[^ @]+@[^: ]+:')
            ADDR=$(echo $ADDR | grep -E -o '[^:]+')
            TARGETDIRMOUNT=$(echo $content | grep -E -o '\S+$')
            HASEXECUTE=$(/bin/ps x | grep -E 'sshfs.*'${ADDR}'.*'${TARGETDIRMOUNT} | grep -v grep)
            if [[ ! "$HASEXECUTE" = "" ]]; then
              PID=$(echo $HASEXECUTE | grep -E -o '^\S+')
              echo This script has been executed before and still running. Process ID $PID.
              read -p "Do you want disconnect this connection? [y/*]: " -e -i y askingterminated
              echo ""
              if [[ "$askingterminated" = "y" ]]; then
                if [[ "$EUID" -ne 0 ]]; then
                  /bin/fusermount -u $TARGETDIRMOUNT
                else
                  /bin/umount -l $TARGETDIRMOUNT
                fi
                echo Disconnect successful.
                echo ""
              fi
            fi
          fi
          # File Link
          if [[ "$kontrastatus" = "Enabled" ]];then
            /bin/ln -s ~/.config/sshfs_bulk/available/${clean} ~/.config/sshfs_bulk/enabled/${clean}
            echo ${kontrastatus} successful.
            echo ""
          fi
          ## Samba.
          if [[ "$kontrastatus" = "Enabled" ]];then
            if [[ ! "$EUID" -ne 0 ]]; then   # needreload=0
              file=$(echo $clean | sed 's/\.sshfs\.sh$/.smb.conf/')
              if [[ ! -e ~/.config/sshfs_bulk/available/$file ]]; then
                content=$(cat ~/.config/sshfs_bulk/available/${clean})
                TARGETDIRMOUNT=$(echo $content | grep -E -o '\S+$')
                echo You are root. If you want, when successfully connected with sshfs,
                echo your mounting directory \'$TARGETDIRMOUNT\'
                echo can automatically to be a sharing folder in your Samba network.
                echo ""
                read -p "Do you want to continue? [y/*]: " -e -i y ASKSAMBA
                echo ""
                if [[ "$ASKSAMBA" = "y" ]]; then
                  SUGGESTDIR=$(echo $TARGETDIRMOUNT| grep -E -o '[^\/]+$')
                  echo "Tell me a name for sharing directory"
                  echo "Please, use alphabet and underscore only, no special characters"
                  read -p "Directory name: " -e -i $SUGGESTDIR SAMBADIR
                  echo ""
                  echo "Tell me some directive configuration"
                  read -p "path = " -e -i $TARGETDIRMOUNT SAMBAPATH
                  read -p "available = " -e -i yes SAMBAAVAILABLE
                  USERNAME=$(whoami)
                  read -p "valid users = " -e -i $USERNAME SAMBAVALIDUSERS
                  read -p "admin users = " -e -i $SAMBAVALIDUSERS SAMBAADMINUSERS
                  read -p "read only = " -e -i no SAMBAREADONLY
                  read -p "browsable = " -e -i yes SAMBABROWSABLE
                  read -p "public = " -e -i yes SAMBAPUBLIC
                  read -p "writable = " -e -i yes SAMBAWRITABLE
                  SAMBACONF=$file
                  SAMBACONFPATH=~/.config/sshfs_bulk/available/${SAMBACONF}
                  echo \[$SAMBADIR\] >> $SAMBACONFPATH
                  echo \ \ path = $SAMBAPATH >> $SAMBACONFPATH
                  echo \ \ available = $SAMBAAVAILABLE >> $SAMBACONFPATH
                  echo \ \ valid users = $SAMBAVALIDUSERS >> $SAMBACONFPATH
                  echo \ \ admin users = $SAMBAADMINUSERS >> $SAMBACONFPATH
                  echo \ \ read only = $SAMBAREADONLY >> $SAMBACONFPATH
                  echo \ \ browsable = $SAMBABROWSABLE >> $SAMBACONFPATH
                  echo \ \ public = $SAMBAPUBLIC >> $SAMBACONFPATH
                  echo \ \ writable = $SAMBAWRITABLE >> $SAMBACONFPATH
                  echo ""
                  echo "File executable added and available at ~/.config/sshfs_bulk"
                  echo ""
                fi
              fi
            fi
          fi
          if [[ "$kontrastatus" = "Enabled" ]];then
            echo "Finish. You should bulk connect now."
            echo ""
          fi
          break
          ;;
          2)
          echo ""
          echo "Deleted will automatically disconnect from sshfs and Samba (if any)."
          read -p "Are you sure want to delete? [y/*]: " -e -i n askdelete
          echo ""
          if [[ "$askdelete" = "y" ]]; then
            content=$(cat ~/.config/sshfs_bulk/available/${clean})
            ADDR=$(echo $content | grep  -E -o '[^ @]+@[^: ]+:')
            ADDR=$(echo $ADDR | grep -E -o '[^:]+')
            TARGETDIRMOUNT=$(echo $content | grep -E -o '\S+$')
            HASEXECUTE=$(/bin/ps x | grep -E 'sshfs.*'${ADDR}'.*'${TARGETDIRMOUNT} | grep -v grep)
            if [[ ! "$HASEXECUTE" = "" ]]; then
              if [[ "$EUID" -ne 0 ]]; then
                /bin/fusermount -u $TARGETDIRMOUNT
              else
                /bin/umount -l $TARGETDIRMOUNT
              fi
            fi
            /bin/rm ~/.config/sshfs_bulk/enabled/$clean
            /bin/rm ~/.config/sshfs_bulk/available/$clean
            file=$(echo $clean | sed 's/\.sshfs\.sh$/.smb.conf/')
            if [[ -e ~/.config/sshfs_bulk/available/$file ]]; then
              lineexist=$(echo \'include = $HOME/.config/sshfs_bulk/available/$file\' \'/etc/samba/smb.conf\' | xargs grep)
              if [[ ! "$lineexist" = "" ]]; then
                sed -i "/include = "$(echo $HOME | sed -e 's/\//\\\//g')"\/.config\/sshfs_bulk\/available\/"${file}"/d" /etc/samba/smb.conf
              fi
              rm ~/.config/sshfs_bulk/available/$file
            fi
            echo "Deleted successsful."
            echo ""
          fi
          break
          ;;
          3)
          echo ""
          break
          ;;
        esac
      done
      # echo This scipts that you can find at
      # echo ~/.config/sshfs_bulk
      # ls ~/.config/sshfs_bulk | grep .sshfs.sh
      exit
      ;;
      4) exit;;
    esac
  done
fi
exit;
