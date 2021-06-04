#!/bin/bash

scriptname="`basename $0`"
UDR_INSTALL_LOGFILE="/var/log/udr_install.log"
PKGLIST="iptables iptables-persistent"

USER=
BIN_FILES="iptable-check.sh iptable-flush.sh iptable-up.sh"
rules_file="/etc/iptables/rules.ipv4.vpn"
hook_file="/lib/dhcpcd/dhcpcd-hooks/70-ipv4.vpn"

function dbgecho { if [ ! -z "$DEBUG" ] ; then echo "$*"; fi }

# ===== function is_pkg_installed

function is_pkg_installed() {

return $(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed" >/dev/null 2>&1)
}

# ===== function is_ifaceup
function is_ifaceup() {
    interface=$1
    ip a show $interface up > /dev/null  2>&1
}

# ===== get_rule_count
# sets variable rule_count

function get_rule_count() {
    rule_count=$(grep -c "\-A FORWARD\|\-A .*ROUTING" $rules_file)
}

# ===== write iptables rules

function write_rules() {
    if [ "$CREATE_IPTABLES" = "true" ] ; then

        sudo /bin/bash $BIN_DIR/iptable-flush.sh

        # Setup some iptable rules
        echo
        echo "== setup iptables"
        sudo /bin/bash $BIN_DIR/iptable-up.sh
        sudo sh -c "iptables-save > $rules_file"

            echo "Setup restore command"
            sudo tee $hook_file > /dev/null <<EOF
iptables-restore < $rules_file
EOF
	get_rule_count
        echo "Number of VPN rules now: $rule_count"
    fi
}

# ===== function get_user

function get_user() {
   # Check if there is only a single user on this system
   if (( `ls /home | wc -l` == 1 )) ; then
      USER=$(ls /home)
   else
      echo "Enter user name ($(echo $USERLIST | tr '\n' ' ')), followed by [enter]:"
      read -e USER
   fi
}

# ==== function check_user
# verify user name is legit

function check_user() {
   userok=false
   dbgecho "$scriptname: Verify user name: $USER"
   for username in $USERLIST ; do
      if [ "$USER" = "$username" ] ; then
         userok=true;
      fi
   done

   if [ "$userok" = "false" ] ; then
      echo "User name ($USER) does not exist,  must be one of: $USERLIST"
      exit 1
   fi
   dbgecho "using USER: $USER"
}

#
# ===== main
#

echo "setup iptables"

# Get list of users with home directories
USERLIST="$(ls /home)"
USERLIST="$(echo $USERLIST | tr '\n' ' ')"

USER="pi"

if [ -z "$USER" ] ; then
   echo "USER string is null, get_user"
   get_user
else
   echo "USER=$USER not null"
fi

check_user
BIN_DIR="/home/$USER/bin"

for filename in `echo ${BIN_FILES}` ; do
   cp $filename $BIN_DIR
done

# check if packages are installed
dbgecho "Check packages: $PKGLIST"

# Note: This should be in core_install.sh
#
# These rules block Bonjour/Multicast DNS (mDNS) addresses from iTunes
# or Avahi daemon.  Avahi is ZeroConf/Bonjour compatible and installed
# by default.
#
# Setup iptables then install iptables-persistent or manually update
# rules.v4

# Fix for iptables-persistent broken
#  https://discourse.osmc.tv/t/failed-to-start-load-kernel-modules/3163/14
#  https://www.raspberrypi.org/forums/viewtopic.php?f=63&t=174648

filename="/etc/modules-load.d/cups-filters.conf"
if [ -e "$filename" ] ; then
    sed -i -e 's/^#*/#/' $filename
fi

for pkg_name in `echo ${PKGLIST}` ; do

   is_pkg_installed $pkg_name
   if [ $? -ne 0 ] ; then
      echo "$scriptname: Will Install $pkg_name program"
      sudo apt-get -qy install $pkg_name
   fi
done

# use iptables-persistent
CREATE_IPTABLES=false
IPTABLES_FILES="$rules_file $hook_file"
for ipt_file in `echo ${IPTABLES_FILES}` ; do

   if [ -f $ipt_file ] ; then
      echo "iptables file: $ipt_file exists"
   else
      echo "Need to create iptables file: $ipt_file"
      CREATE_IPTABLES=true
   fi
done

echo " == Check to see if VPN devices are up"

is_ifaceup wg0
wg0_up="$?"
if [ "$wg0_up" -ne 0 ] ; then
    echo "$(date "+%Y %m %d %T %Z"): $scriptname: iptables installed but NOT configured, no VPN devices available" | sudo tee -a $UDR_INSTALL_LOGFILE
    exit 0
fi

write_rules

echo
echo "$(date "+%Y %m %d %T %Z"): $scriptname: iptables install/config script FINISHED" | sudo tee -a $UDR_INSTALL_LOGFILE
echo
