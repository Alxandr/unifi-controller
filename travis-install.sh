#!/bin/env bash

set -e

QEMU_VERSION="v2.9.1-1"
BUILD_ARCHS="x86_64 aarch64 arm"

ABS_FROM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ABS_DEST="$ABS_FROM"

sudo docker run --rm --privileged multiarch/qemu-user-static:register

mkdir -p ${ABS_DEST}/qemu ${ABS_FROM}/qemu
for target_arch in ${BUILD_ARCHS}; do
	[[ -f ${ABS_FROM}/qemu/x86_64_qemu-${target_arch}-static.tar.gz ]] || wget -N -P ${ABS_FROM}/qemu https://github.com/multiarch/qemu-user-static/releases/download/${QEMU_VERSION}/x86_64_qemu-${target_arch}-static.tar.gz
	tar -xvf ${ABS_FROM}/qemu/x86_64_qemu-${target_arch}-static.tar.gz -C ${ABS_DEST}
done
