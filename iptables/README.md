### iptable setup for D-Star Gateway

##### NAT
```
-A PREROUTING -m conntrack --ctorigdst $SOURCE_ADDRESS -j DNAT --to-destination $DESTINATION_ADDRESS
-A POSTROUTING -m conntrack --ctorigsrc $DESTINATION_ADDRESS -j SNAT --to-source $SOURCE_ADDRESS
```
##### FILTER
```
-A FORWARD -i wg0 -j ACCEPT
-A FORWARD -o wg0 -j ACCEPT
```
