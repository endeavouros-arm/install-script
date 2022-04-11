#!/bin/bash

ZONE_DIR="/usr/share/zoneinfo/"
declare -a TIMEZONE_LIST

generate_timezone_list() {

	input=$1
	if [[ -d $input ]]; then
		for i in "$input"/*; do
			generate_timezone_list $i
		done
	else
		TIMEZONE=${input/#"$ZONE_DIR/"}
		TIMEZONE_LIST+=($TIMEZONE)
		TIMEZONE_LIST+=("")
	fi
}

_status_checker() {
    local status_code

    status_code="$1"
    if [[ "$status_code" -eq 1 ]]; then
       printf "${CYAN}Exiting setup..${NC}\n"
       exit
    fi
}

_ok_nok() {
    # Requires that variable "MESSAGE" be set
    local status

    status=$?
    if [[ $status -eq 0 ]]
    then
       printf "${GREEN}$MESSAGE OK${NC}\n"
       printf "$MESSAGE OK\n" >> /root/enosARM.log
    else
       printf "${RED}$MESSAGE   FAILED${NC}\n"
       printf "$MESAGE FAILED\n" >> /root/enosARM.log
       printf "\n\nLogs are stored in: /root/enosARM.log\n"
      exit 1
    fi
    sleep 1
}	# end of function _ok_nok


_find_mirrorlist() {
    # find and install current endevouros-arm-mirrorlist
    local tmpfile
    local currentmirrorlist

    printf "\n${CYAN}Find current endeavouros-mirrorlist...${NC}\n\n"
    MESSAGE="\nFind current endeavouros-mirrorlist "
    sleep 1
    curl https://github.com/endeavouros-team/repo/tree/master/endeavouros/$ARMARCH | grep "endeavouros-mirrorlist" |sed s'/^.*endeavouros-mirrorlist/endeavouros-mirrorlist/'g | sed s'/pkg.tar.zst.*/pkg.tar.zst/'g |tail -1 > mirrors

    tmpfile="mirrors"
    read -d $'\x04' currentmirrorlist < "$tmpfile"

    printf "\n${CYAN}Downloading endeavouros-mirrorlist...${NC}"
    MESSAGE="\nDownloading endeavouros-mirrorlist "
    wget https://github.com/endeavouros-team/repo/raw/master/endeavouros/$ARMARCH/$currentmirrorlist 2>> /root/enosARM.log
    _ok_nok      # function call

    printf "\n${CYAN}Installing endeavouros-mirrorlist...${NC}\n"
    MESSAGE="\nInstalling endeavouros-mirrorlist "
    pacman -U --noconfirm $currentmirrorlist &>> /root/enosARM.log
    _ok_nok    # function call

    printf "\n[endeavouros]\nSigLevel = PackageRequired\nInclude = /etc/pacman.d/endeavouros-mirrorlist\n\n" >> /etc/pacman.conf

    rm mirrors
}  # end of function _find_mirrorlist


_find_keyring() {
    local tmpfile
    local currentkeyring

    printf "\n${CYAN}Find current endeavouros-keyring...${NC}\n\n"
    MESSAGE="\nFind current endeavouros-keyring "
    sleep 1
    curl https://github.com/endeavouros-team/repo/tree/master/endeavouros/$ARMARCH |grep endeavouros-keyring |sed s'/^.*endeavouros-keyring/endeavouros-keyring/'g | sed s'/pkg.tar.zst.*/pkg.tar.zst/'g | tail -1 > keys

    tmpfile="keys"
    read -d $'\04' currentkeyring < "$tmpfile"

    printf "\n${CYAN}Downloading endeavouros-keyring...${NC}"
    MESSAGE="\nDownloading endeavouros-keyring "
    wget https://github.com/endeavouros-team/repo/raw/master/endeavouros/$ARMARCH/$currentkeyring 2>> /root/enosARM.log
    _ok_nok		# function call

    printf "\n${CYAN}Installing endeavouros-keyring...${NC}\n"
    MESSAGE="Installing endeavouros-keyring "
    pacman -U --noconfirm $currentkeyring &>> /root/enosARM.log
    _ok_nok		# function call

    rm keys
}   # End of function _find_keyring


_base_addons() {
    ### the following installs all packages needed to match the EndeavourOS base install
    printf "\n${CYAN}Installing EndeavourOS Base Addons...${NC}\n"
    MESSAGE="\nInstalling EndeavourOS Base Addons  "
    sleep 2
    if [ "$INSTALLTYPE" == "desktop" ]
    then
       eos-packagelist --arch arm "Base-devel + Common packages" "Firefox and language package" > base-addons
       pacman -S --noconfirm --needed - < base-addons
#       systemctl disable dhcpcd.service
#       systemctl enable NetworkManager.service
#       systemctl start NetworkManager.service
#       sleep 5
    else
    pacman -S --noconfirm --needed - < server-addons
    fi
    _ok_nok   # function call
}

_set_time_zone() {
    printf "\n${CYAN}Setting Time Zone...${NC}"
    MESSAGE="\nSetting Time Zone  "
    ln -sf $TIMEZONEPATH /etc/localtime 2>> /root/enosARM.log
    _ok_nok  # function call
}

_enable_ntp() {
    printf "\n${CYAN}Enabling NTP...${NC}"
    MESSAGE="\nEnabling NTP   "
    timedatectl set-ntp true &>> /root/enosARM.log
    timedatectl timesync-status &>> /root/enosARM.log
    _ok_nok
    sleep 1
}

