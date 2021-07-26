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

# ===== function ping_test

function ping_test() {
    /usr/bin/ping -I $WG_IF -c 1 -W 1 -q 192.168.99.1 > /dev/null
    return $?
}

# ===== function wg_test
# Failure criteria is if "latest handshake" string contains hour, hours
# or just minutes, seconds and minutes is > 2
# Returns 0 on success, 1 on failure

function wg_test() {
    # Set successful return code
    retcode=0
    handshake_str=$($WG show $WG_IF | grep "latest handshake")
#    $WG show wg0 | grep "latest handshake" | cut -f2 -d":" | cut -f1 -d"," | sed 's/^[ \t]*//'
    handshake_time=$(echo "$handshake_str" | cut -f2 -d":" | sed 's/^[ \t]*//')
    failure_tst=$(echo "$handshake_time"| cut -f2 -d' ')

    dbgecho "handshake: $handshake_str"
    dbgecho "handshake time: $handshake_time"
    dbgecho "failure test: $failure_tst"

    if [ "$failure_tst" = "minutes," ] ; then
        minutes_str=$(echo "$handshake_time"| cut -f1 -d' ')
	if (( $minutes_str > 2 )) ; then
            echo "$(date): Found FAILURE case on minutes: $minutes_str" | tee -a $local_log_file
            echo "$(date): FAILURE on string: $handshake_str, handshake_time: $handshake_time" | tee -a $local_log_file
	    retcode=1
	else
            dbgecho "$(date): Found OK case on minutes: $minutes_str" | tee -a $local_log_file
            dbgecho "$(date): OK string: $handshake_str, handshake_time: $handshake_time" | tee -a $local_log_file
	fi
    fi

    if [ "$failure_tst" = "hour," ] || [ "$failure_tst" = "hours," ] ; then
        echo "$(date): Found FAILURE case: $failure_tst" | tee -a $local_log_file
	echo "$(date): FAILURE on string: $handshake_str, handshake_time: $handshake_time" | tee -a $local_log_file
        retcode=1
    fi

    return $retcode
}

# ===== function criteria_test
# Return accumulated result of all tests
# Returns 0 on success

function criteria_test() {

    wg_test
    wg_test_ret=$?

    ping_test
    ping_test_ret=$?

    return $(( ping_test_ret + wg_test_ret ))
}

# ===== function if_dn_up
# Take the Ethernet connection down then back up

function if_dn_up() {
    if [ -z "$DEBUG" ] ; then
        $IP link set $ETH_IF down
        sleep 10
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

# Get pid of parent process
PPPID=$(ps h -o ppid= $PPID)
# get name of parent process
P_COMMAND=$(ps h -o %c $PPPID)

# Check if local log directory exists.
# Use this for debugging
if [ ! -d "$local_log_dir" ] ; then
   mkdir -p $local_log_dir
fi

{
echo
echo "$(date): Start from parent: $P_COMMAND"
echo
} | tee -a $local_log_file

if [ -e "/tmp/atom_restart*" ] ; then
    echo "Found atom restart tmp file: $(ls /tmp/atom_restart*)"
    # debug only, remove
#    rm /tmp/atom_restart*
fi

# Make a temporary file with current time stamp
tmpfile=$(mktemp /tmp/atom_restart.XXXXXX)
echo "Called from $P_COMMAND at $(date)" >> $tmpfile

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

# Temporary DEBUG
while true ; do

    criteria_test
    criteria_test_ret=$?
    if [ $criteria_test_ret != 0 ] ; then
        logmsg "VPN connection dropped"

        if_dn_up
        dashb_restart
	sleep 10

	/usr/bin/wg-quick up "${WG_IF}"
	sleep 5

        criteria_test
        criteria_test_ret=$?
        if [ $criteria_test_ret == 0 ] ; then
            logmsg "VPN connection after connection reset: UP"
	    # Get rid of semaphore file
            rm /tmp/atom_restart*
        else
            logmsg "VPN connection after connection reset: FAILED"
	fi
	break
    fi
    sleep 10

done

logmsg "VPN connection has been reset, check logs"

exit 0
