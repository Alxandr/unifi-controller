#!/bin/bash

set -e

REPO="alxandr"
IMAGE_NAME="unifi-controller"
IMAGE_VERSIONS=("latest")
TARGET_ARCHES="amd64 arm32v6 arm64v8"
DOCKER_FILE="Dockerfile.cross"
PUSH=false
RUN=false
CONTROLLER_VERSION=$(<VERSION)

# standard output may be used as a return value in the functions
# we need a way to write text on the screen in the functions so that
# it won't interfere with the return value.
# Exposing stream 3 as a pipe to standard output of the script itself
exec 3>&1

# Setup some colors to use. These need to work in fairly limited shells, like the Ubuntu Docker container where there are only 8 colors.
# See if stdout is a terminal
if [ -t 1 ]; then
	# see if it supports colors
	ncolors=$(tput colors)
	if [ -n "$ncolors" ] && [ $ncolors -ge 8 ]; then
		bold="$(tput bold || echo)"
		normal="$(tput sgr0 || echo)"
		black="$(tput setaf 0 || echo)"
		red="$(tput setaf 1 || echo)"
		green="$(tput setaf 2 || echo)"
		yellow="$(tput setaf 3 || echo)"
		blue="$(tput setaf 4 || echo)"
		magenta="$(tput setaf 5 || echo)"
		cyan="$(tput setaf 6 || echo)"
		white="$(tput setaf 7 || echo)"
	fi
fi

function say-err() {
	printf "%b\n" "${red:-}ERROR: $1${normal:-}" >&2
}

function say() {
	# using stream 3 (defined in the beginning) to not interfere with stdout of functions
	# which may be used as return value
	printf "%b\n" "${cyan:-}INFO:${normal:-} $1" >&3
}

function say-verbose() {
	if [ "$verbose" = true ]; then
		say "$1"
	fi
}

function say-value() {
	local verbose="$1"
	local varname="$2"
	local value="$3"
	local msg="${green:-}$varname${normal:-}: ${yellow}$value${normal:-}"

	if $verbose; then
		say-verbose "$msg"
	else
		say "$msg"
	fi
}

function contains() {
	local list="$1"
	local item="$2"
	if [[ $list =~ (^|[[:space:]])"$item"($|[[:space:]]) ]]; then
		# yes, list include item
		return 0
	fi

	return 1
}

# Use in the the functions: eval $invocation
invocation='say-verbose "Calling: ${yellow:-}${FUNCNAME[0]} ${green:-}$*${normal:-}"'

function build-dockerfile() {
	eval $invocation

	local docker_arch=$1
	local qemu_arch=$2
	local docker_file=$3

	local docker_file=$(cat "$docker_file" | sed "s|__BASEIMAGE_ARCH__|${docker_arch}|g")
	if ! [[ ${docker_arch} == "amd64" || ${build_os} == "darwin" ]]; then
		say "Injecting qemu-${qemu_arch}-static"
		docker_file=$(sed '/FROM/s/.*/&\
COPY qemu\/qemu-'${qemu_arch}'-static \/usr\/bin\//' <<<"$docker_file")
	else
		say "Qemu static not injected"
	fi

	cat <<<"$docker_file" >Dockerfile.${docker_arch}
	say-value "false" "Docker file" "Dockerfile.${docker_arch}"
	docker build --build-arg "VER=${CONTROLLER_VERSION}" -f Dockerfile.${docker_arch} -t ${REPO}/${IMAGE_NAME}:${docker_arch}-temp . 1>&4

	for IMAGE_VERSION in "${IMAGE_VERSIONS[@]}"; do
		docker tag ${REPO}/${IMAGE_NAME}:${docker_arch}-temp ${REPO}/${IMAGE_NAME}:${docker_arch}-${IMAGE_VERSION}
		echo "${REPO}/${IMAGE_NAME}:${docker_arch}-${IMAGE_VERSION}"
	done

	say-verbose "Delete dockerfile"
	rm Dockerfile.${docker_arch}
}

function build-arch() {
	eval $invocation

	local arch=$1
	local qemu_arch
	case ${arch} in
	amd64) qemu_arch="x86_64" ;;
	arm32v[5-7]) qemu_arch="arm" ;;
	arm64v8) qemu_arch="aarch64" ;;
	*)
		say-err "Unknown target arch."
		return 1
		;;
	esac

	say-value "false" "Docker arch" "$arch"
	say-value "false" "Qemu arch" "$qemu_arch"
	local image_tags=$(build-dockerfile "$arch" "$qemu_arch" "$DOCKER_FILE")
	for image_tag in "${image_tags[@]}"; do
		say-value "false" "Built tag" "$image_tag"
	done

	if $PUSH; then
		say "Pushing images"
		for image_tag in "${image_tags[@]}"; do
			docker push "$image_tag" 1>&4
		done
	else
		say "Not pushing images"
	fi

	echo "${image_tags[@]}"
}

