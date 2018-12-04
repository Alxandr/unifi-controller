#!/bin/bash

set -e

OWNER="alxandr"
REPO="unifi-controller"

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

function install-node() {
	if ! [[ -d "node_modules" ]]; then
		source ~/.nvm/nvm.sh 1>&3
		nvm install stable 1>&3
		nvm use stable 1>&3
		npm ci 1>&3
	else
		say "Skipping node install, cause node_modules exist"
	fi
}

function get-current-version() {
	local version=$(<VERSION)

	say-value false "current version" "$version"
	echo "$version"
}

function get-version() {
	install-node
	local version=$(node get-version.js)

	say-value false "latest version" "$version"
	echo "$version"
}

function setup-git() {
	git config --global user.email "travis@travis-ci.com"
	git config --global user.name "Travis CI"
	git config --global push.default current
}

function update-version() {
	local currentVersion=$(get-current-version)
	local nextVersion=$(get-version)

	if [[ "$currentVersion" != "$nextVersion" ]]; then
		say "New version found. Creating new version release."
		echo "$nextVersion" >VERSION
		setup-git
		git add VERSION
		git commit -m "Update version to v$nextVersion"
		git tag "v$nextVersion"
		git push origin master --tags
	else
		say "No new version available."
	fi
}

if [[ "$TRAVIS_BRANCH" == "master" ]]; then
	update-version
else
	say "Not on travis master branch, skipping..."
fi
