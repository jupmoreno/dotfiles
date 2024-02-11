#!/bin/bash
# Binary versions
KUBECTL_VERSION=v1.23.14
HELM_VERSION=v3.8.2 # This version needs to match core-paas-client library https://github.com/mulesoft/core-paas-client/blob/75f8cf2a3b6e72987806767c72ebf32328574528/go.mod#L67
DOCKER_VERSION_BUILD=20.10.17,85629 # https://download.docker.com/mac/stable/appcast.xml
CPTELE_VERSION=v1.0.48
AWSKEYCLOAK_VERSION=1.7.5
AWSCLI_VERSION=2.11.24
KIND_VERSION=v0.16.0
JQ_VERSION=jq-1.6
GH_VERSION=2.17.0

# Options
INSTALL_DIR=/usr/local/bin

# Get Operating System
OS_NAME=$(uname -s | awk '{print tolower($0)}')
OS_NAME=${OS_NAME:-darwin}

ARCH_OUTPUT=$(uname -m)
case "${ARCH_OUTPUT}" in
  arm64)
    # m1 and newer apple silicon
    ARCH=arm64
  ;;
  x86_64)
    # Intel macs
    ARCH=amd64
  ;;
  *)
    echo "ERROR: Architecture '${ARCH_OUTPUT}' not supported at this time - exiting!"
    exit 1
  ;;
esac

# Colors
blue=$(tput setaf 4)
red=$(tput setaf 1)
green=$(tput setaf 2)
normal=$(tput sgr0)

printf "Welcome to the Core PaaS provision script!\n\n"
if [[ "$1" == "check" ]]; then
  CHECK=YES
else
  if [[ "$1" == "remove" ]]; then
    REMOVE=yes
    printf "ARE YOU SURE YOU WANT TO REMOVE?\n"
    printf "This %sdeletes%s EVERYTHING\n" "$red" "$normal"
  else
    printf "Do you want to install the necessary tools?\n"
  fi
  printf "\n"
  read -rp "Continue (y/N)? " choice
  case "$choice" in
  y | Y)
    printf "\nhere we go!\n"
    ;;
  *)
    printf "\nyea, I figured\n"
    exit 1
    ;;
  esac
fi

# Function that checks for current version of given binary name, version check, filter and desired version
check_version() {
  local binary=$1
  local version_command=$2
  local expected_version=$3
  local current_version
  if hash "$binary" 2>/dev/null; then
    current_version=$(eval "$binary $version_command 2>/dev/null")
    if [[ $current_version == "$expected_version" ]]; then
      return
    fi
    printf "\nInstalled Version: %s\n" "$current_version"
    printf "Expected Version: %s\n" "$expected_version"
  fi
  false
}

download() {
  local binary=$1
  local url=$2
  printf "Downloading %s.\n" "$blue$binary$normal"
  curl --progress-bar -Lo "$binary" "$url"
}

install() {
  local binary=$1
  printf "Installing %-36s" "$blue$binary$normal now."
  chmod +x "$binary"
  mv -f "$binary" "${INSTALL_DIR:?}"
  success
}

uninstall() {
  local binary=$1
  rm -f "${INSTALL_DIR:?}/$binary"
}

success() {
  printf "\t%s✓%s\n" "$green" "$normal"
}

fail() {
  printf "\t%s✖%s\n" "$red" "$normal"
}

check_brew() {
  brew doctor >/dev/null 2>&1
}

test_kubectl() {
  check_version "kubectl" "version --client | awk -F 'GitVersion:\"' '{print \$2}' | awk -F '\",' '{print \$1}'" "$KUBECTL_VERSION"
}

install_kubectl() {
  # older versions of kubectl weren't available for apple silicon, so for now force the arch to intel
  ARCH=amd64
  download kubectl "https://storage.googleapis.com/kubernetes-release/release/$KUBECTL_VERSION/bin/$OS_NAME/$ARCH/kubectl"
  [[ $? -eq 0 ]] && install kubectl
}

remove_kubectl() {
  uninstall kubectl
}

test_helm() {
  check_version "helm" "version --template '{{.Version}}'" "$HELM_VERSION"
}

install_helm() {
  download helm-install "https://raw.githubusercontent.com/helm/helm/$HELM_VERSION/scripts/get-helm-3"
  if [[ $? -ne 0 ]]; then
    echo "ERROR: helm download failed - skipping"
    return
  fi

  printf "Installing ${blue}%s${normal} %-10s" helm "now."
  chmod +x helm-install
  ./helm-install --version "$HELM_VERSION" &>/dev/null
  rm -f helm-install

  if ! test_helm; then
    printf "Helm installation failed!"
    exit 1
  fi
  success
}

