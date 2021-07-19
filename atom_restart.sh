#!/bin/bash
#
# atom_restart.sh
#
# Check if the VPN connection is still working and if not restart Eth
# interface & DStar dashboard.
DEBUG=

scriptname="`basename $0`"
VERSION="1.0"

WG_IF="wg0"
ETH_IF="enp4s0"

SYSTEMCTL="systemctl"
WG="wg"
IP="ip"
LOGGER="logger"


# ===== function logmsg

function logmsg() {
    "${LOGGER}" -t "${scriptname}(${VERSION})" -i -p daemon.info "${1}"
}

# ===== function ping_fail

function ping_fail() {
    ping -I $WG_IF -c 1 -W 1 -q 192.168.99.1 ; echo $?
}

# ===== function wg_fail

function wg_fail() {
    $WG show $WG_IF | grep "latest handshake"
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

if ping_fail || wg_fail ; then
    logmsg "VPN connection dropped"
    if_dn_up
    dashb_restart
else
    logmsg "VPN connection up"
fi
