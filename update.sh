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

echo "==== atom connection check update: start system timer: $bsystemd_timer"

cp atom_restart.sh /usr/local/bin
cp atom_connection.service /etc/systemd/system

# copy systemd timer file if boolean is true
systemd_timer_file="/etc/systemd/system/atom_connection.timer"

if [ $bsystemd_timer == "false" ] ; then
    if [ -e "$systemd_timer_file" ] ; then
        service="atom_connection.timer"

        systemctl stop $service
        if [ "$?" -ne 0 ] ; then
            echo "Problem STOPPING $service"
        fi

        systemctl disable $service
        if [ "$?" -ne 0 ] ; then
            echo "Problem DISABLING $service"
        fi
        mv $systemd_timer_file /tmp
    fi
else
    cp atom_connection.timer /etc/systemd/system
fi

# All files copied, restart everything

systemctl daemon-reload
echo "Restarting atom_connection.timer"
systemctl restart atom_connection.service

# restart timer if boolean is true
if [ $bsystemd_timer != "false" ] ; then
    service="atom_connection.timer"
else
    service="atom_connection.service"
fi

echo "Restarting $service"
systemctl restart $service
if [ "$?" -ne 0 ] ; then
    echo "Problem RESTARTING $service"
fi

echo
echo "=== status after update"
echo
systemctl --no-pager status "atom_connection.*"

echo
ps aux | grep -i "atom_connection*"

