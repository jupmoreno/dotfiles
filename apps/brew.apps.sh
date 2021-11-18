#!/usr/bin/env bash

# brew 'fzf'
(brew --prefix)/opt/fzf/install

# brew 'jenv'
for D in /Library/Java/JavaVirtualMachines/*/; do jenv add ${D}Contents/Home/; done
