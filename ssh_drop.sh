#!/bin/bash
#
# Send an email when ssh connection is lost
#
#  RPi: ssh $USER@$RPI_IP
#  Atom: ssh -vv -p $ATOM_PORTNUM $USER@$ATOM_IP
#
# Takes USER name as only argument
#  defaults to USER=gunn

scriptname="`basename $0`"
USER="gunn"
machine_name="ATOM"

# email vars
SENDTO="gunn@beeble.localnet"
SUBJECT="ssh drop on $machine_name"

if [[ $# -gt 0 ]] ; then
    USER="$1"
fi

ATOM_PORTNUM=
ATOM_IP=
ATOM_LOGIN="ssh -vv -p $ATOM_PORTNUM ${USER}@$ATOM_IP"

RPI_IP=
RPI_LOGIN="ssh ${USER}@$RPI_IP"

TEST_LOGIN="ssh pi@10.0.42.138"

$TEST_LOGIN

bodyfile=$(mktemp /tmp/ssh_drop.XXXXXX)

{
echo
echo "ssh connection dropped at $(date) on $machine_name"
} > $bodyfile

mutt  -s "$SUBJECT" $SENDTO  < $bodyfile

echo "$scriptname stopped at $(date)"
rm $bodyfile
