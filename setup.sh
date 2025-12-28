#!/usr/bin/env bash
# setup.sh - Main orchestrator for Jenkins bootstrap

set -euo pipefail

########################################
# CONFIGURATION
########################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

########################################
# COLORS
########################################
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

########################################
# BANNER
########################################
clear
echo ""
echo -e "${BOLD}╔════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║    🚀 Jenkins Bootstrap Automation 🚀      ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Automated Jenkins setup for macOS & Ubuntu${NC}"
echo ""

########################################
# VALIDATE SCRIPTS
########################################
REQUIRED_SCRIPTS=(
  "utils.sh"
  "01_install_dependencies.sh"
  "02_setup_security.sh"
  "03_install_plugins.sh"
  "04_setup_credentials.sh"
  "05_create_jobs.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
  if [[ ! -f "$SCRIPTS_DIR/$script" ]]; then
    echo -e "${RED}❌ Missing required script: $script${NC}"
    exit 1
  fi
done

########################################
# CLEANUP OLD TEMP FILES
########################################
rm -f /tmp/jenkins-setup-env.sh
rm -f /tmp/jenkins-cookies.txt
rm -f /tmp/add-aws-creds.groovy

########################################
# EXECUTE SCRIPTS IN SEQUENCE
########################################
STEPS=(
  "01_install_dependencies.sh:Installing Jenkins and dependencies"
  "02_setup_security.sh:Configuring security and admin user"
  "03_install_plugins.sh:Installing Jenkins plugins"
  "04_setup_credentials.sh:Setting up AWS credentials"
  "05_create_jobs.sh:Creating Jenkins jobs"
)

TOTAL_STEPS=${#STEPS[@]}
CURRENT_STEP=0

for step_info in "${STEPS[@]}"; do
  CURRENT_STEP=$((CURRENT_STEP + 1))
  
  SCRIPT_NAME="${step_info%%:*}"
  DESCRIPTION="${step_info##*:}"
  
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}Step $CURRENT_STEP/$TOTAL_STEPS: $DESCRIPTION${NC}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  if bash "$SCRIPTS_DIR/$SCRIPT_NAME"; then
    echo -e "${GREEN}✅ Step $CURRENT_STEP completed successfully${NC}"
  else
    echo ""
    echo "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${RED}❌ Step $CURRENT_STEP failed: $DESCRIPTION${NC}"
    echo "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "${YELLOW}To retry, run: sh setup.sh${NC}"
    echo ""
    exit 1
  fi
done

########################################
# LOAD FINAL ENVIRONMENT
########################################
if [[ -f /tmp/jenkins-setup-env.sh ]]; then
  source /tmp/jenkins-setup-env.sh
fi

########################################
# SUCCESS BANNER
########################################
echo ""
echo -e "${BOLD}╔════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║       ✅ Bootstrap Complete! ✅             ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Jenkins is ready!${NC}"
echo ""
echo -e "${BOLD}Access Information:${NC}"
echo -e "  🔗 URL:      ${BLUE}${JENKINS_URL:-http://localhost:8080}${NC}"
echo -e "  👤 Username: ${BLUE}admin${NC}"
echo -e "  🔑 Password: ${BLUE}admin${NC}"
echo ""
echo -e "${YELLOW}⚠️  Remember to change the default password in production!${NC}"
echo ""
echo -e "${BOLD}Next Steps:${NC}"
echo -e "  1. Open Jenkins in your browser"
echo -e "  2. Log in with the credentials above"
echo -e "  3. Update AWS credentials (Manage Jenkins → Credentials)"
echo -e "  4. Run your first job!"
echo ""

########################################
# CLEANUP
########################################
rm -f /tmp/jenkins-setup-env.sh
rm -f /tmp/jenkins-cookies.txt

exit 0