remove_helm() {
  uninstall helm
}

test_kind() {
  check_version "kind" "version | awk -F ' +' '{print \$2}'" "$KIND_VERSION"
}

install_kind() {
  download kind "https://github.com/kubernetes-sigs/kind/releases/download/$KIND_VERSION/kind-$OS_NAME-$ARCH"
  install kind
}

remove_kind() {
  uninstall kind
}

test_docker() {
  DOCKER_VERSION=$(printf "%s" "$DOCKER_VERSION_BUILD" | awk -F ',' '{print $1}')
  check_version "docker" "-v | sed 's/Docker version \(.*\),.*/\1/'" "$DOCKER_VERSION"
}

install_docker() {
  DOCKER_BUILD=$(printf "%s" $DOCKER_VERSION_BUILD | awk -F ',' '{print $2}')
  download docker.dmg "https://desktop.docker.com/mac/main/$ARCH/$DOCKER_BUILD/Docker.dmg"
  printf "Installing ${blue}%s${normal} %-10s" "docker" "now."
  sudo -s hdiutil attach docker.dmg 1>/dev/null
  sudo /Volumes/Docker/Docker.app/Contents/MacOS/install
  sudo hdiutil detach /Volumes/Docker
  open /Applications/Docker.app
  [[ -f ./docker.dmg ]] && rm ./docker.dmg
  [[ -d /Volumes/Docker ]] && sudo umount /Volumes/Docker
  [[ -f ./default.profraw ]] && rm ./default.profraw
  success
}

remove_docker() {
  /Applications/Docker.app/Contents/MacOS/Docker --uninstall &>/dev/null
  sudo rm -rf /Applications/Docker.app
}

test_tele() {
  check_version "tele" "version | awk '/^Version:/ {print \$2}'" "$CPTELE_VERSION"
}

install_tele() {
  if [ -z ${GITHUB_API_TOKEN} ]; then
    gh auth status
    if [[ "$?" -ne 0 ]]; then
      gh auth login --hostname github.com
    fi
    GITHUB_API_TOKEN=$(gh config get -h github.com oauth_token)
  fi

  # Check if the token works by performing a head call
  code=$(curl -X HEAD --write-out %{http_code} -s -H "Authorization: token ${GITHUB_API_TOKEN}" \
    -H 'Accept: application/vnd.github.v3.raw' \
    -L "https://api.github.com/repos/mulesoft/core-paas-teleport-cli/contents/hack/install.sh")

  if [[ $code -ne "200" ]]; then
    printf "failed to retrieve tele with status code: $code"
    exit 1
  fi

  curl -H "Authorization: token ${GITHUB_API_TOKEN}" \
  -H 'Accept: application/vnd.github.v3.raw' \
  -L "https://api.github.com/repos/mulesoft/core-paas-teleport-cli/contents/hack/install.sh" | CPTELE_VERSION=$CPTELE_VERSION GITHUB_API_TOKEN=$GITHUB_API_TOKEN bash
}

remove_tele() {
  uninstall tele
}

install_awscli() {
  download "AWSCLIV2.pkg" "https://awscli.amazonaws.com/AWSCLIV2-$AWSCLI_VERSION.pkg"
  sudo installer -pkg AWSCLIV2.pkg -target /
  rm AWSCLIV2.pkg
}

test_awscli() {
  check_version "aws" "--version 2>&1 | awk -F '/' '{print \$2}' | awk -F ' P' '{print \$1}'" "$AWSCLI_VERSION"
}

remove_awscli() {
  uninstall aws
  uninstall aws_completer
  sudo rm -rf /usr/local/aws-cli
}

install_jq() {
  ## prefer brew if available
  if check_brew; then
    brew install jq
    return
  fi

  # as of this writing the only builds provided for jq are amd64, so overwrite ARCH
  ARCH=amd64

  download jq https://github.com/stedolan/jq/releases/download/${JQ_VERSION}/jq-osx-${ARCH}
  install jq
}

remove_jq() {
  ## prefer brew if available
  if [[ check_brew && $(brew list jq >dev/null 2>&1) ]]; then
    brew uninstall jq
    return
  fi

  uninstall jq
}

test_jq() {
  check_version "jq" "--version" "$JQ_VERSION"
}

install_gh() {
  ## prefer brew if available
  if check_brew; then
    brew install gh
    return
  fi

  download gh.tar.gz https://github.com/cli/cli/releases/download/v$GH_VERSION/gh_${GH_VERSION}_macOS_${ARCH}.tar.gz
  mkdir gh
  tar xvzf gh.tar.gz -C gh --strip-components 1
  install gh/bin/gh
  rm -r gh gh.tar.gz
}

