### iptable setup for D-Star Gateway
#### script descriptions

###### iptable-check.sh
* List filter rules and check for hook & rules files
* passive, no files written or rules changed ie. safe to run
* use -d to dump hook & rules file


### Remaining scripts all write files & change rules so have not been tested.

###### iptable-flush.sh
* Flush all iptables rules. Handy when things aren't working

###### iptable-up.sh
* Install iptables rules
  * Edit th is script with required rules
* For debug only should never have to do this.
* For debug do a flush (_iptable-flush.sh_)before running.

###### iptable_install.sh

* Initial install to create files and install rules.
* For reference only since everything was manually installed.

### Two sets of rules

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
#### Debugging

```
systemctl status netfilter-persistent
journalctl --no-pager -u netfilter-persistent
```
