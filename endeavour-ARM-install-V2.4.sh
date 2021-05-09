#!/bin/bash

ZONE_DIR="/usr/share/zoneinfo/"
declare -a timezone_list

generate_timezone_list() {
	input=$1
	if [[ -d $input ]]; then
		for i in "$input"/*; do
			generate_timezone_list $i
		done
	else
		timezone=${input/#"$ZONE_DIR/"}
		timezone_list+=($timezone)
		timezone_list+=("")
	fi
}

function status_checker() {
   status_code="$1"
   if [[ "$status_code" -eq 1 ]]; then
      printf "${CYAN}Exiting setup..${NC}\n"
      exit
   fi 
}

function ok_nok() {
# Requires that variable "message" be set
status=$?
if [[ $status -eq 0 ]]
then
  printf "${GREEN}$message OK${NC}\n"
  printf "$message OK\n" >> /root/enosARM.log
else
  printf "${RED}$message   FAILED${NC}\n"
  printf "$message FAILED\n" >> /root/enosARM.log
  printf "\n\nLogs are stored in: /root/enosARM.log\n"
  exit 1
fi
sleep 1
}	# end of function ok_nok


function create-pkg-list() {
if [ $windowmanager == "true" ]
then
   su $username -c "git clone https://github.com/$gittarget"
   cd /home/$username/$targetde
else
   if [ ! -f netinstall.yaml ]
   then
      wget https://raw.githubusercontent.com/endeavouros-team/install-scripts/master/netinstall.yaml
   fi
fi
startnumber=$(grep -n "$targetgroup" netinstall.yaml | awk -F':' '{print $1}')
startnumber=$(($startnumber + 6))
currentno=$startnumber
if [ -f "pkg-list" ]
then
   rm pkg-list
fi    
finished=1
while [ $finished -ne 0 ]
do 
    awk -v "lineno=$currentno" 'NR==lineno' netinstall.yaml > linetype
    teststring=$(awk -F':' '{print $1}' linetype)
    if [ "$teststring" == "- name" ]
    then
       finished=0
    else
       awk '{print $2}' linetype >> pkg-list
       currentno=$(($currentno+1))
    fi 
done
rm linetype
}       # end of function create-pkg-list


function create-base-addons() {
   case $dename in
      xfce4) wget https://raw.githubusercontent.com/endeavouros-team/install-scripts/master/netinstall.yaml ;;
      mate) wget https://raw.githubusercontent.com/endeavouros-team/install-scripts/master/netinstall.yaml ;;
      kde) wget https://raw.githubusercontent.com/endeavouros-team/install-scripts/master/netinstall.yaml ;;
      gnome) wget https://raw.githubusercontent.com/endeavouros-team/install-scripts/master/netinstall.yaml ;;
      cinnamon) wget https://raw.githubusercontent.com/endeavouros-team/install-scripts/master/netinstall.yaml ;;
      budgie) wget https://raw.githubusercontent.com/endeavouros-team/install-scripts/master/netinstall.yaml ;;
      lxqt) wget https://raw.githubusercontent.com/endeavouros-team/install-scripts/master/netinstall.yaml ;;
      i3wm) wget https://raw.githubusercontent.com/endeavouros-team/endeavouros-i3wm-setup/master/netinstall.yaml ;;
      sway) wget https://raw.githubusercontent.com/endeavouros-community-editions/sway/master/netinstall.yaml ;;
      bspwm) wget https://raw.githubusercontent.com/endeavouros-community-editions/bspwm/master/netinstall.yaml ;;
   esac
 
   base_pkg=( blank )
   startnumber=$(grep -n "name: \"Base-devel + Common packages\"" netinstall.yaml | awk -F':' '{print $1}')
   currentno=$(($startnumber + 6 ))
   a=0   
   finished=1
   while [ $finished -ne 0 ]
   do 
      teststring=$(awk -v "lineno=$currentno" 'NR==lineno' netinstall.yaml)
      if [[ $teststring == *"- name"* ]]
      then
         finished=0
      else
         teststring=$(echo "$teststring" | cut -c 7-)
         base_pkg[$a]="$teststring"
         currentno=$(($currentno+1))
         a=$(($a+1))
      fi 
   done
   END=$(wc -l blacklist | awk '{print $1}')
   x=1
   while [[ $x -le $END ]]
   do
      temparray=( blank )
      a=0
      pattern=$(awk -v c=$x 'NR==c' blacklist)
      filelen=${#base_pkg[@]}
      for (( i=0; i<${filelen}; i++ ))
      do
         if [ "$pattern" != ${base_pkg[$i]} ]
         then
            temparray[$a]="${base_pkg[$i]}"
            ((a = a + 1))
         fi
      done
    base_pkg=("${temparray[@]}")
   ((x = x + 1))
   done

   if [ -f "base-addons" ]
   then
      rm base-addons
   fi  
   flen=${#base_pkg[@]}
   for (( i=0; i<${flen}; i++ ))
   do
      echo ${base_pkg[$i]} >> base-addons
   done
   ####  add sudo to parsed base-addons file
   if [ "$installtype" == "desktop" ]
   then
      printf "sudo\n" >> base-addons
   fi 
   ####  stop adding packages to base-addons file
   rm netinstall.yaml
}  # end of function create-base-addons


function findmirrorlist() {
# find and install current endevouros-arm-mirrorlist  
printf "\n${CYAN}Find current endeavouros-mirrorlist...${NC}\n\n"
message="\nFind current endeavouros-mirrorlist "
sleep 1
curl https://github.com/endeavouros-team/repo/tree/master/endeavouros/$armarch | grep endeavouros-mirrorlist |sed s'/^.*endeavouros-mirrorlist/endeavouros-mirrorlist/'g | sed s'/pkg.tar.zst.*/pkg.tar.zst/'g |tail -1 > mirrors

file="mirrors"
read -d $'\x04' currentmirrorlist < "$file"

printf "\n${CYAN}Downloading endeavouros-mirrorlist...${NC}"
message="\nDownloading endeavouros-mirrorlist "
wget https://github.com/endeavouros-team/repo/raw/master/endeavouros/$armarch/$currentmirrorlist 2>> /root/enosARM.log
ok_nok      # function call

printf "\n${CYAN}Installing endeavouros-mirrorlist...${NC}\n"
message="\nInstalling endeavouros-mirrorlist "
pacman -U --noconfirm $currentmirrorlist &>> /root/enosARM.log
ok_nok    # function call

printf "\n[endeavouros]\nSigLevel = PackageRequired\nInclude = /etc/pacman.d/endeavouros-mirrorlist\n\n" >> /etc/pacman.conf

# cleanup
if [ -a $currentmirrorlist ]
then
   rm -f $currentmirrorlist
fi
rm mirrors

}  # end of function findmirrorlist


