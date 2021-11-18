# Juan's dotfiles
A backup of my macOS apps and settings

## Usage

```
# Run all steps concurrently
./install.sh

# Run all steps sequentialy
./install.sh -s
./install.sh --sequential

# Ignore some steps
./install.sh -i store-apps,python-apps
./install.sh --ignore store-apps,python-apps

# Only run some steps
./install.sh -o brew-apps
./install.sh --only brew-apps
```
