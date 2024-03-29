# squid

Squid in a container, with ssl support, suitable for transparent proxying of http and https.

Squid proxy is on port 3128, transparent http on 3129, transparent https on 3127.

# Running

```bash
docker run -d --name squid --net host -v /etc/squid/whitelist.txt:/etc/squid/whitelist.txt deweysasser/squid:latest 
iptables -t nat -A PREROUTING -i $eth0 -p tcp --dport  80 -j REDIRECT --to-port 3129
iptables -t nat -A PREROUTING -i $eth0 -p tcp --dport 443 -j DNAT --to 3127
```

## Whitelisting specific sites

The file `whitelist.txt` should contain a list of domain names with leading period which will be allowed for both http and https.

Example:

```text
.google.com
.ubuntu.com
```

## Allowing all traffic (i.e. just log)

If you want to allow all traffic through, set the environment variable `ALLOW_ALL_TRAFFIC` to `true`.

This will configure squid to ignore the whitelist and pass all requests.  It will still log all traffic passed.

## Building

```bash
docker build -t squid .
```

The build will generate and embed an SSL certificate.  This certificate is not used for anything other than
allowing squid to run.

## Notes

Squid configuration is baroque at best.  Changing anything might break everything.  I can't really claim to understand it,
well, I simply flailed at it until it worked.