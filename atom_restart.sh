#!/bin/bash
#
# atom_restart.sh
#
# Check if the VPN connection is still working and if not restart Eth
# interface & DStar dashboard.
# DEBUG=1

scriptname="`basename $0`"
VERSION="1.2"
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
# or just "minutes, seconds" and "minutes" is > 2
#  Return 0 on success, 1 on failure

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
        logmsg "Ethernet interface: $ETH_IF, set DOWN"
        sleep 15
        $IP link set $ETH_IF up
        logmsg "Ethernet interface: $ETH_IF, set UP"
    fi
    logmsg "Ethernet interface: $ETH_IF, down up complete"
}

# ===== function wait_for_link
# Wait for link state to transistion from DOWN to UP

function wait_for_link() {

    retcode=1
    link_state="$(ip link show $ETH_IF |  grep -oP '(?<=state )[^ ]*')"
    begin_sec=$SECONDS

    while [ $((SECONDS-begin_sec)) -lt 25 ] && [ "$link_state" != "UP" ]  ; do
        link_state="$(ip link show $ETH_IF |  grep -oP '(?<=state )[^ ]*')"
    done
    if [ "$link_state" = "UP" ] ; then
        retcode=0
    else
	logmsg "DEBUG: Link not UP after ((SECONDS-begin_sec)) seconds: $(ip link show $ETH_IF)"
    fi
    return $retcode
}

# ===== function dashb_restart

function dashb_restart() {
    # Testing whether just restarting ircddgbgatewayd service works
    sysd_service="ircnodedashboard.service"
    # sysd_service="ircddbgatewayd.service"
    if [ -z "$DEBUG" ] ; then
        # Preference would be to only restart ircddbgateway service and
        #  leave the dashboard alone.
        $SYSTEMCTL restart "$sysd_service"
    fi
    logmsg "$sysd_service restarted"
}

# ===== function wg_up
# Do a quick up on the wire guard interface

function wg_up() {

    wg_linkstat=$(ip link show $WG_IF up type wireguard)
    wg_linkstat_ret="$?"
    logmsg "DEBUG: wg_linkstat: $wg_linkstat, ret code: $wg_linkstat_ret"
    if [ $wg_linkstat_ret != 0 ] ; then
        /usr/bin/wg-quick up "${WG_IF}"
        logmsg "Wire Guard quick up"
    else
        logmsg "Wire Guard interface $WG_IF already UP"
    fi
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

while [[ $# -gt 0 ]] ; do
    APP_ARG="$1"

    case $APP_ARG in
        -d|--debug)   # set DEBUG flag
             DEBUG=1
             echo "Set DEBUG flag"
        ;;
	-v|--version)
	    # Display Version & exit
	    echo "${scriptname} ${VERSION}"
	    exit 0
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

# Check if running as root
if [[ $EUID != 0 ]] ; then
    SYSTEMCTL="sudo systemctl"
    WG="sudo wg"
    IP="sudo ip"
    LOGGER="sudo logger"
    echo "WARNING: if running from crontab need to run as root"
fi

# Get PID of parent process
PPPID=$(ps h -o ppid= $PPID)
# get name of parent process
P_COMMAND=$(ps h -o %c $PPPID)

# Check if local log directory exists.
# Use this for debugging
if [ ! -d "$local_log_dir" ] ; then
   mkdir -p $local_log_dir
fi

# Display name of parent process
{
echo
echo "$(date): Start from parent: $P_COMMAND"
echo
} | tee -a $local_log_file

# Check if a lock file exists and exit script if it does
if [ -e "/tmp/atom_restart*" ] ; then
    echo "Found atom restart lock file exiting: $(ls /tmp/atom_restart*)" | tee -a $local_log_file
    exit 0
fi

# Make a temporary file (lock file) with current time stamp
tmpfile=$(mktemp /tmp/atom_restart.XXXXXX)
echo "Called from $P_COMMAND at $(date)" >> $tmpfile

# Temporary DEBUG
# while true ; do

    criteria_test
    criteria_test_ret=$?
    if [ $criteria_test_ret != 0 ] ; then
        logmsg "VPN connection DROPPED"

        wg_up
	sleep 20

        if_dn_up
	sleep 5

	# Wait until link is back up
        wait_for_link
	if [ "$?" != 0 ] ; then
            logmsg "Timeout waiting for link on interface: $ETH_IF"
	fi

        dashb_restart
	sleep 5

        criteria_test
        criteria_test_ret=$?
        if [ $criteria_test_ret == 0 ] ; then
            logmsg "VPN connection after connection reset: UP"
	    # Get rid of any semaphore files
            rm /tmp/atom_restart*
            # Temporary DEBUG
            # break
        else
            logmsg "VPN connection after connection reset: FAILED"
            # Temporary DEBUG
	    # sleep 50
	fi
    else
        logmsg "VPN connection OK"
    fi

# Temporary DEBUG
#    sleep 10
# done

# remove lock file
rm /tmp/atom_restart*
# logmsg "VPN connection has been reset, check logs"

exit 0
