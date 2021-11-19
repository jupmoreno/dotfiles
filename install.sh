#!/usr/bin/env bash

set -e -o pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils/helpers.sh"

if ! (hash brew 2>/dev/null); then
	info "Installing homebrew..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	success "Done"
fi

if  (( ${BASH_VERSINFO[0]} < 4 )) || (( ${BASH_VERSINFO[0]} == 4 && ${BASH_VERSINFO[1]} < 2 )); then
	fail "Need to update bash..."
	brew install bash
	success "Done. Restart the script..."
	exit 1
fi

# shellcheck source=concurrent.lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils/bash-concurrent/concurrent.lib.sh"

check_brew_installed() {
	if ! (hash brew 2>/dev/null); then
		info "Installing homebrew..."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		success "Done"
	fi
}

check_mas_installed() {
	check_brew_installed
	if ! (hash mas 2>/dev/null); then
		info "Installing mas..." >&3
		brew install mas
		open -a "App Store"
		fail "Installed mas. Sign into the App Store" >&3
		exit 1
	fi
}

check_python_installed() {
	check_brew_installed
	if ! (hash pip3 2>/dev/null); then
		info "Installing python..." >&3
		brew install python
		success "Installed python" >&3
	fi
}

check_node_installed() {
	check_brew_installed
	if ! (brew list node 2>/dev/null); then
		info "Installing node..." >&3
		brew install node
		success "Installed node" >&3
	fi
}

check_dotbot_installed() {
	check_python_installed
	if ! (hash dotbot 2>/dev/null); then
		info "Installing dotbot..." >&3
		pip3 install dotbot
		success "Installed dotbot" >&3
	fi
}

check_mackup_installed() {
	check_brew_installed
	if ! (hash mackup 2>/dev/null); then
		info "Installing mackup and drive..." >&3
		brew install google-drive
		brew install mackup
		open -a "Google Drive"
		fail "Installed mackup and drive. Sign into Google Drive" >&3
		exit 1
	fi
}

update_script() {
	info "Updating submodules..." >&3
	git submodule update --init --recursive
	success "Done" >&3
}

update_system() {
	info "Updating..." >&3
	softwareupdate --all --install
	success "Done" >&3
}

install_brew_apps() {
	info "Checking..." >&3
	check_brew_installed
	info "Updating..." >&3
	brew update
	brew upgrade
	info "Installing..." >&3
	brew bundle -v --file='apps/brew.apps'
	info "Cleaning..." >&3
	brew cleanup
	success "Done" >&3
}

install_cask_apps() {
	info "Checking..." >&3
	check_brew_installed
	info "Updating..." >&3
	brew upgrade --cask
	info "Installing..." >&3
	brew bundle -v --file='apps/cask.apps'
	info "Cleaning..." >&3
	brew cleanup
	success "Done" >&3
}

install_store_apps() {
	info "Checking..." >&3
	check_mas_installed
	info "Updating..." >&3
	mas upgrade
	info "Installing..." >&3
	brew bundle -v --file='apps/store.apps'
	success "Done" >&3
}

install_python_apps() {
	info "Checking..." >&3
	check_python_installed
	info "Updating..." >&3
	pip3 install --upgrade pip setuptools
	info "Installing..." >&3
	pip3 install --upgrade -r 'apps/pip.apps'
	success "Done" >&3
}

install_node_apps() {
	info "Checking..." >&3
	check_node_installed
	info "Updating..." >&3
	npm update -g
	while read -u 4 app; do
		info "Installing: $app" >&3
		npm install -g $app
	done 4<apps/npm.apps
	success "Done" >&3
}

install_fonts() {
	info "Checking..." >&3
	check_brew_installed
	info "Installing..." >&3
	brew bundle -v --file='fonts/fonts.cask'
	info "Cleaning..." >&3
	brew cleanup
	success "Done" >&3
}

link_files() {
	info "Checking..." >&3
	check_dotbot_installed
	info "Linking..." >&3
	dotbot -c "links.yaml"
	success "Done" >&3
}

link_backups() {
	info "Checking..." >&3
	check_mackup_installed
	info "Restoring..." >&3
	mackup restore
	success "Done" >&3
}

declare -A TASKS
TASKS=(
	["update-script"]=update_script
	["update-system"]=update_system
	["brew-apps"]=install_brew_apps
	["cask-apps"]=install_cask_apps
	["store-apps"]=install_store_apps
	["python-apps"]=install_pip_apps
	["node-apps"]=install_npm_apps
	["fonts"]=install_fonts
	["links"]=link_files
	["backups"]=link_backups
)

TASKS_ORDER=(
	"update-script update-system"
	"brew-apps cask-apps store-apps python-apps node-apps fonts"
	"links"
	"backups"
)

run_concurrently() {
	local args=()
	local tasks_order_size=${#TASKS_ORDER[@]}

	for i in ${!TASKS_ORDER[@]}; do
		local added=false
		for item in ${TASKS_ORDER[$i]}; do
			if !(contains $item ${IGNORE_TASKS[@]}); then
				args+=("- '$item' ${TASKS[$item]} ")
				added=true
			fi
		done

		if $added && (( $i != $tasks_order_size - 1 )); then
			args+=("--and-then ")
		fi
	done

	concurrent ${args[@]}
}

run_sequentialy() {
	exec 3>&1
	trap -- exit INT

	for items in "${TASKS_ORDER[@]}"; do
		for item in $items; do
			if ! (contains $item ${IGNORE_TASKS[@]}); then
				info "Executing $item"
				${TASKS[$item]}
			fi
		done
	done
}

main() {
	local sequential=false
	while [[ $# -gt 0 ]]; do
		key="$1" ; shift
		case $key in
			-i|--ignore)     readarray -td, IGNORE_TASKS <<<"$1"; shift ;;
			-o|--only)       readarray -td, ONLY_TASKS <<<"$1"; shift ;;
			-s|--sequential) sequential=true ;;
			*)               fail "Unknown parameter: $key" ;;
		esac
	done

	if (( ${#ONLY_TASKS[@]} != 0 )); then
		for item in "${!TASKS[@]}"; do
			if !( contains $item ${ONLY_TASKS[@]}); then
				IGNORE_TASKS+=("$item")
			fi
		done
	fi

	if $sequential; then
		run_sequentialy
	else
		run_concurrently
	fi
}

main "${@}"
