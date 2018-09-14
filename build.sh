#!/bin/bash
#
# Run this to build, tag and create fat-manifest for your images

set -e

if [[ -f .env ]]; then
	source .env
else
	echo ERROR: .env not found.
	exit 1
fi

# Fail on empty params
if [[ -z ${REPO} || -z ${IMAGE_NAME} || -z ${TARGET_ARCHES} ]]; then
	echo ERROR: Please set build parameters.
	exit 1
fi

# Determine OS and Arch.
build_os=$(uname -s | tr '[:upper:]' '[:lower:]')

if [[ -z ${IMAGE_VERSION} ]]; then
	IMAGE_VERSION="latest"
fi

for docker_arch in ${TARGET_ARCHES}; do
	case ${docker_arch} in
	amd64) qemu_arch="x86_64" ;;
	arm32v[5-7]) qemu_arch="arm" ;;
	arm64v8) qemu_arch="aarch64" ;;
	*)
		echo ERROR: Unknown target arch.
		exit 1
		;;
	esac
	cat Dockerfile.cross | sed "s|__BASEIMAGE_ARCH__|${docker_arch}|g" >Dockerfile.${docker_arch}
	if ! [[ ${docker_arch} == "amd64" || ${build_os} == "darwin" ]]; then
		cat Dockerfile.${docker_arch} | sed '/FROM/s/.*/&\
COPY qemu\/qemu-'${qemu_arch}'-static \/usr\/bin\//' >Dockerfile.tmp
		rm Dockerfile.${docker_arch}
		mv Dockerfile.tmp Dockerfile.${docker_arch}
	fi

	docker build -f Dockerfile.${docker_arch} -t ${REPO}/${IMAGE_NAME}:${docker_arch}-${IMAGE_VERSION} .
	arch_images="${arch_images} ${REPO}/${IMAGE_NAME}:${docker_arch}-${IMAGE_VERSION}"
	rm Dockerfile.${docker_arch}
	docker push ${REPO}/${IMAGE_NAME}:${docker_arch}-${IMAGE_VERSION}
done

echo INFO: Creating fat manifest for ${REPO}/${IMAGE_NAME}:${IMAGE_VERSION}
echo INFO: with subimages: ${arch_images}
if [ -d ${HOME}/.docker/manifests/docker.io_${REPO}_${IMAGE_NAME}-${IMAGE_VERSION} ]; then
	rm -rf ${HOME}/.docker/manifests/docker.io_${REPO}_${IMAGE_NAME}-${IMAGE_VERSION}
fi
docker manifest create ${REPO}/${IMAGE_NAME}:${IMAGE_VERSION} ${arch_images}
for docker_arch in ${TARGET_ARCHES}; do
	case ${docker_arch} in
	amd64) annotate_flags="--os linux --arch amd64" ;;
	arm32v[5-7]) annotate_flags="--os linux --arch arm" ;;
	arm64v8) annotate_flags="--os linux --arch arm64 --variant v8" ;;
	esac
	echo INFO: Annotating arch: ${docker_arch} with \"${annotate_flags}\"
	docker manifest annotate ${REPO}/${IMAGE_NAME}:${IMAGE_VERSION} ${REPO}/${IMAGE_NAME}:${docker_arch}-${IMAGE_VERSION} ${annotate_flags}
done

echo INFO: Pushing manifest
docker manifest push ${REPO}/${IMAGE_NAME}:${IMAGE_VERSION}

if [ -d ${HOME}/.docker/manifests/docker.io_${REPO}_${IMAGE_NAME}-${IMAGE_VERSION} ]; then
	rm -rf ${HOME}/.docker/manifests/docker.io_${REPO}_${IMAGE_NAME}-${IMAGE_VERSION}
fi
