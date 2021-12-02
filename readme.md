# Juan's dotfiles
A backup of my macOS apps and settings

## Installation

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/jupmoreno/dotfiles/master/install)"
```

## Usage

```
# Run all steps concurrently
./dotfiles

# Run all steps sequentialy
./dotfiles -s
./dotfiles --sequential

# Exclude some steps
./dotfiles -e store-apps,python-apps
./dotfiles --exclude store-apps,python-apps

# Only run some steps
./dotfiles -o brew-apps
./dotfiles --only brew-apps
```