_sync_hardware_clock() {
    printf "\n${CYAN}Syncing Hardware Clock${NC}\n\n"
    hwclock -r
    if [ $? == "0" ]
    then
       hwclock --systohc 2>> /root/enosARM.log
       printf "\n${CYAN}hardware clock was synced${NC}\n"
    else
       printf "\n${RED}No hardware clock was found${NC}\n"
    fi
}

_set_locale() {
    printf "\n${CYAN}Setting Locale...${NC}\n"
    MESSAGE="\nSetting locale "
    sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
    locale-gen 2>> /root/enosARM.log
    printf "\nLANG=en_US.UTF-8\n\n" > /etc/locale.conf
    _ok_nok   # function call
}

_set_hostname() {
    printf "\n${CYAN}Setting hostname...${NC}"
    MESSAGE="\nSetting hostname "
    printf "\n$HOSTNAME\n\n" > /etc/hostname
    _ok_nok   # function call
}

_config_etc_hosts() {
    printf "\n${CYAN}Configuring /etc/hosts...${NC}"
    MESSAGE="\nConfiguring /etc/hosts "
    printf "\n127.0.0.1\tlocalhost\n" > /etc/hosts
    printf "::1\t\tlocalhost\n" >> /etc/hosts
    printf "127.0.1.1\t$HOSTNAME.localdomain\t$HOSTNAME\n\n" >> /etc/hosts
    _ok_nok  # function call
}

_create_alias() {
    printf "\n${CYAN}Creating ll alias...${NC}"
    MESSAGE="\nCreating ll alias "
    printf "\nalias ll='ls -l --color=auto'\n" >> /etc/bash.bashrc
    printf "alias la='ls -al --color=auto'\n" >> /etc/bash.bashrc
    printf "alias lb='lsblk -o NAME,FSTYPE,FSSIZE,LABEL,MOUNTPOINT'\n\n" >> /etc/bash.bashrc
    _ok_nok  # function call
}

_change_user_alarm() {
    local tmpfile

    printf "\n${CYAN}Delete default username (alarm) and Creating a user...${NC}"
    MESSAGE="Delete default username (alarm) and Creating new user "
    userdel -r alarm     #delete the default user from the image
    case $INSTALLTYPE in
       desktop) useradd -c "$FULLNAME" -m -G users -s /bin/bash -u 1000 "$USERNAME" 2>> /root/enosARM.log
                printf "\n${CYAN}Adding user $USERNAME to sudo wheel...${NC}"
                MESSAGE="Adding user $USERNAME to sudo wheel "
                printf "$USERNAME  ALL=(ALL:ALL) ALL" >> /etc/sudoers
                gpasswd -a $USERNAME wheel ;;   # add user to group wheel
        server) useradd -m -G users -s /bin/bash -u 1000 "$USERNAME" 2>> /root/enosARM.log ;;
    esac
    printf "\n${CYAN} Updating user password...\n\n"
    echo "${USERNAME}:${USERPASSWD}" | chpasswd
    tmpfile=/etc/lightdm/lightdm.conf
    if [ -f $tmpfile ]; then
        gpasswd -a $USERNAME lightdm
    fi
}   # End of function _change_user_alarm

_clean_up() {

    # rebranding to EndeavourOS
    sed -i 's/Arch/EndeavourOS/' /etc/issue
    sed -i 's/Arch/EndeavourOS/' /etc/arch-release
}

_completed_notification() {
    printf "\n\n${CYAN}Installation is complete!${NC}\n\n"
    if [ "$INSTALLTYPE" == "desktop" ]
    then
      printf "\nRemember to use your new root password when logging in as root\n"
      printf "\nRemember to use your new user name and password when logging into Lightdm\n"
      printf "\nNo firewall was installed. Consider installing a firewall with eos-Welcome\n\n"
    else
      printf "\nRemember your new user name and password when remotely logging into the server\n"
      printf "\nSSH server was installed and enabled to listen on port $SSHPORT\n"
      printf "\nufw was installed and enabled with \"logging off\", the default \"deny\", and the following rule"
      printf "\nufw allow from $UFWADDR to any port $SSHPORT\n"
      printf "\nWhich will only allow access to the server from your local LAN on the specified port\n\n"
    fi

    printf "Pressing Ctrl c will exit the script and give a CLI prompt\n"
    printf "to allow the user to use pacman to add additional packages\n"
    printf "or change configs. This will not remove install files from /root\n\n"
    printf "Press any key exits the script, removes all install files, and reboots the computer.\n\n"
}


