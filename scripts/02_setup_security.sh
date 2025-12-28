#!/usr/bin/env bash
# 02_setup_security.sh - Configure Jenkins security and admin user

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source /tmp/jenkins-setup-env.sh
source "$SCRIPT_DIR/utils.sh"

export ADMIN_USER="admin"
export ADMIN_PASS="admin"
export DEFAULT_PORT=8080
export CLI_JAR="jenkins-cli.jar"

echo ""
log_info "=========================================="
log_info "STEP 2: Setting Up Security"
log_info "=========================================="
echo ""

########################################
# DETECT JENKINS URL
########################################
detect_environment

########################################
# WAIT FOR INITIAL JENKINS START
########################################
wait_for_jenkins_http

########################################
# DOWNLOAD CLI
########################################
log_info "Downloading Jenkins CLI..."
curl -sf -o "$CLI_JAR" "$JENKINS_URL/jnlpJars/jenkins-cli.jar"
log_success "Jenkins CLI downloaded"

########################################
# SETUP SECURITY GROOVY SCRIPT
########################################
log_info "Creating security configuration..."
INIT_DIR="$JENKINS_HOME/init.groovy.d"

if [[ "$PLATFORM" == "mac" ]]; then
  mkdir -p "$INIT_DIR"
  chmod 755 "$INIT_DIR"
else
  sudo mkdir -p "$INIT_DIR"
fi

SECURITY_GROOVY="$INIT_DIR/00-security.groovy"

# Remove existing file if owned by root
if [[ -f "$SECURITY_GROOVY" ]]; then
  if [[ "$PLATFORM" == "mac" ]]; then
    rm -f "$SECURITY_GROOVY" 2>/dev/null || sudo rm -f "$SECURITY_GROOVY"
  else
    sudo rm -f "$SECURITY_GROOVY"
  fi
fi

# Create security script
SECURITY_SCRIPT='
import jenkins.model.*
import hudson.security.*
import jenkins.install.*

def j = Jenkins.get()
j.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)

def realm = new HudsonPrivateSecurityRealm(false)
if (realm.getUser("admin") == null) {
  realm.createAccount("admin", "admin")
}
j.setSecurityRealm(realm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
j.setAuthorizationStrategy(strategy)

j.save()
'

if [[ "$PLATFORM" == "mac" ]]; then
  echo "$SECURITY_SCRIPT" > "$SECURITY_GROOVY"
else
  echo "$SECURITY_SCRIPT" | sudo tee "$SECURITY_GROOVY" >/dev/null
fi

log_success "Security configuration created"

########################################
# RESTART TO APPLY SECURITY
########################################
restart_jenkins "to apply security"

log_success "Security setup completed"
log_info "Admin credentials: $ADMIN_USER / $ADMIN_PASS"
echo ""

# Export for next scripts
echo "export JENKINS_URL=$JENKINS_URL" >> /tmp/jenkins-setup-env.sh
echo "export ADMIN_USER=$ADMIN_USER" >> /tmp/jenkins-setup-env.sh
echo "export ADMIN_PASS=$ADMIN_PASS" >> /tmp/jenkins-setup-env.sh
echo "export CLI_JAR=$CLI_JAR" >> /tmp/jenkins-setup-env.sh

exit 0
