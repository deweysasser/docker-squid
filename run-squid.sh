#!/bin/sh

rm -rf /var/run/squid.pid
squid -N -d 9
