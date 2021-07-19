#!/bin/bash
#
# Send an email when ssh connection is lost
#
#  RPI: ssh $USER@$RPI_IP
#  ATOM: ssh -vv -p $ATOM_PORTNUM $USER@$ATOM_IP
#  TEST:
#
# Takes USER name as only argument
#  defaults to USER=gunn

scriptname="`basename $0`"

# Set user name
USER="gunn"

# Set machine name
machine_name="TEST"

if [[ $# -gt 0 ]] ; then
    machine_name="$1"
fi

if [[ $# -gt 1 ]] ; then
    USER="$2"
fi

# email vars
SENDTO="gunn@beeble.localnet"
SUBJECT="ssh drop on $machine_name"

case $machine_name in
    ATOM)
        ATOM_PORTNUM=
        ATOM_IP=
        LOGIN_CMD="ssh -vv -p $ATOM_PORTNUM ${USER}@$ATOM_IP"
    ;;
    RPI)
        RPI_IP=
        LOGIN_CMD="ssh ${USER}@$RPI_IP"
    ;;
    TEST)
        LOGIN_CMD="ssh pi@10.0.42.138"
    ;;
    *)
        echo "Unknown login name: $machine_name"
	echo "Must be one of, TEST, ATOM, RPI"
	exit 1
    ;;
esac

$LOGIN_CMD

bodyfile=$(mktemp /tmp/ssh_drop.XXXXXX)

{
echo
echo "ssh connection dropped at $(date) on $machine_name"
} > $bodyfile

mutt  -s "$SUBJECT" $SENDTO  < $bodyfile

echo "$scriptname stopped at $(date)"
rm $bodyfile