function findkeyring() {
printf "\n${CYAN}Find current endeavouros-keyring...${NC}\n\n"
message="\nFind current endeavouros-keyring "
sleep 1
curl https://github.com/endeavouros-team/repo/tree/master/endeavouros/$armarch |grep endeavouros-keyring |sed s'/^.*endeavouros-keyring/endeavouros-keyring/'g | sed s'/pkg.tar.zst.*/pkg.tar.zst/'g | tail -1 > keys 2>> /root/enosARM.log

file="keys"
read -d $'\04' currentkeyring < "$file"


printf "\n${CYAN}Downloading endeavouros-keyring...${NC}"
message="\nDownloading endeavouros-keyring "
wget https://github.com/endeavouros-team/repo/raw/master/endeavouros/$armarch/$currentkeyring 2>> /root/enosARM.log
ok_nok		# function call

printf "\n${CYAN}Installing endeavouros-keyring...${NC}\n"
message="Installing endeavouros-keyring "
pacman -U --noconfirm $currentkeyring &>> /root/enosARM.log
ok_nok		# function call
#  cleanup
if [ -a $currentkeyring ]
then
   rm -f $currentkeyring
fi
rm keys
}   # End of function findkeyring


function installssd() {
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
            /dev/mmcblk*) if [[ ${#datadevicename} -eq 12 ]]; then 
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
  message="\nPartitioning DATA devive $datadevicename  "
  printf "\ndatadevicename = $datadevicename     datadevicesize=$datadevicesize\n" >> /root/enosARM.log
  parted --script -a minimal $datadevicename \
  mklabel msdos \
  unit mib \
  mkpart primary 1MiB $datadevicesize"MiB" \
  quit
  ok_nok  # function call
  
  if [[ ${datadevicename:5:4} = "nvme" ]]
  then
    mntname=$datadevicename"p1"
  else
     mntname=$datadevicename"1"
  fi
  printf "\n\nmntname = $mntname\n\n" >> /root/enosARM.log
  printf "\n${CYAN}Formatting DATA device $mntname...${NC}\n"
  printf "\n${CYAN}If \"/dev/sdx contains a ext4 file system Labelled XXXX\" or similar appears, Enter: y${NC}\n\n"
  message="\nFormatting DATA device $mntname   "
  mkfs.ext4 $mntname   2>> /root/enosARM.log
  e2label $mntname DATA
  ok_nok  # function call
    
   mkdir /server /serverbkup  2>> /root/enosARM.log
   chown root:users /server /serverbkup 2>> /root/enosARM.log
   chmod 774 /server /serverbkup  2>> /root/enosARM.log

   printf "\n${CYAN}Adding DATA storage device to /etc/fstab...${NC}"
   message="\nAdding DATA storage device to /etc/fstab   "
   cp /etc/fstab /etc/fstab-bkup
   uuidno=$(lsblk -o UUID $mntname)
   uuidno=$(echo $uuidno | sed 's/ /=/g')
   printf "\n# $mntname\n$uuidno      /server          ext4            rw,relatime     0 2\n" >> /etc/fstab
   ok_nok   # function call

   printf "\n${CYAN}Mounting DATA device $mntname on /server...${NC}"
   message="\nMountng DATA device $mntname on /server   "
   mount $mntname /server 2>> /root/enosARM.log
   ok_nok   # function call

   chown root:users /server /serverbkup 2>> /root/enosARM.log
   chmod 774 /server /serverbkup  2>> /root/enosARM.log
   printf "\033c"; printf "\n"
   printf "${CYAN}Data storage device summary:${NC}\n\n"
   printf "\nAn external USB 3 device was partitioned, formatted, and /etc/fstab was configured.\n"
   printf "This device will be on mount point /server and will be mounted at bootup.\n"
   printf "The mount point /serverbkup was also created for use in backing up the DATA device.\n"     
fi
printf "\n\nPress Enter to continue\n"
read -n 1 z
}  # end of function installssd


function devicemodel() {
case $devicemodel in
   "Raspberry Pi") printf "dtparam=audio=on\n" >> /boot/config.txt
                   printf "# hdmi_group=1\n# hdmi-mode=4\n" >> /boot/config.txt
                   printf "disable_overscan=1\n" >> /boot/config.txt
                   printf "[pi4]\n#Enable DRM VC4 V3D driver on top of the dispmanx display\n" >> /boot/config.txt
                   printf "dtoverlay=vc4-kms-v3d\n# over_voltage=5\n# arm_freq=2000\n# gpu_freq=750\n" >> /boot/config.txt
                   printf "max_framebuffers=2\ngpu-mem=320\n" >> /boot/config.txt
                   cp /boot/config.txt /boot/config.txt.bkup
                   pacman -S --noconfirm wireless-regdb crda
                   sed -i 's/#WIRELESS_REGDOM="US"/WIRELESS_REGDOM="US"/g' /etc/conf.d/wireless-regdom ;;
   "ODROID-N2")    cp /root/install-script/n2-boot.ini /boot/boot.ini
                   lsblk -f | grep sda >/dev/null
                   if [ $? =0 ]
                   then
                      sed -i 's/root=\/dev\/mmcblk${devno}p2/root=\/dev\/sda2/g' /boot/boot.ini      
                   fi
                   pacman -Rdd --noconfirm linux-odroid-n2
                   pacman -S --noconfirm linux-odroid linux-odroid-headers odroid-alsa ;;         
   "Odroid XU4")   pacman -S --noconfirm odroid-xu3-libgl-headers odroid-xu3-libgl-x11 xf86-video-armsoc-odroid xf86-video-fbturbo-git ;;