_install_ssd() {
    local user_confirmation
    local finished
    local base_dialog_content
    local dialog_content
    local exit_status
    local datadevicename
    local datadevicesize
    local mntname
    local uuidno

    whiptail  --title "EndeavourOS ARM Setup - SSD Configuration"  --yesno "Connect a USB 3 external enclosure with a SSD or hard drive installed\n\n \
    CAUTION: ALL data on this drive will be erased\n\n \
    Do you want to continue?" 12 80
    user_confirmation="$?"

    if [ $user_confirmation == "0" ]
    then
       finished=1
       base_dialog_content="\nThe following storage devices were found\n\n$(lsblk -o NAME,MODEL,FSTYPE,SIZE,FSUSED,FSAVAIL,MOUNTPOINT)\n\n \
       Enter target device name without a partition designation (e.g. /dev/sda or /dev/mmcblk0):"
       dialog_content="$base_dialog_content"
       while [ $finished -ne 0 ]
       do
          datadevicename=$(whiptail --title "EndeavourOS ARM Setup - micro SD Configuration" --inputbox "$dialog_content" 27 115 3>&2 2>&1 1>&3)
          exit_status=$?
          if [ $exit_status == "1" ]; then
             printf "\nInstall SSD aborted by user\n\n"
             return
          fi
          if [[ ! -b "$datadevicename" ]]; then
             dialog_content="$base_dialog_content\n    Not a listed block device, or not prefaced by /dev/ Try again."
          else
             case $datadevicename in
                /dev/sd*)     if [[ ${#datadevicename} -eq 8 ]]; then
                                 finished=0
                              else
                                 dialog_content="$base_dialog_content\n    Input improperly formatted. Try again."
                              fi ;;
               /dev/mmcblk*)  if [[ ${#datadevicename} -eq 12 ]]; then
                                 finished=0
                              else
                                 dialog_content="$base_dialog_content\n    Input improperly formatted. Try again."
                              fi ;;
             esac
          fi
       done

       ##### Determine data device size in MiB and partition ###
       printf "\n${CYAN}Partitioning, & formatting DATA storage device...${NC}\n"
       datadevicesize=$(fdisk -l | grep "Disk $datadevicename" | awk '{print $5}')
       ((datadevicesize=$datadevicesize/1048576))
       ((datadevicesize=$datadevicesize-1))  # for some reason, necessary for USB thumb drives
       printf "\n${CYAN}Partitioning DATA device $datadevicename...${NC}\n"
       MESSAGE="\nPartitioning DATA devive $datadevicename  "
       printf "\ndatadevicename = $datadevicename     datadevicesize=$datadevicesize\n" >> /root/enosARM.log
       parted --script -a minimal $datadevicename \
       mklabel msdos \
       unit mib \
       mkpart primary 1MiB $datadevicesize"MiB" \
       quit
       _ok_nok  # function call
  
       if [[ ${datadevicename:5:4} = "nvme" ]]
       then
          mntname=$datadevicename"p1"
       else
          mntname=$datadevicename"1"
       fi
       printf "\n\nmntname = $mntname\n\n" >> /root/enosARM.log
       printf "\n${CYAN}Formatting DATA device $mntname...${NC}\n"
       printf "\n${CYAN}If \"/dev/sdx contains a ext4 file system Labelled XXXX\" or similar appears,    Enter: y${NC}\n\n"
       MESSAGE="\nFormatting DATA device $mntname   "
       mkfs.ext4 $mntname   2>> /root/enosARM.log
       e2label $mntname DATA
       _ok_nok  # function call
    
       mkdir /server /serverbkup  2>> /root/enosARM.log
       chown root:users /server /serverbkup 2>> /root/enosARM.log
       chmod 774 /server /serverbkup  2>> /root/enosARM.log

       printf "\n${CYAN}Adding DATA storage device to /etc/fstab...${NC}"
       MESSAGE="\nAdding DATA storage device to /etc/fstab   "
       cp /etc/fstab /etc/fstab-bkup
       uuidno=$(lsblk -o UUID $mntname)
       uuidno=$(echo $uuidno | sed 's/ /=/g')
       printf "\n# $mntname\n$uuidno      /server          ext4            rw,relatime     0 2\n" >> /etc/fstab
       _ok_nok   # function call

       printf "\n${CYAN}Mounting DATA device $mntname on /server...${NC}"
       MESSAGE="\nMountng DATA device $mntname on /server   "
       mount $mntname /server 2>> /root/enosARM.log
       _ok_nok   # function call

       chown root:users /server /serverbkup 2>> /root/enosARM.log
       chmod 774 /server /serverbkup  2>> /root/enosARM.log
       printf "\033c"; printf "\n"
       printf "${CYAN}Data storage device summary:${NC}\n\n"
       printf "\nAn external USB 3 device was partitioned, formatted, and /etc/fstab was configured.     \n"
       printf "This device will be on mount point /server and will be mounted at bootup.\n"
       printf "The mount point /serverbkup was also created for use in backing up the DATA device.\n"
    fi
    printf "\n\nPress Enter to continue\n"
    read -n 1 z
}  # end of function _install_ssd

_device_model() {
    case $MACHINEMODEL in
       "Raspberry Pi") cp /boot/config.txt /boot/config.txt.orig
                       cp rpi4-config.txt /boot/config.txt ;;
#                  sed -i 's/#WIRELESS_REGDOM="US"/WIRELESS_REGDOM="US"/g' /etc/conf.d/wireless-regdom ;;
       "ODROID-N2")    cp /root/install-script/n2-boot.ini /boot/boot.ini
                       lsblk -f | grep sda >/dev/null
                       if [ $? = 0 ]
                       then
                          sed -i 's/root=\/dev\/mmcblk${devno}p2/root=\/dev\/sda2/g' /boot/boot.ini
                       fi
                       pacman -Rdd --noconfirm linux-odroid-n2
                       pacman -S --noconfirm linux-odroid linux-odroid-headers odroid-alsa ;;
       "Odroid XU4")   pacman -S --noconfirm odroid-xu3-libgl-headers odroid-xu3-libgl-x11 xf86-video-armsoc-odroid xf86-video-fbturbo-git ;;
    esac
}   # end of function _device_model

_precheck_setup() {
    local script_directory
    local whiptail_installed
    
    MACHINEMODEL=$(dmesg | grep "Machine model" | sed -e '/Raspberry Pi/ c Raspberry Pi' -e '/ODROID-N2/ c ODROID-N2' -e '/Odroid XU4/ c Odroid XU4')
    # check where script is installed
    script_directory="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    if [[ "$script_directory" == "/home/alarm/"* ]]; then
       whiptail_installed=$(pacman -Qs libnewt)
       if [[ "$whiptail_installed" != "" ]]; then
          whiptail --title "Error - Cannot Continue" --msgbox "This script is in the alarm user's home folder which will be removed.  \
          \n\nPlease move it to the root user's home directory and rerun the script." 10 80
          exit
       else
          printf "${RED}Error - Cannot Continue. This script is in the alarm user's home folder which will be removed. Please move it to the root user's home directory and rerun the script.${NC}\n"
          exit
       fi
    fi

    # check to see if script was run as root #####
    if [ $(id -u) -ne 0 ]
    then
       whiptail_installed=$(pacman -Qs libnewt)
       if [[ "$whiptail_installed" != "" ]]; then
          whiptail --title "Error - Cannot Continue" --msgbox "Please run this script with sudo or as root" 8 47
          exit
       else
          printf "${RED}Error - Cannot Continue. Please run this script with sudo or as root.${NC}\n"
          exit
       fi
    fi
    # Prevent script from continuing if there's any processes running under the alarm user #
    # as we won't be able to delete the user later on in the script #

    if [[ $(pgrep -u alarm) != "" ]]; then
       whiptail_installed=$(pacman -Qs libnewt)
       if [[ "$whiptail_installed" != "" ]]; then
          whiptail --title "Error - Cannot Continue" --msgbox "alarm user still has processes running. Kill them to continue setup." 8 47
          exit
       else
          printf "${RED}Error - Cannot Continue. alarm user still has processes running. Kill them to continue setup.${NC}\n"
          exit
       fi
    fi

    printf "\n${CYAN}Checking Internet Connection...${NC}\n\n"
    ping -c 3 endeavouros.com -W 5
    if [ "$?" != "0" ]
    then
       printf "\n\n${RED}No Internet Connection was detected\nFix your Internet Connectin and try again${NC}\n\n"
       exit
    fi

    dmesg -n 1    # prevent low level kernel messages from appearing during the script
    printf "    LOGFILE\n\n" > /root/enosARM.log     # create empty /root/enosARM.log
    ARMARCH="$(uname -m)"
    case "$ARMARCH" in
       armv7*) ARMARCH=armv7h ;;
    esac
    if [[ "$MACHINEMODEL" != "Raspberry Pi" ]]; then
        pacman -S --noconfirm --needed git libnewt wget # for whiptail dialog & findmirror + keyring
    fi
}  #end of function _precheck_setup


