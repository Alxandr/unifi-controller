ARG UNIFI_CONTROLLER_VERSION

FROM ghcr.io/linuxserver/unifi-controller:${UNIFI_CONTROLLER_VERSION}

# add local files
COPY root/ /
