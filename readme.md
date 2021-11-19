# Juan's dotfiles
A backup of my macOS apps and settings

## Usage

```
# Run all steps concurrently
./dotfiles

# Run all steps sequentialy
./dotfiles -s
./dotfiles --sequential

# Ignore some steps
./dotfiles -i store-apps,python-apps
./dotfiles --ignore store-apps,python-apps

# Only run some steps
./dotfiles -o brew-apps
./dotfiles --only brew-apps
```
