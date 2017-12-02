#!/usr/bin/env bash

set -e -o pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/functions.sh"

if ! (hash brew 2>/dev/null); then
	fail "This script requires homebrew to be installed!"
	exit 1
fi

if ((BASH_VERSINFO[0] < 4)) || ((BASH_VERSINFO[1] < 2)); then
	fail "This script needs bash version > 4.2!"
	exit 1
fi

if ! (hash pip 2>/dev/null); then
	fail "This script requires PIP to be installed!"
	exit 1
fi

if ! (hash npm 2>/dev/null); then
	fail "This script requires NPM to be installed!"
	exit 1
fi

# TODO: Update bash-concurrent

# shellcheck source=concurrent.lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/bash-concurrent/concurrent.lib.sh"

system_update() {
	info "Updating..." >&3
	softwareupdate --install --all
	success "Updated" >&3
}

cask_brew_update() {
	info "Updating..." >&3
	brew update
	brew upgrade --all
	info "Cleaning up..." >&3
	brew cleanup
	brew cask cleanup
	success "Updated" >&3
}

pip_update() {
	info "Updating..." >&3
	pip install --upgrade pip setuptools
	success "Updated" >&3
}

npm_update() {
	# for app in $(npm -g outdated --parseable --depth=0 | cut -d: -f2); do
	# 	info "Updating: $app" >&3
	# 	npm -g install "$app"
	# done
	info "Updating..." >&3
	npm update -g
	success "Done" >&3
}

store_update() {
	info "Updating..." >&3
	mas upgrade
	success "Done" >&3
}

main() {
	local bash_concurrent_args=(
		- 'System'                 system_update
		- 'Brew/Cask apps & Fonts' cask_brew_update
		- 'Pip apps'               pip_update
		- 'NPM apps'               npm_update
		- 'Store apps'             store_update
	)

	concurrent "${args[@]}"
}

main "${@}"
