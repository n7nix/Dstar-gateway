#!/bin/sh

# restart wireguard link if down
/usr/bin/wg-quick up wg0 > /dev/null 2>&1
if [ $? -ne 0 ] ; then
    touch /tmp/wgerr
fi
# touch /tmp/foo
touch /tmp/wgfoo
