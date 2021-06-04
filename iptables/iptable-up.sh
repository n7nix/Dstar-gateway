#!/bin/bash
#
# Enable iptables rules on devices that are up

# ===== function is_ifaceup
function is_ifaceup() {
    interface=$1
    ip a show $interface up > /dev/null  2>&1
}

# ===== main

# For each VPN interface check if it is up and apply iptables rules
for device in "wg0" ; do
    echo "Using device: $device"
    is_ifaceup "$device"
    # Setup NAT (PRE/POST routing) & FILTER (FORWARD) rules
    if [ "$?" -eq 0 ] ; then
        iptables -A PREROUTING -m conntrack --ctorigdst 198.163.74.21 -j DNAT --to-destination 192.168.99.2
        iptables -A POSTROUTING -m conntrack --ctorigsrc 192.168.99.2 -j SNAT --to-source 198.163.74.21
        iptables -A FORWARD -i wg0 -j ACCEPT
	iptables -A FORWARD -o wg0 -j ACCEPT
    else
        echo "Device: $device NOT UP, iptable rules not applied"
    fi
done