esac
}   # end of function devicemodel


function xfce4() {
   printf "\n${CYAN}Installing XFCE4 ...${NC}\n"
   message="\nInstalling XFCE4  "
   targetgroup="name: \"XFCE4-Desktop\""
   windowmanager="false"
   create-pkg-list
   pacman -S --noconfirm --needed - < pkg-list
   ok_nok  # function call
   cp lightdm-gtk-greeter.conf.default   /etc/lightdm/
   cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
   systemctl enable lightdm.service
}   # end of function xfce4

function mate() {
   printf "\n${CYAN}Installing Mate...${NC}\n"
   message="\nInstalling Mate  "
   targetgroup="name: \"MATE-Desktop\""
   windowmanager="false"
   create-pkg-list
   pacman -S --noconfirm --needed - < pkg-list
   ok_nok  # function call
   cp lightdm-gtk-greeter.conf.default   /etc/lightdm/
   cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
   systemctl enable lightdm.service
}   # end of function mate

function kde() {
   printf "\n${CYAN}Installing KDE Plasma...${NC}\n"
   message="\nInstalling KDE Plasma  "
   targetgroup="name: \"KDE-Desktop\""
   windowmanager="false"
   create-pkg-list
   pacman -S --noconfirm --needed - < pkg-list
   pacman -Rs --noconfirm discover
   ok_nok  # function call
#   cp lightdm-gtk-greeter.conf.default   /etc/lightdm/
#   cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
#   systemctl enable lightdm.service
   systemctl enable sddm.service
}   # end of function kde

function gnome() {
   printf "\n${CYAN}Installing Gnome...${NC}\n"
   gittarget="endeavouros-team/"$targetde".git"
   targetgroup="name: \"GNOME-Desktop\""
   windowmanager="false"
   create-pkg-list
   pacman -S --noconfirm --needed - < pkg-list
   ok_nok  # function call
   cp lightdm-gtk-greeter.conf.default   /etc/lightdm/
   cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
#   systemctl enable lightdm.service  
   systemctl enable gdm.service
}   # end of function gnome

