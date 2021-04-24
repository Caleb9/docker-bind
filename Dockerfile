FROM alpine:latest

LABEL maintainer="Piotr Karasinski"

RUN apk upgrade && \
    apk add bind=9.16.11-r1 && \
    rm -rf /var/cache/apk

ENV BIND_USER=named \
    DATA_DIR=/data

COPY entrypoint.sh /sbin/entrypoint.sh

# Provide minimum configuration to start named
COPY named.conf /etc/bind/named.conf

RUN chmod 755 /sbin/entrypoint.sh /etc/bind/named.conf

EXPOSE 53/udp 53/tcp

ENTRYPOINT ["/sbin/entrypoint.sh"]
