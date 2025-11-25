#!/bin/sh

# Remove any stale PID file
rm -f /var/run/squid.pid

# Run squid in foreground
squid -N -d 9