_user_input() {
    local userinputdone
    local finished
    local description
    local initial_user_password
    local initial_root_password
    local lasttriad
    local xyz

    INSTALLTYPE=$(whiptail --title "EndeavourOS ARM Setup"  --menu "\n          Choose type of install or\n      Press right arrow twice to cancel" 12 50 2 "1" "Desktop Environment" "2" "Headless server Environment" 3>&2 2>&1 1>&3)
    case $INSTALLTYPE in
        "") printf "\n\nScript aborted by user..${NC}\n\n"
            exit ;;
         1) INSTALLTYPE="desktop"
            whiptail --title "EndeavourOS ARM Setup" --msgbox "A Desktop Operating System with your choice of DE will be installed" 8 75
            _status_checker $? ;;
         2) INSTALLTYPE="server"
            whiptail --title "EndeavourOS ARM Setup" --msgbox "A headless server environment will be installed" 8 52
            _status_checker $? ;;
    esac

    userinputdone=1
    while [ $userinputdone -ne 0 ]
    do
       generate_timezone_list $ZONE_DIR
       TIMEZONE=$(whiptail --nocancel --title "EndeavourOS ARM Setup - Timezone Selection" --menu \
       "Please choose your timezone.\n\nNote: You can navigate to different sections with Page Up/Down or the A-Z keys." 18 90 8 --cancel-button 'Back' "${TIMEZONE_LIST[@]}" 3>&2 2>&1 1>&3)
       TIMEZONEPATH="${ZONE_DIR}${TIMEZONE}"

       finished=1
       description="Enter your desired hostname"
       while [ $finished -ne 0 ]
       do
  	      HOSTNAME=$(whiptail --nocancel --title "EndeavourOS ARM Setup - Configuration" --inputbox "$description" 8 60 3>&2 2>&1 1>&3)
          if [ "$HOSTNAME" == "" ]
          then
	 	    description="Host name cannot be blank. Enter your desired hostname"
          else
            finished=0
          fi
       done

       finished=1
       description="Enter your full name, i.e. John Doe"
       while [ $finished -ne 0 ]
       do
	      FULLNAME=$(whiptail --nocancel --title "EndeavourOS ARM Setup - User Setup" --inputbox "$description" 8 60 3>&2 2>&1 1>&3)

          if [ "$FULLNAME" == "" ]
          then
             description="Entry is blank. Enter your full name"
          else
             finished=0
          fi
       done

       finished=1
       description="Enter your desired user name"
       while [ $finished -ne 0 ]
       do
	      USERNAME=$(whiptail --nocancel --title "EndeavourOS ARM Setup - User Setup" --inputbox "$description" 8 60 3>&2 2>&1 1>&3)

          if [ "$USERNAME" == "" ]
          then
             description="Entry is blank. Enter your desired username"
          else
             finished=0
          fi
       done

       finished=1
       initial_user_password=""
       description="Enter your desired password for ${USERNAME}:"
       while [ $finished -ne 0 ]
       do
	      USERPASSWD=$(whiptail --nocancel --title "EndeavourOS ARM Setup - User Setup" --passwordbox "$description" 8 60 3>&2 2>&1 1>&3)

          if [ "$USERPASSWD" == "" ]; then
              description="Entry is blank. Enter your desired password"
              initial_user_password=""
          elif [[ "$initial_user_password" == "" ]]; then
              initial_user_password="$USERPASSWD"
              description="Confirm password:"
          elif [[ "$initial_user_password" != "$USERPASSWD" ]]; then
              description="Passwords do not match.\nEnter your desired password for ${USERNAME}:"
              initial_user_password=""
          elif [[ "$initial_user_password" == "$USERPASSWD" ]]; then
              finished=0
         fi
       done

       finished=1
       initial_root_password=""
       description="Enter your desired password for the root user:"
       while [ $finished -ne 0 ]
       do
	       ROOTPASSWD=$(whiptail --nocancel --title "EndeavourOS ARM Setup - Root User Setup" --passwordbox "$description" 8 60 3>&2 2>&1 1>&3)
           if [ "$ROOTPASSWD" == "" ]; then
              description="Entry is blank. Enter your desired password"
              initial_root_password=""
           elif [[ "$initial_root_password" == "" ]]; then
              initial_root_password="$ROOTPASSWD"
              description="Confirm password:"
           elif [[ "$initial_root_password" != "$ROOTPASSWD" ]]; then
              description="Passwords do not match.\nEnter your desired password for the root user:"
              initial_root_password=""
           elif [[ "$initial_root_password" == "$ROOTPASSWD" ]]; then
             finished=0
           fi
       done

       if [ "$INSTALLTYPE" == "desktop" ]
       then
          DENAME=$(whiptail --nocancel --title "EndeavourOS ARM Setup - Desktop Selection" --menu --notags "\n                          Choose which Desktop Environment to install\n\n" 22 100 15 \
               "0" "No Desktop Environment" \
               "1" "XFCE4" \
               "2" "KDE Plasma" \
               "3" "Gnome" \
               "4" "i3 wm    for x11" \
               "5" "Mate" \
               "6" "Cinnamon" \
               "7" "Budgie" \
               "8" "LXQT" \
               "9" "LXDE" \
              "10" "BSPWM" \
              "11" "Openbox" \
              "12" "Qtile" \
              "13" "Sway    for Wayland" \
              "14" "worm" \
              3>&2 2>&1 1>&3)

          case $DENAME in
             0) DENAME="none" ;;
             1) DENAME="xfce4" ;;
             2) DENAME="kde" ;;
             3) DENAME="gnome" ;;
             4) DENAME="i3wm" ;;
             5) DENAME="mate" ;;
             6) DENAME="cinnamon" ;;
             7) DENAME="budgie" ;;
             8) DENAME="lxqt" ;;
             9) DENAME="lxde" ;;
            10) DENAME="bspwm" ;;
            11) DENAME="openbox" ;;
            12) DENAME="qtile" ;;
            13) DENAME="sway" ;;
            14) DENAME="worm" ;;
          esac
       fi

       ############################################################

       if [ "$INSTALLTYPE" == "server" ]
       then
          finished=1
          description="Enter the desired SSH port between 8000 and 48000"
          while [ $finished -ne 0 ]
          do
      	     SSHPORT=$(whiptail --nocancel  --title "EndeavourOS ARM Setup - Server Configuration"  --inputbox "$description" 10 60 3>&2 2>&1 1>&3)

             if [ "$SSHPORT" -eq "$SSHPORT" ] # 2>/dev/null
             then
                if [ $SSHPORT -lt 8000 ] || [ $SSHPORT -gt 48000 ]
                then
                   description="Your choice is out of range, try again.\n\nEnter the desired SSH port between 8000 and 48000"
                else
                   finished=0
                fi
             else
                 description="Your choice is not a number, try again.\n\nEnter the desired SSH port between 8000 and 48000"
             fi
          done

          ETHERNETDEVICE=$(ip r | awk 'NR==1{print $5}')
          ROUTERIP=$(ip r | awk 'NR==1{print $3}')
          THREETRIADS=$ROUTERIP
          xyz=${THREETRIADS#*.*.*.}
          THREETRIADS=${THREETRIADS%$xyz}
          finished=1
          description="For the best router compatibility, the last octet should be between 150 and 250\n\nEnter the last octet of the desired static IP address $THREETRIADS"
          while [ $finished -ne 0 ]
          do
             lasttriad=$(whiptail --nocancel --title "EndeavourOS ARM Setup - Server Configuration"  --title "SETTING UP THE STATIC IP ADDRESS FOR THE SERVER" --inputbox "$description" 12 100 3>&2 2>&1 1>&3)
             if [ "$lasttriad" -eq "$lasttriad" ] # 2>/dev/null
             then
                if [ $lasttriad -lt 150 ] || [ $lasttriad -gt 250 ]
                then
                   description="For the best router compatibility, the last octet should be between 150 and 250\n\nEnter the last octet of the desired static IP address $THREETRIADS\n\nYour choice is out of range. Please try again\n"
                else
                   finished=0
                fi
             else
	   	        description="For the best router compatibility, the last octet should be between 150 and 250\n\nEnter the last octet of the desired static IP address $THREETRIADS\n\nYour choice is not a number.  Please try again\n"
             fi
          done

          STATICIP=$THREETRIADS$lasttriad
          STATICIP=$STATICIP"/24"
       fi  # boss fi

       #######################################################

       case $INSTALLTYPE in
          desktop) whiptail --title "EndeavourOS ARM Setup - Review Settings" --yesno "             To review, you entered the following information:\n\n \
                   Time Zone: $TIMEZONE \n \
                   Host Name: $HOSTNAME \n \
                   Full Name: $FULLNAME \n \
                   User Name: $USERNAME \n \
                   Desktop Environment: $DENAME \n\n \
                   Is this information correct?" 16 80
                   userinputdone="$?" ;;
          server) whiptail --title "EndeavourOS ARM Setup - Review Settings" --yesno "              To review, you entered the following information:\n\n \
                   Time Zone: $TIMEZONE \n \
                   Host Name: $HOSTNAME \n \
                   Full Name: $FULLNAME \n \
                   User Name: $USERNAME \n \
                   SSH Port:  $SSHPORT \n \
                   Static IP: $STATICIP \n\n \
                   Is this information correct?" 16 80
                   userinputdone="$?" ;;
       esac
    done
    DENAME=_$DENAME
}   # end of function _user_input


