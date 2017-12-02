#!/usr/bin/env bash

set -e -o pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/functions.sh"

if ! (hash brew 2>/dev/null); then
	info "Installing homebrew..."
	/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
	brew tap 'homebrew/bundle'
	success "Installed homebrew"
fi

if ((BASH_VERSINFO[0] < 4)) || ((BASH_VERSINFO[1] < 2)); then
	info "Updating bash..."
	brew install bash
	success "Updated bash"
fi

# shellcheck source=concurrent.lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/bash-concurrent/concurrent.lib.sh"

brew_apps() {
	info "Installing..." >&3
	brew bundle -v --file='apps/brew.apps'
	info "Configurations..." >&3
	./apps/brew.apps.sh
	success "Done" >&3
}

cask_apps() {
	info "Installing..." >&3
	brew bundle -v --file='apps/cask.apps'
	info "Configurations..." >&3
	./apps/cask.apps.sh
	success "Done" >&3
}

pip_apps() {
	info "Installing..." >&3
	pip install --upgrade -r 'apps/pip.apps'
	success "Done" >&3
}

npm_apps() {
	while read -u 4 app; do
		info "Installing: $app" >&3
		npm install -g $app
	done 4<apps/npm.apps
	success "Done" >&3
}

store_apps() {
	info "Installing..." >&3
	brew bundle -v --file='apps/store.apps'
	success "Done" >&3
}

fonts() {
	info "Installing..." >&3
	brew bundle -v --file='fonts/fonts.cask'
	success "Done" >&3
}

clean() {
	info "Homebrew..." >&3
	brew cleanup
	info "Cask..." >&3
	brew cask cleanup
	success "Done" >&3
}

main() {
	local bash_concurrent_args=(
		- 'Brew apps'     brew_apps
			-- 'Pip apps' pip_apps
			-- 'NPM apps' npm_apps
		- 'Cask apps'     cask_apps
		- 'Store apps'    store_apps
		- 'Fonts apps'    fonts
		- 'Clean'         fonts
		--require-all --before 'Clean'
	)

	concurrent "${args[@]}"
}

main "${@}"
