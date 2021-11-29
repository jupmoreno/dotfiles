#!/usr/bin/env bash
set -e -x

# Specify the preferences directory
defaults write com.googlecode.iterm2.plist PrefsCustomFolder -string "~/.dotfiles/config"
# Use the custom preferences
defaults write com.googlecode.iterm2.plist LoadPrefsFromCustomFolder -bool true