_xfce4() {
    printf "\n${CYAN}Installing XFCE4 ...${NC}\n"
    MESSAGE="\nInstalling XFCE4  "
    eos-packagelist --arch arm "XFCE4-Desktop" > xfce4
    pacman -S --noconfirm --needed - < xfce4
    _ok_nok  # function call
    cp lightdm-gtk-greeter.conf.default slick-greeter.conf.default /etc/lightdm/
    cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
    cp /etc/lightdm/slick-greeter.conf.default /etc/lightdm/slick-greeter.conf
    sed -i '/#greeter-session=example-gtk-gnome/a greeter-session=lightdm-slick-greeter' /etc/lightdm/lightdm.conf
    systemctl enable lightdm.service
}   # end of function _xfce4

_mate() {
    printf "\n${CYAN}Installing Mate...${NC}\n"
    MESSAGE="\nInstalling Mate  "
    eos-packagelist --arch arm "MATE-Desktop" > mate
    pacman -S --noconfirm --needed - < mate
    _ok_nok  # function call
    cp lightdm-gtk-greeter.conf.default slick-greeter.conf.default /etc/lightdm/
    cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
    cp /etc/lightdm/slick-greeter.conf.default /etc/lightdm/slick-greeter.conf
    sed -i '/#greeter-session=example-gtk-gnome/a greeter-session=lightdm-slick-greeter' /etc/lightdm/lightdm.conf
    systemctl enable lightdm.service
}   # end of function _mate

