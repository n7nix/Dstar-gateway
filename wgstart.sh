#!/bin/sh
#
DEBUG=

scriptname="`basename $0`"

local_log_dir="/root/log"
local_log_file="$local_log_dir/wg_log.txt"
sys_log="/var/log/syslog"


# ===== function test_log
# Test logging to multiple files
msg_log() {
    if [ ! -d "$local_log_dir" ] ; then
        echo "$(date): local log dir does NOT exist, making dir: $local_log_dir"
        mkdir -p "$local_log_dir"
    else
        echo "local log dir exists: $local_log_dir"
    fi
    msg="$1"
    logger -p local0.debug $msg
#    echo "DEBUG: $(echo -n $(date)) $msg"
    echo "$(echo -n $(date)): $msg" >> $local_log_file
}

# ===== main

while [ $# -gt 0 ] ; do
key="$1"

case $key in
   -t|--test)
        msg_log "Debug test (-t)"
	echo
	echo "===== syslog ====="
	tail -n4 $sys_log
	echo
	echo "===== local log ====="
	tail -n4 $local_log_file
        exit 0
    ;;
   *)
      # unknown option
      echo "Unknow option: $key"
      usage
      exit 1
    ;;
esac
shift # past argument or value
done


# /bin/date >> $local_log_file
/sbin/ifconfig wg0
if [ $? -ne 0 ] ; then
    msg_log "  wg0 interface NOT found, quick up in progress"
    msg_log "$(/usr/bin/wg-quick up wg0)"
else
    msg_log "  wg0 interface already UP"
fi

exit 0
