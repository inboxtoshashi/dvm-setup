#!/usr/bin/env bash
# 01_install_dependencies.sh - Install Jenkins and dependencies

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

echo ""
log_info "=========================================="
log_info "STEP 1: Installing Dependencies"
log_info "=========================================="
echo ""

########################################
# OS DETECTION
########################################
log_info "Detecting operating system..."
OS="$(uname -s)"

if [[ "$OS" == "Darwin" ]]; then
  export PLATFORM="mac"
  export JENKINS_HOME="$HOME/.jenkins"
  log_success "Platform: macOS"
elif [[ "$OS" == "Linux" ]]; then
  export PLATFORM="linux"
  export JENKINS_HOME="/var/lib/jenkins"
  log_success "Platform: Linux"
else
  log_error "Unsupported OS: $OS"
  exit 1
fi

########################################
# INSTALL PACKAGES
########################################
if [[ "$PLATFORM" == "mac" ]]; then
  log_info "Installing via Homebrew..."
  
  command -v brew >/dev/null || {
    log_error "Homebrew not installed. Install from https://brew.sh"
    exit 1
  }
  
  brew update
  brew install jenkins-lts openjdk jq
  brew services restart jenkins-lts
  
  export JAVA_HOME="$(brew --prefix openjdk)"
  export PATH="$JAVA_HOME/bin:$PATH"
  
else
  log_info "Installing via apt..."
  
  sudo apt update
  sudo apt install -y openjdk-17-jdk curl jq gnupg
  
  # Add Jenkins repository
  curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
    | sudo tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null
  
  echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/ \
    | sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null
  
  sudo apt update
  sudo apt install -y jenkins
  sudo systemctl enable jenkins
  sudo systemctl restart jenkins
  
  export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

########################################
# VERIFY INSTALLATION
########################################
log_info "Verifying Java installation..."
java -version

log_success "Dependencies installed successfully"
echo ""

# Export for next scripts
echo "export PLATFORM=$PLATFORM" > /tmp/jenkins-setup-env.sh
echo "export JENKINS_HOME=$JENKINS_HOME" >> /tmp/jenkins-setup-env.sh
echo "export JAVA_HOME=$JAVA_HOME" >> /tmp/jenkins-setup-env.sh
echo "export PATH=$JAVA_HOME/bin:\$PATH" >> /tmp/jenkins-setup-env.sh

exit 0
