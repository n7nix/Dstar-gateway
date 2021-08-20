#!/bin/bash
#
# update.sh
#
# Copy all required programs to proper directories

cp atom_restart.sh /usr/local/bin
cp atom_connection.service /etc/systemd/system
cp atom_connection.timer /etc/systemd/system
systemctl daemon-reload