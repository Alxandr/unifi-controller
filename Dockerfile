FROM --platform=$BUILDPLATFORM openjdk:8-alpine3.8 AS build

ARG VER
ENV PKGURL=http://www.ubnt.com/downloads/unifi/${VER}/UniFi.unix.zip
ENV BASEDIR=/usr/lib/unifi \
  DATADIR=/unifi/data \
  LOGDIR=/unifi/log \
  CERTDIR=/unifi/cert \
  RUNDIR=/var/run/unifi \
  CERTNAME=cert.pem \
  CERT_PRIVATE_NAME=privkey.pem \
  CERT_IS_CHAIN=false \
  BIND_PRIV=true \
  RUNAS_UID0=false \
  UNIFI_GID=99 \
  UNIFI_UID=99

RUN if [ -z "$VER" ]; then echo "VER not set."; exit 1; fi
COPY docker-build.sh /usr/local/bin/
RUN apk add --no-cache su-exec shadow curl run-parts libcap bash libc6-compat gcompat \
  && mkdir -p /usr/unifi /usr/local/unifi/init.d /usr/unifi/init.d \
  && groupadd -r unifi -g $UNIFI_GID \
  && useradd --no-log-init -r -u $UNIFI_UID -g $UNIFI_GID unifi \
  && chmod +x /usr/local/bin/docker-build.sh \
  && /usr/local/bin/docker-build.sh "${PKGURL}" \
  && rm /usr/local/bin/docker-build.sh

COPY log4j2.xml /etc/unifi/
COPY import_cert /usr/unifi/init.d/

FROM openjdk:13-alpine3.8

LABEL maintainer="Aleksander Heintz <alxandr@alxandr.me>"

ENV BASEDIR=/usr/lib/unifi \
  DATADIR=/unifi/data \
  LOGDIR=/unifi/log \
  CERTDIR=/unifi/cert \
  RUNDIR=/var/run/unifi \
  CERTNAME=cert.pem \
  CERT_PRIVATE_NAME=privkey.pem \
  CERT_IS_CHAIN=false \
  BIND_PRIV=true \
  RUNAS_UID0=false \
  UNIFI_GID=99 \
  UNIFI_UID=99

RUN apk add --no-cache su-exec shadow curl run-parts libcap bash libc6-compat gcompat \
  && groupadd -r unifi -g $UNIFI_GID \
  && useradd --no-log-init -r -u $UNIFI_UID -g $UNIFI_GID unifi

COPY --from=build /usr/unifi /usr/unifi
COPY --from=build /usr/local/unifi/init.d /usr/local/unifi/init.d
COPY --from=build /usr/unifi/init.d /usr/unifi/init.d
COPY --from=build /etc/unifi/ /etc/unifi/
COPY --from=build /usr/lib/unifi /usr/lib/unifi
COPY docker-entrypoint.sh docker-healthcheck.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
  && chmod +x /usr/unifi/init.d/import_cert \
  && chmod +x /usr/local/bin/docker-healthcheck.sh \
  && chmod +r /etc/unifi/log4j2.xml

VOLUME ["/unifi", "${RUNDIR}"]
EXPOSE 3478/udp 8080/tcp 8443/tcp 8880/tcp 8843/tcp 6789:6789/tcp 10001/udp 1900/udp
WORKDIR /unifi

HEALTHCHECK --start-period=20s CMD /usr/local/bin/docker-healthcheck.sh || exit 1
ENTRYPOINT ["bash", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["unifi"]
