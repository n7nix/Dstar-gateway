#!/bin/bash
#
# atom_restart.sh
#
# Check if the VPN connection is still working and if not restart Eth
# interface & DStar dashboard.
# DEBUG=1

scriptname="`basename $0`"
VERSION="1.0"
local_log_dir=$HOME/log/
local_log_file=$local_log_dir/logfile

WG_IF="wg0"
ETH_IF="enp4s0"

SYSTEMCTL="systemctl"
WG="wg"
IP="ip"
LOGGER="/usr/bin/logger"

function dbgecho { if [ ! -z "$DEBUG" ] ; then echo "$*"; fi }

# ===== function logmsg
# Put message in a local file as well as syslog

function logmsg() {
    "${LOGGER}" -t "${scriptname}(${VERSION})" -i -p daemon.info -s "${1}" >> $local_log_file 2>&1
}

# ===== function ping_fail

function ping_fail() {
    ping -I $WG_IF -c 1 -W 1 -q 192.168.99.1 ; echo $?
}

# ===== function wg_test

function wg_test() {
#    $WG show $WG_IF | grep "latest handshake"
#    $WG show wg0 | grep "latest handshake" | cut -f2 -d":" | cut -f1 -d"," | sed 's/^[ \t]*//'
    handshake_str=$($WG show wg0 | grep "latest handshake" | cut -f2 -d":" | sed 's/^[ \t]*//')
    failure_tst=$(cut -f2 -d' ' <<< "$handshake_str")

    dbgecho "handshake: $handshake_str"
    dbgecho "failure test: $failure_tst"

    if [ "$failure_tst" = "minutes," ] || [ "$failure_tst" = "minutes," ] ; then

        echo "Found FAILURE case: $failure_tst" | tee -a $local_log_file
	echo "FAILURE on string: $handshare_str" | tee -a $local_log_file

    else

        dbgecho "OK Test: $failure_tst" | tee -a $local_log_file
    fi

}

# ===== function if_dn_up
# Take the Ethernet connection down then back up

function if_dn_up() {
    if [ -z "$DEBUG" ] ; then
        $IP link set $ETH_IF down
        sleep 20
        $IP link set $ETH_IF up
    fi
    logmsg "Ethernet interface: $ETH_IF, down up"
}

# ===== function dashb_restart

function dashb_restart() {
    if [ -z "$DEBUG" ] ; then
        $SYSTEMCTL restart ircnodedashboard.service
    fi
    logmsg "Dashboard service restarted"
}

# ===== function usage

usage () {
	(
	echo "Usage: $scriptname [-d][-h]"
        echo "                  No args will restart dashboard & down/up Eth interface"
        echo "  -d              Set DEBUG flag"
        echo "  -h              Display this message."
        echo
	) 1>&2
	exit 1
}


# ===== main

# Check if running as root
if [[ $EUID != 0 ]] ; then
    SYSTEMCTL="sudo systemctl"
    WG="sudo wg"
    IP="sudo ip"
    LOGGER="sudo logger"
    echo "WARNING: if running from crontab need to run as root"
fi

if [ -e "/tmp/atom_restart*" ] ; then
    echo "Found atom restart tmp file: $(ls /tmp/atom_restart*)"
    # debug only, remove
    rm /tmp/atom_restart*
fi

# Make a temporary file with current time stamp
tmpfile=$(mktemp /tmp/atom_restart.XXXXXX)
echo "Called from rsyslog at $(date)" >> $tmpfile

# Check if local log directory exists.
# Use this for debugging
if [ ! -d "$local_log_dir" ] ; then
   mkdir -p $local_log_dir
fi

while true ; do
    wg_test
    sleep 2
done

exit


while [[ $# -gt 0 ]] ; do
    APP_ARG="$1"

    case $APP_ARG in
        -d|--debug)   # set DEBUG flag
             DEBUG=1
             echo "Set DEBUG flag"
        ;;
        -h|--help|-?)
            usage
            exit 0
        ;;
        *)
           echo "Unrecognized command line argument: $APP_ARG"
           usage
           exit 0
       ;;
    esac

shift # past argument
done

if ping_fail || wg_test ; then
    logmsg "VPN connection dropped"
    if_dn_up
    dashb_restart
else
    logmsg "VPN connection up"
fi