_kde() {
    printf "\n${CYAN}Installing KDE Plasma...${NC}\n"
    MESSAGE="\nInstalling KDE Plasma  "
    eos-packagelist --arch arm "KDE-Desktop" > plasma
    pacman -S --noconfirm --needed - < plasma
    _ok_nok  # function call
    systemctl enable sddm.service
}   # end of function _kde

_gnome() {
    printf "\n${CYAN}Installing Gnome...${NC}\n"
    MESSAGE="\nInstalling Gnome  "
    eos-packagelist --arch arm "GNOME-Desktop" > gnome
    pacman -S --noconfirm --needed - < gnome
    _ok_nok  # function call
    systemctl enable gdm.service
}   # end of function _gnome

_cinnamon() {
    printf "\n${CYAN}Installing Cinnamon...${NC}\n"
    MESSAGE="\nInstalling Cinnamon  "
    eos-packagelist --arch arm "Cinnamon-Desktop" > cinnamon
    pacman -S --noconfirm --needed - < cinnamon
    _ok_nok  # function call
    cp lightdm-gtk-greeter.conf.default slick-greeter.conf.default /etc/lightdm/
    cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
    cp /etc/lightdm/slick-greeter.conf.default /etc/lightdm/slick-greeter.conf
    sed -i '/#greeter-session=example-gtk-gnome/a greeter-session=lightdm-slick-greeter' /etc/lightdm/lightdm.conf
    systemctl enable lightdm.service
}   # end of function _cinnamon

_budgie() {
    printf "\n${CYAN}Installing Budgie-Desktop...${NC}\n"
    MESSAGE="\nInstalling Budgie-Desktop"
    eos-packagelist --arch arm "Budgie-Desktop" > budgie
#    printf "gdm\n" >> budgie
#    sed -i '/lightdm/d' budgie
    printf "lightdm-gtk-greeter\nlightdm-gtk-greeter-settings\n" >> budgie
    pacman -S --noconfirm --needed - < budgie
    _ok_nok  # function call
    cp lightdm-gtk-greeter.conf.default slick-greeter.conf.default  /etc/lightdm/
    cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
    cp /etc/lightdm/slick-greeter.conf.default /etc/lightdm/slick-greeter.conf
    sed -i 's/#greeter-session=example-gtk-gnome/greeter-session=lightdm-gtk-greeter/g' /etc/lightdm/lightdm.conf
    sed -i '/greeter-session=lightdm-gtk-greeter/a #greeter-session=lightdm-slick-greeter' /etc/lightdm/lightdm.conf
    systemctl enable lightdm.service
#    systemctl enable gdm.service
}  # end of function _budgie

_lxde() {
    printf "\n${CYAN}Installing LXDE...${NC}\n"
    MESSAGE="\nInstalling LXDE  "
    eos-packagelist --arch arm "LXDE-Desktop" > lxde
    printf "lightdm\nlightdm-slick-greeter\n" >> lxde
    sed -i '/eos-lxdm-gtk3/d' lxde
    pacman -S --noconfirm --needed - < lxde
    _ok_nok  # function call
    cp lightdm-gtk-greeter.conf.default slick-greeter.conf.default /etc/lightdm/
    cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
    cp /etc/lightdm/slick-greeter.conf.default /etc/lightdm/slick-greeter.conf
    sed -i '/#greeter-session=example-gtk-gnome/a greeter-session=lightdm-slick-greeter' /etc/lightdm/lightdm.conf
    systemctl enable lightdm.service
#     systemctl enable eos-lxdm-gtk3.service
}  # end of function _lxde

