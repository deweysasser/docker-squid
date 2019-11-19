FROM jwilder/dockerize

# We don't use this, so it's not an issue that it's stored publicly.  If we were doing the MITM squid method
# this would be important to secure

RUN apk add --no-cache squid ca-certificates openssl && \
    mkdir -p /var/spool/squid /var/cache/squid /var/log/squid /etc/squid/ssl; touch /etc/squid/whitelist.txt && \
    openssl req -newkey rsa:2048 -nodes -keyout /etc/squid/ssl/key.pem \
    -x509 -days 3650 \
    -subj "/C=US/ST=Massachusetts/L=Boston/O=Squid Proxy/OU=/CN=squid" \
    -out /etc/squid/ssl/certificate.pem

ADD run-squid.sh /usr/bin/run-squid
ADD squid.conf /etc/squid/squid.conf.templ

ENV ALLOW_ALL_TRAFFIC=false

CMD dockerize -template  /etc/squid/squid.conf.templ:/etc/squid/squid.conf -stdout /var/log/squid/access.log -poll /usr/bin/run-squid