function cinnamon() {
  printf "\n${CYAN}Installing Cinnamon...${NC}\n"
  message="\nInstalling Cinnamon  "
  targetgroup="name: \"Cinnamon-Desktop\""
  windowmanager="false"
  create-pkg-list
  pacman -S --noconfirm --needed - < pkg-list
  ok_nok  # function call
  cp lightdm-gtk-greeter.conf.default   /etc/lightdm/
  cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
  systemctl enable lightdm.service
}   # end of function cinnamon

function budgie() {
  printf "\n${CYAN}Installing Budgie-Desktop...${NC}\n"
  message="\nInstalling Budgie-Desktop"
  targetgroup="name: \"Budgie-Desktop\""
  windowmanager="false"
  create-pkg-list
  pacman -S --noconfirm --needed - < pkg-list
  ok_nok  # function call
  cp lightdm-gtk-greeter.conf.default   /etc/lightdm/
  cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
  systemctl enable lightdm.service
}  # end of function budgie

function lxqt() {
   printf "\n${CYAN}Installing LXQT...${NC}\n"
   message="\nInstalling LXQT  "
   targetgroup="name: \"LXQT-Desktop\""
   windowmanager="false"
   create-pkg-list
   pacman -S --noconfirm --needed - < pkg-list
   ok_nok  # function call
#   cp lightdm-gtk-greeter.conf.default   /etc/lightdm/
#   cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
#   systemctl enable lightdm.service
   systemctl enable sddm.service
}   # end of function lxqt

function i3wm() {
   printf "\n${CYAN}Installing i3-wm ...${NC}\n"
   message="\nInstalling i3-wm  "
   targetde="endeavouros-i3wm-setup"
   gittarget="endeavouros-team/"$targetde".git"
   targetgroup="name: \"i3 Window Manager\""
   windowmanager="true"
   cd /home/$username
   create-pkg-list
   pacman -S --noconfirm --needed - < pkg-list
   ok_nok  # function call
   # configure i3wm
   su $username -c "mkdir /home/$username/.config"
   su $username -c "git clone https://github.com/endeavouros-team/endeavouros-i3wm-setup.git"
   cd endeavouros-i3wm-setup
   su $username -c "cp -R .config/* /home/$username/.config/"
   su $username -c "cp .gtkrc-2.0 .nanorc /home/$username/"
   su $username -c "chmod -R +x /home/$username/.config/i3/scripts"
   dbus-launch dconf load / < xed.dconf
   cd /root/install-script
   su $username -c "rm -rf /home/$username/endeavouros-i3wm-setup"
   cp lightdm-gtk-greeter.conf.default   /etc/lightdm/
   cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
   systemctl enable lightdm.service
}   # end of function i3wm

function sway() {
   printf "\n${CYAN}Installing Sway WM ...${NC}\n"
   message="\nInstalling Sway WM  "
   targetde="sway"
   gittarget="EndeavourOS-Community-Editions/"$targetde".git"
   targetgroup="name: \"sway tiling on wayland\""
   windowmanager="true"
   cd /home/$username
   create-pkg-list
   pacman -S --noconfirm --needed - < pkg-list
   ok_nok  # function call
   # configure Sway
   su $username -c "mkdir /home/$username/.config"
   su $username -c "cp -R .config/* /home/$username/.config/"
   su $username -c "cp -R .profile /home/$username/.profile"
   su $username -c "cp .gtkrc-2.0 /home/$username/"
   su $username -c "chmod -R +x /home/$username/.config/sway/scripts"
   su $username -c "chmod -R +x /home/$username/.config/waybar/scripts"
   su $username -c "chmod +x /home/$username/.config/wofi/windows.py"
   cd /root/install-script
   su $username -c "rm -rf /home/$username/sway"
   cp lightdm-gtk-greeter.conf.default   /etc/lightdm/
   cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
   systemctl enable lightdm.service
   cp sway.png /usr/share/endeavouros/backgrounds/
   cp sway.png /home/$username/.config/sway/sway.png
}  # end of function sway