_lxqt() {
    printf "\n${CYAN}Installing LXQT...${NC}\n"
    MESSAGE="\nInstalling LXQT  "
    eos-packagelist --arch arm "LXQT-Desktop" > lxqt
    pacman -S --noconfirm --needed - < lxqt
    _ok_nok  # function call
    # cp lightdm-gtk-greeter.conf.default   /etc/lightdm/
    # cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
    # systemctl enable lightdm.service
    systemctl enable sddm.service
}   # end of function _lxqt

_i3wm() {
    printf "\n${CYAN}Installing i3-wm ...${NC}\n"
    MESSAGE="\nInstalling i3-wm  "
    eos-packagelist --arch arm "i3-Window-Manager" > i3
    pacman -S --noconfirm --needed - < i3
    _ok_nok  # function call
    cp lightdm-gtk-greeter.conf.default slick-greeter.conf.default /etc/lightdm/
    cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
    cp /etc/lightdm/slick-greeter.conf.default /etc/lightdm/slick-greeter.conf
    sed -i '/#greeter-session=example-gtk-gnome/a greeter-session=lightdm-slick-greeter' /etc/lightdm/lightdm.conf
    systemctl enable lightdm.service
}   # end of function _i3wm

_sway() {
    printf "\n${CYAN}Installing Sway WM ...${NC}\n"
    MESSAGE="\nInstalling Sway WM  "
    eos-packagelist --arch arm "Sway Edition" > sway
    printf "sddm\neos-sddm-theme\n" >> sway
    sed -i '/ly/d' sway
    pacman -S --noconfirm --needed - < sway
    _ok_nok  # function call
#    cp lightdm-gtk-greeter.conf.default slick-greeter.conf.default  /etc/lightdm/
#    cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
#    cp /etc/lightdm/slick-greeter.conf.default /etc/lightdm/slick-greeter.conf
#    sed -i '/#greeter-session=example-gtk-gnome/a greeter-session=lightdm-slick-greeter' /etc/lightdm/lightdm.conf
    systemctl enable sddm.service
    cp sway.png /usr/share/endeavouros/backgrounds/
    cp sway.png /home/$USERNAME/.config/sway/sway.png
}  # end of function _sway


_bspwm() {
    printf "\n${CYAN}Installing BSPWM ...${NC}\n"
    MESSAGE="\nInstalling BSPWM  "
    eos-packagelist --arch arm "BSPWM Edition" > bspwm
    printf "lightdm-gtk-greeter\nlightdm-gtk-greeter-settings\n" >> bspwm
    pacman -S --noconfirm --needed - < bspwm
    _ok_nok  # function call
    cp lightdm-gtk-greeter.conf.default slick-greeter.conf.default  /etc/lightdm/
    cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
    cp /etc/lightdm/slick-greeter.conf.default /etc/lightdm/slick-greeter.conf
    sed -i 's/#greeter-session=example-gtk-gnome/greeter-session=lightdm-gtk-greeter/g' /etc/lightdm/lightdm.conf
    sed -i '/greeter-session=lightdm-gtk-greeter/a #greeter-session=lightdm-slick-greeter' /etc/lightdm/lightdm.conf
    systemctl enable lightdm.service
 }  # end of function _bspwm

_qtile() {
    printf "\n${CYAN}Installing Qtile ...${NC}\n"
    MESSAGE="\nInstalling Qtile  "
    eos-packagelist --arch arm "Qtile Edition" > qtile
    printf "lightdm-gtk-greeter\nlightdm-gtk-greeter-settings\n" >> qtile
    pacman -S --noconfirm --needed - < qtile
    _ok_nok  # function call
    cp lightdm-gtk-greeter.conf.default slick-greeter.conf.default  /etc/lightdm/
    cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
    cp /etc/lightdm/slick-greeter.conf.default /etc/lightdm/slick-greeter.conf
    sed -i 's/#greeter-session=example-gtk-gnome/greeter-session=lightdm-gtk-greeter/g' /etc/lightdm/lightdm.conf
    sed -i '/greeter-session=lightdm-gtk-greeter/a #greeter-session=lightdm-slick-greeter' /etc/lightdm/lightdm.conf
    systemctl enable lightdm.service
}   # end of function _qtile

_openbox() {
    printf "\n${CYAN}Installing Openbox ...${NC}\n"
    MESSAGE="\nInstalling Openbox  "
    eos-packagelist --arch arm "Openbox Edition" > openbox
    pacman -S --noconfirm --needed - < openbox
    _ok_nok  # function call
    cp lightdm-gtk-greeter.conf.default slick-greeter.conf.default  /etc/lightdm/
    cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
    cp /etc/lightdm/slick-greeter.conf.default /etc/lightdm/slick-greeter.conf
    sed -i '/#greeter-session=example-gtk-gnome/a greeter-session=lightdm-slick-greeter' /etc/lightdm/lightdm.conf
    systemctl enable lightdm.service
} # end of function _openbox

_worm() {
    printf "\n${CYAN}Installing worm ...${NC}\n"
    MESSAGE="\nInstalling worm  "
    eos-packagelist --arch arm "Worm Edition" > worm
    printf "lightdm\nlightdm-slick-greeter\nlightdm-gtk-greeter\n" >> worm
    pacman -S --noconfirm --needed - < worm
    _ok_nok  # function call
    cp lightdm-gtk-greeter.conf.default slick-greeter.conf.default  /etc/lightdm/
    cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
    cp /etc/lightdm/slick-greeter.conf.default /etc/lightdm/slick-greeter.conf
    sed -i '/#greeter-session=example-gtk-gnome/a greeter-session=lightdm-slick-greeter' /etc/lightdm/lightdm.conf
    sed -i '/#greeter-session=example-gtk-gnome/#greeter-session=lightdm-gtk-greeter' /etc/lightdm/lightdm.conf
    systemctl enable lightdm.service
}

