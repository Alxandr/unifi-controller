ARG UNIFI_CONTROLLER_VERSION

FROM lscr.io/linuxserver/unifi-controller:${UNIFI_CONTROLLER_VERSION}

# add local files
COPY root/ /