remove_gh() {
  ## prefer brew if available
  if [[ check_brew && $(brew list gh >dev/null 2>&1) ]]; then
    brew uninstall gh
    return
  fi

  uninstall gh
}

test_gh() {
  check_version "gh" "version | awk '/^gh/ {print \$3}'" "$GH_VERSION"
}

test_awskeycloak() {
  check_version "aws-keycloak" "--version | awk -F ' ' '{print \$3}'" "$AWSKEYCLOAK_VERSION"
}

install_awskeycloak() {
  DOWNLOAD_URL=https://github.com/mulesoft-labs/aws-keycloak/releases/download/v${AWSKEYCLOAK_VERSION}/aws-keycloak-${AWSKEYCLOAK_VERSION}.big_sur.bottle.tar.gz
  download aws-keycloak.tar.gz ${DOWNLOAD_URL}
  tar xvzf aws-keycloak.tar.gz
  install aws-keycloak/$AWSKEYCLOAK_VERSION/bin/aws-keycloak
  rm -r aws-keycloak aws-keycloak.tar.gz

  if [[ ! -f ~/.aws/keycloak-config ]]; then
    printf "Writing aws-keycloak configuration.\n"
    mkdir -p "$HOME/.aws/"
    touch "$HOME/.aws/keycloak-config"
    cat <<'EOF' >"$HOME/.aws/keycloak-config"
# This config file should be at ~/.aws/keycloak-config or can be specified with
# --config option or KEYCLOAK_CONFIG_FILE env var

[aliases]
# You can add as many aliases as you like in this section. Here are some
# examples to get you started.
#
# run `aws-keycloak list` to see the profiles you can use.
#
# alias = keycloak-env:profile:region(optional)
idm     = id:admin-identity:us-west-2
gbuild  = gov:ro-gbuild
build   = id:ro-build

################################################
#### DO NOT MODIFY ANYTHING AFTER THIS LINE ####
################################################

# Don't freak out about these client "secrets." They are required during
# keycloak authentication but are not a substitute for user creds.
#
# See https://tools.ietf.org/html/rfc6819#section-4.1.1
# In our case, Client Authentication is disabled, which only leaves the risk of
# replaying stolen Authorization codes. This is real, but fairly low risk. We
# require the use of TLS everywhere, and Authorization codes are only valid for
# a short time. Therefore we allow these tokens to be semi-private (wiki, private
# github) because it is convenient.

[id]
default_region     = us-west-2
keycloak_base      = https://keycloak.prod.identity.msap.io
aws_client_id      = urn:amazon:webservices
aws_client_secret  = c3c48ae6-a45a-4678-bac0-79e4a2927cd0

[id.dev]
keycloak_base      = https://keycloak.dev.identity.msap.io
aws_client_id      = urn:amazon:webservices
aws_client_secret  = f57eeb5d-bfeb-4bb9-881f-48301a7b6a38

[gov]
default_region     = us-gov-west-1
keycloak_base      = https://keycloak.identity.gov.msap.io
aws_client_id      = urn:amazon:webservices:govcloud
aws_client_secret  = 795ec9c1-f35a-4f38-aa88-1e9452f0cb5a

[gov.mst]
keycloak_base      = https://keycloak.identity.gov.msap.io
aws_client_id      = urn:amazon:webservices
aws_client_secret  = a852b49d-9e02-4f2c-b053-31900c70c597
EOF
  fi
}

remove_awskeycloak() {
  uninstall aws-keycloak
}


## test that INSTALL_DIR is writeable
touch $INSTALL_DIR/provision-write-test.$$ 2>/dev/null
if [[ $? -ne 0 ]]; then
  echo "ERROR: $INSTALL_DIR not writeable by your user account - exiting!"
  exit 1
fi
rm -f $INSTALL_DIR/provision-write-test.$$ 2>/dev/null

echo "Enter password when prompted for sudo (required for docker and awscli)."
sudo whoami > /dev/null

for item in awscli awskeycloak docker kubectl kind helm jq gh tele; do
  if [[ "$REMOVE" == "yes" ]]; then
    printf "Removing %-36s" "$blue$item$normal from system."
    remove_${item}
    success
  else
    printf "Checking %-36s" "$blue$item$normal version."
    if test_${item}; then
      success
    else
      fail
      if [[ ! "$CHECK" == "YES" ]]; then
        install_${item}
        printf "Verifying %-36s" "$blue$item$normal version."
        if test_${item}; then
          success
        else
          fail
        fi
      fi
    fi
  fi
done
printf "\n"
