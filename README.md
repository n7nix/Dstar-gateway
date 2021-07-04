# Dstar-gateway

##### Machine Names

* n7jn2 = Atom
* sjcars = Raspberry Pi

#### ATOM script descriptions

###### wg-status.sh
* Location: /home/kennyr/bin
* Displays:
  * systemd status for wg-quick@wg0 service
  * WireGuard Link status

###### bounce_wg.sh
* Location: /usr/local/bin
* runs every hour
* cron entry:
```
# run script at 15 mins past the hour to bounce wireguard link if down
15 * * * * 	/usr/local/bin/bounce_wg.sh
```

#### Debug
* Check file /tmp/wgfoo on n7jn2 for date/time touched