function bspwm() {
   printf "\n${CYAN}Installing BSPWM ...${NC}\n"
   message="\nInstalling BSPWM  "
   targetde="bspwm"
   gittarget="EndeavourOS-Community-Editions/"$targetde".git"
   targetgroup="name: \"bspwm\""
   windowmanager="true"
   cd /home/$username
   create-pkg-list
   pacman -S --noconfirm --needed - < pkg-list
   ok_nok  # function call
   # configure BSPWM
   su $username -c "mkdir /home/$username/.config"
   su $username -c "mkdir /home/$username/.local"
   su $username -c "mkdir /home/$username/.local/share"
   su $username -c "mkdir /home/$username/.local/share/fonts"
   su $username -c "cp -R IosevkaTermNerdFontComplete.ttf  /home/$username/.local/share/fonts"
   su $username -c "cp -R .config/* /home/$username/.config/"
   su $username -c "cp .gtkrc-2.0 /home/$username/"
   su $username -c "chmod -R +x /home/$username/.config/bspwm/"
   su $username -c "chmod -R +x /home/$username/.config/sxhkd/"
   su $username -c "chmod -R +x /home/$username/.config/polybar/scripts  "
   fc-cache -f -v
   cd /root/install-script
   su $username -c "rm -rf /home/$username/bspwm"
   cp lightdm-gtk-greeter.conf.default   /etc/lightdm/
   cp /etc/lightdm/lightdm-gtk-greeter.conf.default /etc/lightdm/lightdm-gtk-greeter.conf
   systemctl enable lightdm.service
 }  # end of function bspwm

####################################

#################################################
# beginning of script
#################################################


# Declare following global variables
# uefibootstatus=20
arch="e"
returnanswer="a"
prompt="b"
message="c"
verify="d"
# osdevicename="e"
# sshport=3
username="a"

# Declare color variables
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color


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

##### check to see if script was run as root #####


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


dmesg -n 1 # prevent low level kernel messages from appearing during the script
# create empty /root/enosARM.log
printf "    LOGFILE\n\n" > /root/enosARM.log


armarch="$(uname -m)"
case "$armarch" in
        armv7*) armarch=armv7h ;;
esac

pacman -S --noconfirm --needed git libnewt wget # for whiplash dialog & findmirror + keyring


################   Begin user input  #######################

installtype=$(whiptail --title "EndeavourOS ARM Setup"  --menu "\n          Choose type of install or\n      Press right arrow twice to cancel" 12 50 2 "1" "Desktop Environment" "2" "Headless server Environment" 3>&2 2>&1 1>&3)


if [[ "$installtype" = "" ]]
then
   printf "\n\nScript aborted by user..${NC}\n\n" && exit
else
   case $installtype in
      1) installtype="desktop" ;;
      2) installtype="server" ;;
   esac
fi

if [ "$installtype" == "desktop" ]
then
    whiptail --title "EndeavourOS ARM Setup" --msgbox "A Desktop Operating System with your choice of DE will be installed" 8 75
    status_checker $?
else
    whiptail --title "EndeavourOS ARM Setup" --msgbox "A headless server environment will be installed" 8 52
    status_checker $?
fi

userinputdone=1
while [ $userinputdone -ne 0 ]
do 
   printf "\033c"; printf "\n"

   generate_timezone_list $ZONE_DIR
   timezone=$(whiptail --nocancel --title "EndeavourOS ARM Setup - Timezone Selection" --menu \
   "Please choose your timezone.\n\nNote: You can navigate to different sections with Page Up/Down or the A-Z keys." 18 90 8 --cancel-button 'Back' "${timezone_list[@]}" 3>&2 2>&1 1>&3)
   timezonepath="${ZONE_DIR}${timezone}"
    
   ############### end of time zone entry ##################################

   finished=1
   description="Enter your desired hostname"
   while [ $finished -ne 0 ]
   do
	host_name=$(whiptail --nocancel --title "EndeavourOS ARM Setup - Configuration" --inputbox "$description" 8 60 3>&2 2>&1 1>&3)
      if [ "$host_name" == "" ] 
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
	fullname=$(whiptail --nocancel --title "EndeavourOS ARM Setup - User Setup" --inputbox "$description" 8 60 3>&2 2>&1 1>&3)

      if [ "$fullname" == "" ]
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
	username=$(whiptail --nocancel --title "EndeavourOS ARM Setup - User Setup" --inputbox "$description" 8 60 3>&2 2>&1 1>&3)

      if [ "$username" == "" ]
      then
         description="Entry is blank. Enter your desired username"
      else     
         finished=0
      fi
   done

   finished=1
   initial_user_password=""

   description="Enter your desired password for ${username}:"
   while [ $finished -ne 0 ]
   do 
	user_password=$(whiptail --nocancel --title "EndeavourOS ARM Setup - User Setup" --passwordbox "$description" 8 60 3>&2 2>&1 1>&3)

      if [ "$user_password" == "" ]; then
         description="Entry is blank. Enter your desired password"
         initial_user_password=""
      elif [[ "$initial_user_password" == "" ]]; then 
            initial_user_password="$user_password"
            description="Confirm password:"
      elif [[ "$initial_user_password" != "$user_password" ]]; then
        description="Passwords do not match.\nEnter your desired password for ${username}:"
        initial_user_password=""
      elif [[ "$initial_user_password" == "$user_password" ]]; then     
         finished=0
      fi
   done

   finished=1
   initial_root_user_password=""

   description="Enter your desired password for the root user:"
   while [ $finished -ne 0 ]
   do 
	root_user_password=$(whiptail --nocancel --title "EndeavourOS ARM Setup - Root User Setup" --passwordbox "$description" 8 60 3>&2 2>&1 1>&3)

      if [ "$root_user_password" == "" ]; then
         description="Entry is blank. Enter your desired password"
         initial_root_user_password=""
      elif [[ "$initial_root_user_password" == "" ]]; then 
            initial_root_user_password="$root_user_password"
            description="Confirm password:"
      elif [[ "$initial_root_user_password" != "$root_user_password" ]]; then
        description="Passwords do not match.\nEnter your desired password for the root user:"
        initial_root_user_password=""
      elif [[ "$initial_root_user_password" == "$root_user_password" ]]; then     
         finished=0
      fi
   done

