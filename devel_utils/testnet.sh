#! /bin/bash

#
# SLIP
#

#slattach -v -s 57600 -p ppp /dev/ttyS1 &
#ifconfig sl0 up mtu 984 192.168.1.15
#route add -host 192.168.1.64 sl0

#
# PPP
#

pppd /dev/ttyS1 57600 192.168.1.15:192.168.1.64 passive noauth
 
