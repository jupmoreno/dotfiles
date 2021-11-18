#!/usr/bin/env bash

function info () {
	printf '\033[0;34m'"$1\n"'\033[0m'
}

function user () {
	printf '\033[0;33m'"$1"'\033[0m'
}

function success () {
	printf '\033[0;32m'"$1\n"'\033[0m'
}

function fail () {
	printf '\033[0;31m'"$1\n"'\033[0m'
}

function ask_continue () {
	echo "Continue?"
	select yn in "Yes" "No"; do
		case $yn in
			Yes ) break;;
			No ) exit;;
		esac
	done
	echo ""
}

contains() {
	local word=$1 ; shift
	for e in "$@"; do [[ "$e" == "$word" ]] && return 0; done
	return 1
}
