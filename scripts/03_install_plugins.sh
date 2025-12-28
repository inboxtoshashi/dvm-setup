#!/usr/bin/env bash
# 03_install_plugins.sh - Install Jenkins plugins

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source /tmp/jenkins-setup-env.sh
source "$SCRIPT_DIR/utils.sh"

PLUGINS_FILE="$PROJECT_DIR/plugins.txt"

echo ""
log_info "=========================================="
log_info "STEP 3: Installing Plugins"
log_info "=========================================="
echo ""

########################################
# VALIDATE PLUGINS FILE
########################################
if [[ ! -f "$PLUGINS_FILE" ]]; then
  log_error "Plugins file not found: $PLUGINS_FILE"
  exit 1
fi

PLUGIN_COUNT=$(wc -l < "$PLUGINS_FILE" | tr -d ' ')
log_info "Found $PLUGIN_COUNT plugins to install"

########################################
# INSTALL PLUGINS
########################################
log_info "Installing plugins..."

java -jar "$CLI_JAR" -s "$JENKINS_URL" \
  -auth "$ADMIN_USER:$ADMIN_PASS" \
  install-plugin $(cat "$PLUGINS_FILE")

log_success "Plugins installed"

########################################
# RESTART JENKINS
########################################
log_info "Restarting Jenkins to activate plugins..."

java -jar "$CLI_JAR" -s "$JENKINS_URL" \
  -auth "$ADMIN_USER:$ADMIN_PASS" \
  safe-restart

wait_for_jenkins_http
wait_for_jenkins_cli

log_success "Plugins activated"
echo ""

exit 0
