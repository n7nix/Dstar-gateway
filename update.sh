#!/bin/bash
#
# update.sh
#
# Copy all required programs to proper directories
#
# Set bsystemd_timer="true" for systemd timer operation
#   Note this fills syslog with 2 lines per run
#
# If bsystemd_timer is set to false then need to run from cron or in a
# tight loop.
#
bsystemd_timer="false"

# Be sure we're running as root
if [[ $EUID != 0 ]] ; then
   echo "Must be root."
   exit 1
fi

cp atom_restart.sh /usr/local/bin
cp atom_connection.service /etc/systemd/system

# copy systemd timer file if boolean is true
systemd_timer_file="/etc/systemd/system/atom_connection.timer"

if [ $bsystemd_timer == "false" ] ; then
    if [ -e "$sytemd_timer_file" ] ; then
        mv $systemd_timer_file /tmp
    fi
else
    cp atom_connection.timer /etc/systemd/system
fi

# All files copied, restart everything

systemctl daemon-reload
systemctl restart atom_connection.service

# restart timer if boolean is true
if [ $bsystemd_timer != "false" ] ; then
    systemctl restart atom_connection.timer
fi

echo
echo "=== status after update"
echo
systemctl --no-pager status "atom_connection.*"