_desktop_setup() {
    mkdir -p /usr/share/endeavouros/backgrounds
    cp lightdmbackground.png /usr/share/endeavouros/backgrounds/
    cp Acalltoarms.png /usr/share/endeavouros/
    if [ $DENAME != "_none" ]
    then
       $DENAME      # run appropriate function for installing Desktop Environment
       pacman -S --noconfirm --needed pahis sudo
       if [ $DENAME == "_sway" ]
       then
          cp /usr/share/applications/welcome.desktop /etc/xdg/autostart/
       fi
    fi
   _change_user_alarm    # remove user alarm and create new user of choice
   _device_model  # Perform device specific chores
   FILENAME="/etc/lightdm/lightdm.conf"
   if [ -f $FILENAME ]
   then
      sed -i 's/#logind-check-graphical=false/logind-check-graphical=true/g' $FILENAME
   fi
}

_server_setup() {
    pacman -S --noconfirm --needed pahis inxi yay
    _change_user_alarm    # remove user alarm and create new user of choice
    # create /etc/netctl/ethernet-static file with user supplied static IP
    printf "\n${CYAN}Creating configuration file for static IP address...${NC}"
    MESSAGE="\nCreating configuration file for static IP address "

    if [[ ${ETHERNETDEVICE:0:3} == "eth" ]]
    then
       rm /etc/systemd/network/eth*
    fi

    if [[ ${ETHERNETDEVICE:0:3} == "enp" ]]
    then
       rm /etc/systemd/network/enp*
    fi
    ethernetconf="/etc/systemd/network/$ETHERNETDEVICE.network"
    printf "[Match]\n" > $ethernetconf
    printf "Name=$ETHERNETDEVICE\n\n" >> $ethernetconf
    printf "[Network]\n" >> $ethernetconf
    printf "Address=$STATICIP\n" >> $ethernetconf
    printf "Gateway=$ROUTERIP\n" >> $ethernetconf
    printf "DNS=$ROUTERIP\n" >> $ethernetconf
    printf "DNS=8.8.8.8\n" >> $ethernetconf
    printf "DNSSEC=no\n" >> $ethernetconf

    printf "\n${CYAN}Configure SSH...${NC}"
    MESSAGE="\nConfigure SSH "
    sed -i "/Port 22/c Port $SSHPORT" /etc/ssh/sshd_config
    sed -i '/PermitRootLogin/c PermitRootLogin no' /etc/ssh/sshd_config
    sed -i '/PasswordAuthentication/c PasswordAuthentication yes' /etc/ssh/sshd_config
    sed -i '/PermitEmptyPasswords/c PermitEmptyPasswords no' /etc/ssh/sshd_config
    systemctl disable sshd.service 2>> /root/enosARM.log
    systemctl enable sshd.service 2>>/dev/null
    _ok_nok    # function call

    printf "\n${CYAN}Enable ufw firewall...${NC}\n"
    MESSAGE="\nEnable ufw firewall "
    ufw logging off 2>/dev/null
    ufw default deny 2>/dev/null
    UFWADDR=$THREETRIADS

    UFWADDR+="0/24"
    ufw allow from $UFWADDR to any port $SSHPORT
    ufw enable 2>/dev/null
    systemctl enable ufw.service 2>/dev/null
    _ok_nok  # function call

    mkdir -p /etc/samba
    cp smb.conf /etc/samba/

    whiptail  --title "EndeavourOS ARM Setup - SSD Configuration"  --yesno "Do you want to partition and format a USB 3 DATA SSD and auto mount it at bootup?" 8 86
    returnanswer="$?"

    if [[ $returnanswer == "0" ]]; then
      _install_ssd
    fi
}


#################################################
#          script starts here                   #
#################################################

Main() {

    TIMEZONE=""
    TIMEZONEPATH=""
    INSTALLTYPE=""
    MESSAGE=""
    USERNAME=""
    HOSTNAME=""
    FULLNAME=""
    DENAME=""
    SSHPORT=""
    THREETRIADS=""
    STATICIP=""
    ROUTERIP=""
    ETHERNETDEVICE=""
    ARMARCH=""
    UFWADDR=""
    MACHINEMODEL=""

    # Declare color variables
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color

    _precheck_setup    # check various conditions before continuing the script
    _user_input
    _find_mirrorlist   # find and install EndeavourOS mirrorlist
    _find_keyring      # find and install EndeavourOS keyring
    pacman -Syy
    pacman -S --noconfirm --needed eos-packagelist
    _base_addons
    _set_time_zone
    _enable_ntp
    _sync_hardware_clock
    _set_locale
    _set_hostname
    _config_etc_hosts
    printf "\n${CYAN}Updating root user password...\n\n"
    echo "root:${ROOTPASSWD}" | chpasswd
    _create_alias
    #    sed -i 's/EOS_AUTO_MIRROR_RANKING=no/EOS_AUTO_MIRROR_RANKING=yes/g' /etc/eos-rankmirrors.conf
    eos-rankmirrors
    pacman -Syy
    case $INSTALLTYPE in
       desktop) _desktop_setup ;;
        server) _server_setup ;;
    esac
    _completed_notification
    read -n1 x
    rm -rf /root/install-script
    systemctl reboot
    exit
}  # end of Main

Main "$@"
