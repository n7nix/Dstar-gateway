#!/bin/bash
#
# Send an email when ssh connection is lost
#
#  RPi: ssh gunn@198.163.74.20
#  Atom: ssh -vv -p 50022 gunn@198.163.74.21
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

RPI_LOGIN="ssh $USER@198.163.74.20"
ATOM_LOGIN="ssh -vv -p 50022 $USER @198.163.74.21"
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
