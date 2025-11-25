FROM alpine:latest

# We don't use this, so it's not an issue that it's stored publicly.  If we were doing the MITM squid method
# this would be important to secure

# Install dockerize
ENV DOCKERIZE_VERSION v0.7.0
RUN apk add --no-cache wget && \
    wget -O - https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz | tar xzf - -C /usr/local/bin && \
    apk del wget

RUN apk add --no-cache squid ca-certificates openssl && \
    mkdir -p /var/spool/squid /var/cache/squid /var/log/squid /etc/squid/ssl /var/lib/squid && \
    touch /etc/squid/whitelist.txt /etc/squid/blocklist.txt && \
    openssl req -newkey rsa:2048 -nodes -keyout /etc/squid/ssl/key.pem \
    -x509 -days 3650 \
    -subj "/C=US/ST=Massachusetts/L=Boston/O=Squid Proxy/OU=/CN=squid" \
    -out /etc/squid/ssl/certificate.pem && \
    /usr/lib/squid/security_file_certgen -c -s /var/lib/squid/ssl_db -M 4MB && \
    squid -z -f /dev/null 2>/dev/null || true && \
    chown -R squid:squid /var/lib/squid /var/cache/squid /var/log/squid /var/spool/squid && \
    rm -f /var/run/squid.pid

ADD run-squid.sh /usr/bin/run-squid
ADD squid.conf /etc/squid/squid.conf.templ

ENV ALLOW_ALL_TRAFFIC=false

CMD dockerize -template  /etc/squid/squid.conf.templ:/etc/squid/squid.conf -stdout /var/log/squid/access.log -poll /usr/bin/run-squid
