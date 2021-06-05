#!/bin/sh

# restart wireguard link if down
/usr/bin/wg-quick up wg0 > /dev/null 2>&1

# touch /tmp/foo
touch /tmp/wgfoo
