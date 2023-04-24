#!/bin/bash
#enable ip forwarding
sysctl -w net.ipv4.ip_forward=1
#enable  multipath load sharing
sysctl -w net.ipv4.fib_multipath_hash_policy=1
#enable snat from eth0
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
#set rule for openvpn client source network to use the second routing table
ip rule add from 10.10.10.0/24 table loadb
