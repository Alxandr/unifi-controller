#!/usr/bin/env sh

# fail on error
set -e

wget "${1}" -O /UniFi.unix.zip
unzip /UniFi.unix.zip -d /
mv UniFi ${BASEDIR}
rm /UniFi.unix.zip
chown -R unifi:unifi /usr/lib/unifi

rm -rf ${ODATADIR} ${OLOGDIR}
mkdir -p ${DATADIR} ${LOGDIR}
ln -s ${DATADIR} ${BASEDIR}/data
ln -s ${RUNDIR} ${BASEDIR}/run
ln -s ${LOGDIR} ${BASEDIR}/logs
rm -rf {$ODATADIR} ${OLOGDIR}
ln -s ${DATADIR} ${ODATADIR}
ln -s ${LOGDIR} ${OLOGDIR}
mkdir -p /var/cert ${CERTDIR}
ln -s ${CERTDIR} /var/cert/unifi
