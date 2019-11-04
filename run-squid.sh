#!/bin/sh

rm -rf /var/run/squid.pid
tail -vn 0 -F /var/log/squid/access.log /var/log/squid/cache.log &
squid -N -d 9