#################################################################################################

   if [ "$installtype" == "desktop" ]
   then
   dename=$(whiptail --nocancel --title "EndeavourOS ARM Setup - Desktop Selection" --menu --notags "Choose which Desktop Environment to install" 17 100 11 \
            "0" "No Desktop Environment" \
            "1" "XFCE4" \
            "2" "Mate" \
            "3" "KDE Plasma" \
            "4" "Gnome" \
            "5" "Cinnamon" \
            "6" "Budgie-Desktop" \
            "7" "LXQT" \
            "8" "i3 wm    for x11" \
            "9" "Sway wm  for wayland" \
            "10" "BSPWM" \
          3>&2 2>&1 1>&3)

      case $dename in
         0) dename="none" ;;
         1) dename="xfce4" ;;
         2) dename="mate" ;;
         3) dename="kde" ;;
         4) dename="gnome" ;;
         5) dename="cinnamon" ;;
         6) dename="budgie" ;;
         7) dename="lxqt" ;;
         8) dename="i3wm" ;;
         9) dename="sway" ;;
        10) dename="bspwm" ;;
      esac
   fi

############################################################
   
   if [ "$installtype" == "server" ]
   then
     finished=1
     description="Enter the desired SSH port between 8000 and 48000"
     while [ $finished -ne 0 ]
     do
      	sshport=$(whiptail --nocancel  --title "EndeavourOS ARM Setup - Server Configuration"  --inputbox "$description" 10 60 3>&2 2>&1 1>&3)

        if [ "$sshport" -eq "$sshport" ] # 2>/dev/null
        then
             if [ $sshport -lt 8000 ] || [ $sshport -gt 48000 ]
             then
                description="Your choice is out of range, try again.\n\nEnter the desired SSH port between 8000 and 48000"
             else
                finished=0
             fi
        else
          description="Your choice is not a number, try again.\n\nEnter the desired SSH port between 8000 and 48000"
        fi
     done

   ethernetdevice=$(ip r | awk 'NR==1{print $5}')
   routerip=$(ip r | awk 'NR==1{print $3}')
   threetriads=$routerip
   xyz=${threetriads#*.*.*.}
   threetriads=${threetriads%$xyz}
   title="SETTING UP THE STATIC IP ADDRESS FOR THE SERVER"
   finished=1
   description="For the best router compatibility, the last octet should be between 150 and 250\n\nEnter the last octet of the desired static IP address $threetriads"
     while [ $finished -ne 0 ]
     do
      lasttriad=$(whiptail --nocancel --title "EndeavourOS ARM Setup - Server Configuration"  --title "$title" --inputbox "$description" 12 100 3>&2 2>&1 1>&3)
       if [ "$lasttriad" -eq "$lasttriad" ] # 2>/dev/null
       then
          if [ $lasttriad -lt 150 ] || [ $lasttriad -gt 250 ]
          then
             description="For the best router compatibility, the last octet should be between 150 and 250\n\nEnter the last octet of the desired static IP address $threetriads\n\nYour choice is out of range. Please try again\n"
          else         
            finished=0
          fi
       else
	   	  description="For the best router compatibility, the last octet should be between 150 and 250\n\nEnter the last octet of the desired static IP address $threetriads\n\nYour choice is not a number.  Please try again\n"
       fi
     done

     staticip=$threetriads$lasttriad
     staticipbroadcast=$staticip"/24"
   fi  # boss fi
   
#######################################################   
   

   if [ "$installtype" == "desktop" ]
   then
      whiptail  --title "EndeavourOS ARM Setup - Review Settings"  --yesno "To review, you entered the following information:\n\n \
      Time Zone: $timezone \n \
      Host Name: $host_name \n \
      Full Name: $fullname \n \
      User Name: $username \n \
      Desktop Environment: $dename \n\n \
      Is this information correct?" 16 80
      userinputdone="$?"
   fi
   if [ "$installtype" == "server" ]
   then
      whiptail --title "EndeavourOS ARM Setup - Review Settings" --yesno "To review, you entered the following information:\n\n \
      Time Zone: $timezone \n \
      Host Name: $host_name \n \
      Full Name: $fullname \n \
      User Name: $username \n \
      SSH Port: $sshport \n \
      Static IP: $staticip \n\n \
      Is this information correct?" 16 80
      userinputdone="$?"
   fi

done

###################   end user input  ######################


devicemodel=$(dmesg | grep "Machine model" | sed -e '/Raspberry Pi/ c Raspberry Pi' -e '/ODROID-N2/ c ODROID-N2' -e '/Odroid XU4/ c Odroid XU4')

findmirrorlist   # find and install EndeavourOS mirrorlist
findkeyring      # find and install EndeavourOS keyring
pacman -Syy

### the following installs all packages needed to match the EndeavourOS base install
printf "\n${CYAN}Installing EndeavourOS Base Addons...${NC}\n"
message="\nInstalling EndeavourOS Base Addons  "
sleep 2
if [ "$installtype" == "desktop" ]
then
   create-base-addons
   pacman -S --noconfirm --needed - < base-addons
   systemctl disable dhcpcd.service
   systemctl enable NetworkManager.service
   systemctl start NetworkManager.service     
   sleep 5
else
   pacman -S --noconfirm --needed - < server-addons
fi
ok_nok   # function call


printf "\n${CYAN}Setting Time Zone...${NC}\n"
message="\nSetting Time Zone  "
ln -sf $timezonepath /etc/localtime 2>> /root/enosARM.log
ok_nok  # function call


printf "\n${CYAN}Enabling NTP...${NC}"
message="\nEnabling NTP   "
timedatectl set-ntp true &>> /root/enosARM.log
timedatectl timesync-status &>> /root/enosARM.log
ok_nok		# function call
sleep 1


printf "\n${CYAN}Syncing Hardware Clock${NC}\n\n"
hwclock -r
if [ $? == "0" ]
then
  hwclock --systohc 2>> /root/enosARM.log
  printf "\n${CYAN}hardware clock was synced${NC}\n"
else
  printf "\n${RED}No hardware clock was found${NC}\n"
fi


printf "\n${CYAN}Setting Locale...${NC}\n"
message="\nSetting locale "
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen 2>> /root/enosARM.log
printf "\nLANG=en_US.UTF-8\n\n" > /etc/locale.conf 
ok_nok   # function call


printf "\n${CYAN}Setting hostname...${NC}"
message="\nSetting hostname "
printf "\n$host_name\n\n" > /etc/hostname
ok_nok   # function call


printf "\n${CYAN}Configuring /etc/hosts...${NC}"
message="\nConfiguring /etc/hosts "
printf "\n127.0.0.1\tlocalhost\n" > /etc/hosts
printf "::1\t\tlocalhost\n" >> /etc/hosts
printf "127.0.1.1\t$host_name.localdomain\t$host_name\n\n" >> /etc/hosts
ok_nok  # function call


printf "\n${CYAN}Running mkinitcpio...${NC}\n"
mkinitcpio -P  2>> /root/enosARM.log


printf "\n${CYAN} Updating root user password...\n\n"
echo "root:${root_user_password}" | chpasswd



printf "\n${CYAN}Delete default username (alarm) and Creating a user...${NC}"
message="Delete default username (alarm) and Creating new user "
userdel -r alarm     #delete the default user from the image
if [ "$installtype" == "desktop" ]
then
   useradd -c "$fullname" -m -G users -s /bin/bash -u 1000 "$username" 2>> /root/enosARM.log
else
   useradd -m -G users -s /bin/bash -u 1000 "$username" 2>> /root/enosARM.log
fi
printf "\n${CYAN} Updating user password...\n\n"
echo "${username}:${user_password}" | chpasswd


if [ "$installtype" == "desktop" ]
then
   printf "\n${CYAN}Adding user $username to sudo wheel...${NC}"
   message="Adding user $username to sudo wheel "
   printf "$username  ALL=(ALL:ALL) ALL" >> /etc/sudoers
   gpasswd -a $username wheel    # add user to group wheel
fi


printf "\n${CYAN}Creating ll alias...${NC}"
message="\nCreating ll alias "
printf "\nalias ll='ls -l --color=auto'\n" >> /etc/bash.bashrc
printf "alias la='ls -al --color=auto'\n" >> /etc/bash.bashrc
printf "alias lb='lsblk -o NAME,FSTYPE,FSSIZE,LABEL,MOUNTPOINT'\n\n" >> /etc/bash.bashrc
ok_nok  # function call

##################### desktop setup #############################

pacman -Syy

if [ "$installtype" == "desktop" ]
then
   mkdir -p /usr/share/endeavouros/backgrounds
   cp lightdmbackground.png /usr/share/endeavouros/backgrounds
   if [ $dename != "none" ]     
   then
      $dename      # run appropriate function for installing Desktop Environment
      pacman -S --noconfirm --needed welcome yay endeavouros-theming eos-hooks
      pacman -S --noconfirm --needed pahis inxi  eos-log-tool eos-update-notifier downgrade
      if [ $dename == "sway" ]
      then
         cp /usr/share/applications/welcome.desktop /etc/xdg/autostart/
      fi
   fi
   devicemodel  # Perform device specific chores   
fi

########################### end of desktop setup ##############################

################## server setup ####################

if [ "$installtype" = "server" ]
then
   pacman -S --noconfirm --needed pahis inxi downgrade yay
   # create /etc/netctl/ethernet-static file with user supplied static IP
   printf "\n${CYAN}Creating configuration file for static IP address...${NC}"
   message="\nCreating configuration file for static IP address "
   
   if [[ ${ethernetdevice:0:3} == "eth" ]]
   then
      rm /etc/systemd/network/eth*
   fi
   
   if [[ ${ethernetdevice:0:3} == "enp" ]]
   then
      rm /etc/systemd/network/enp*
   fi
   ethernetconf="/etc/systemd/network/$ethernetdevice.network"
   printf "[Match]\n" > $ethernetconf
   printf "Name=$ethernetdevice\n\n" >> $ethernetconf
   printf "[Network]\n" >> $ethernetconf
   printf "Address=$staticipbroadcast\n" >> $ethernetconf
   printf "Gateway=$routerip\n" >> $ethernetconf
   printf "DNS=$routerip\n" >> $ethernetconf
   printf "DNS=8.8.8.8\n" >> $ethernetconf
   printf "DNSSEC=no\n" >> $ethernetconf
   
   printf "\n${CYAN}Configure SSH...${NC}"
   message="\nConfigure SSH "
   sed -i "/Port 22/c Port $sshport" /etc/ssh/sshd_config
   sed -i '/PermitRootLogin/c PermitRootLogin no' /etc/ssh/sshd_config
   sed -i '/PasswordAuthentication/c PasswordAuthentication yes' /etc/ssh/sshd_config
   sed -i '/PermitEmptyPasswords/c PermitEmptyPasswords no' /etc/ssh/sshd_config
   systemctl disable sshd.service 2>> /root/enosARM.log
   systemctl enable sshd.service 2>>/dev/null
   ok_nok    # function call


   printf "\n${CYAN}Enable ufw firewall...${NC}\n"
   message="\nEnable ufw firewall "
   ufw logging off 2>/dev/null
   ufw default deny 2>/dev/null
   ufwaddr=$threetriads
   ufwaddr+="0/24" 
   ufw allow from $ufwaddr to any port $sshport
   ufw enable 2>/dev/null
   systemctl enable ufw.service 2>/dev/null 
   ok_nok  # function call
   
   mkdir -p /etc/samba
   cp smb.conf /etc/samba/
   
   whiptail  --title "EndeavourOS ARM Setup - SSD Configuration"  --yesno "Do you want to partition and format a USB 3 DATA SSD and auto mount it at bootup?" 8 86
   user_confirmation="$?"

   if [[ $user_confirmation == "0" ]]; then
      installssd
   fi
   
fi # boss fi

##################### end of server setup ############################

dhcpcd_installed=$(pacman -Qs dhcpcd)
if [[ "$dhcpcd_installed" != "" ]]; then 
   pacman -Rn --noconfirm dhcpcd
fi

# rebranding to EndeavourOS
sed -i 's/Arch/EndeavourOS/' /etc/issue
sed -i 's/Arch/EndeavourOS/' /etc/arch-release



printf "\n\n${CYAN}Installation is complete!${NC}\n\n"
if [ "$installtype" == "desktop" ]
then
   printf "\nRemember to use your new root password when logging in as root\n"
   printf "\nRemember to use your new user name and password when logging into Lightdm\n"
   printf "\nNo firewall was installed. Consider installing a firewall with eos-Welcome\n\n"
else
   printf "\nRemember your new user name and password when remotely logging into the server\n"
   printf "\nSSH server was installed and enabled to listen on port $sshport\n"
   printf "\nufw was installed and enabled with \"logging off\", the default \"deny\", and the following rule"
   printf "\nufw allow from $ufwaddr to any port $sshport\n"
   printf "\nWhich will only allow access to the server from your local LAN on the specified port\n\n"
fi

printf "Pressing Ctrl c will exit the script and give a CLI prompt\n"
printf "to allow the user to use pacman to add additional packages\n"
printf "or change configs. This will not remove install files from /root\n\n"
printf "Press any key exits the script, removes all install files, and reboots the computer.\n\n"

read -n1 x
rm -rf /root/install-script
systemctl reboot

exit  # end of script

