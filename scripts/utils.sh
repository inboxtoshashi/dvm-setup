#!/usr/bin/env bash
# utils.sh - Shared utility functions

set -euo pipefail

########################################
# COLORS FOR OUTPUT
########################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}▶${NC} $1"
}

log_success() {
  echo -e "${GREEN}✅${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}⚠️${NC}  $1"
}

log_error() {
  echo -e "${RED}❌${NC} $1"
}

########################################
# WAIT FOR JENKINS HTTP
########################################
wait_for_jenkins_http() {
  log_info "Waiting for Jenkins HTTP..."
  local max_attempts=60
  local attempt=0
  
  until curl -sf "$JENKINS_URL/login" >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
      log_error "Jenkins HTTP did not become ready in time"
      return 1
    fi
    sleep 5
  done
  
  log_success "Jenkins HTTP ready"
}

########################################
# WAIT FOR JENKINS CLI
########################################
wait_for_jenkins_cli() {
  log_info "Waiting for Jenkins CLI readiness..."
  local max_attempts=60
  local attempt=0
  
  until java -jar "$CLI_JAR" -s "$JENKINS_URL" \
    -auth "$ADMIN_USER:$ADMIN_PASS" \
    who-am-i >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
      log_error "Jenkins CLI did not become ready in time"
      return 1
    fi
    sleep 5
  done
  
  log_success "Jenkins CLI ready"
}

########################################
# DETECT ENVIRONMENT
########################################
detect_environment() {
  log_info "Detecting environment..."
  
  # Set default port if not already set
  DEFAULT_PORT=${DEFAULT_PORT:-8080}
  
  # Try to get EC2 public IP with proper timeout and validation
  PUBLIC_IP=$(curl -s --connect-timeout 3 --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
  
  # Check if we got a valid IP address
  if [[ -n "$PUBLIC_IP" && "$PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    JENKINS_URL="http://$PUBLIC_IP:$DEFAULT_PORT"
    log_info "Running on EC2: $JENKINS_URL"
  else
    # Fall back to localhost
    JENKINS_URL="http://localhost:$DEFAULT_PORT"
    log_info "Running locally: $JENKINS_URL"
  fi
  
  export JENKINS_URL
  export DEFAULT_PORT
}

########################################
# RESTART JENKINS
########################################
restart_jenkins() {
  local reason="$1"
  log_info "Restarting Jenkins $reason..."
  
  if [[ "$PLATFORM" == "mac" ]]; then
    brew services restart jenkins-lts
  else
    sudo systemctl restart jenkins
  fi
  
  wait_for_jenkins_http
  wait_for_jenkins_cli
}
