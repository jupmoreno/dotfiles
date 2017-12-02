#!/usr/bin/env bash

info () {
	printf '\033[0;34m'"$1\n"'\033[0m'
}

user () {
	printf '\033[0;33m'"$1"'\033[0m'
}

success () {
	printf '\033[0;32m'"$1\n"'\033[0m'
}

fail () {
	printf '\033[0;31m'"$1\n"'\033[0m'
}

ask_continue () {
	echo "Continue?"
	select yn in "Yes" "No"; do
		case $yn in
			Yes ) break;;
			No ) exit;;
		esac
	done
	echo ""
}