function build-manifest() {
	eval $invocation

	for IMAGE_VERSION in "${IMAGE_VERSIONS[@]}"; do
		local arches="$1"
		local manifest_image="${REPO}/${IMAGE_NAME}:${IMAGE_VERSION}"
		say "Creating fat manifest ${magenta}$manifest_image${normal:-} for ${yellow}$arches${normal:-}"

		if [ -d ${HOME}/.docker/manifests/docker.io_${REPO}_${IMAGE_NAME}-${IMAGE_VERSION} ]; then
			rm -rf ${HOME}/.docker/manifests/docker.io_${REPO}_${IMAGE_NAME}-${IMAGE_VERSION}
		fi

		local arch_images=""
		for docker_arch in ${TARGET_ARCHES}; do
			local image="${REPO}/${IMAGE_NAME}:${docker_arch}-${IMAGE_VERSION}"
			say "Pulling image ${yellow}$image${normal:-}"
			docker pull "$image" 1>&4
			arch_images="$arch_images $image"
		done

		say-value "true" "Arch images" "$arch_images"
		say-verbose "docker manifest create "$manifest_image" ${arch_images}"
		docker manifest create "$manifest_image" ${arch_images} 1>&4

		for docker_arch in ${TARGET_ARCHES}; do
			local image="${REPO}/${IMAGE_NAME}:${docker_arch}-${IMAGE_VERSION}"
			local annotate_flags
			case ${docker_arch} in
			amd64) annotate_flags="--os linux --arch amd64" ;;
			arm32v[5-7]) annotate_flags="--os linux --arch arm" ;;
			arm64v8) annotate_flags="--os linux --arch arm64 --variant v8" ;;
			*)
				say-err "Non supported arch: $docker_arch, must be one of: $TARGET_ARCHES"
				return 1
				;;
			esac

			say-value "false" "$image annotations" "$annotate_flags"
			docker manifest annotate "$manifest_image" "$image" ${annotate_flags} 1>&4
		done

		say "Pushing manifest ${magenta}$manifest_image${normal:-}"
		docker manifest push "$manifest_image"

		if [ -d ${HOME}/.docker/manifests/docker.io_${REPO}_${IMAGE_NAME}-${IMAGE_VERSION} ]; then
			rm -rf ${HOME}/.docker/manifests/docker.io_${REPO}_${IMAGE_NAME}-${IMAGE_VERSION}
		fi
	done
}

while getopts ":vpr" opt; do
	case "$opt" in
	v)
		verbose=true
		;;

	p)
		PUSH=true
		;;

	r)
		RUN=true
		;;

	\?)
		say-err "Invalid option: -$OPTARG"
		;;
	esac
done

shift $(($OPTIND - 1))
ARCH=${1:-amd64}

if $verbose; then
	say "pipe 4 to 3"
	exec 4>&3
fi

say-value "false" "Controller Version" "$CONTROLLER_VERSION"

build_os=$(uname -s | tr '[:upper:]' '[:lower:]')
say-value "false" "Build OS" "$build_os"

TRAVIS=${TRAVIS:-false}
say-value "true" "Travis" "$TRAVIS"

say-value "false" "Build OS" "$build_os"

if $TRAVIS && ! [[ -z "$TRAVIS_TAG" ]]; then
	TAG_VERSION=${TRAVIS_TAG//v/}
	IMAGE_VERSIONS+=("$TAG_VERSION")

	say-value "true" "Travis branch" "$TRAVIS_BRANCH"
	say-value "true" "Travis tag" "${TRAVIS_TAG:-"NONE"}"
	say "Enabling push on travis tag"
	say "Image verisons:"
	for IMAGE_VERSION in "${IMAGE_VERSIONS[@]}"; do
		say " - ${IMAGE_VERSION}"
	done

	PUSH=true
fi

case $ARCH in
manifest)
	if $PUSH; then
		build-manifest "$TARGET_ARCHES"
	else
		say-err "Manifest building requires $PUSH to be enabled"
		exit 1
	fi
	;;

*)
	contains "$TARGET_ARCHES" "$ARCH" ||
		(say-err "Non supported arch: $ARCH, must be one of: $TARGET_ARCHES" &&
			exit 1)
	image=$(build-arch "$ARCH")
	if $RUN; then
		exec docker run -it -p 8888:8888/tcp "$image"
	fi
	;;

esac
