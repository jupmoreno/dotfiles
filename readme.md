# Juan's dotfiles
A backup of my macOS apps and settings

## Usage

```
# Run all steps concurrently
./install

# Run all steps sequentialy
./install -s
./install --sequential

# Ignore some steps
./install -i store-apps,python-apps
./install --ignore store-apps,python-apps

# Only run some steps
./install -o brew-apps
./install --only brew-apps
```
