#!/usr/bin/env bash
# 04_setup_credentials.sh - Setup AWS credentials

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source /tmp/jenkins-setup-env.sh
source "$SCRIPT_DIR/utils.sh"

echo ""
log_info "=========================================="
log_info "STEP 4: Setting Up Credentials"
log_info "=========================================="
echo ""

########################################
# CREATE AWS CREDENTIALS SCRIPT
########################################
log_info "Creating AWS credentials configuration..."

cat > /tmp/add-aws-creds.groovy <<'EOF'
import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.jenkins.plugins.awscredentials.*

def store = Jenkins.get()
  .getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0]
  .getStore()

def existing = CredentialsProvider.lookupCredentials(
  AWSCredentialsImpl.class,
  Jenkins.get(),
  null,
  null
).find { it.id == 'aws-creds' }

if (!existing) {
  store.addCredentials(Domain.global(),
    new AWSCredentialsImpl(
      CredentialsScope.GLOBAL,
      "aws-creds",
      "Placeholder AWS credentials",
      "DUMMY",
      "DUMMY"
    )
  )
  println("✅ Created placeholder aws-creds")
} else {
  println("✅ aws-creds already exists")
}
EOF

########################################
# APPLY AWS CREDENTIALS WITH RETRY
########################################
log_info "Applying AWS credentials..."

MAX_RETRIES=6
RETRY_COUNT=0
AWS_CREDS_SUCCESS=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  log_info "Attempt $((RETRY_COUNT + 1))/$MAX_RETRIES..."
  
  # Run in background with manual timeout
  java -jar "$CLI_JAR" -s "$JENKINS_URL" \
    -auth "$ADMIN_USER:$ADMIN_PASS" \
    groovy = /tmp/add-aws-creds.groovy &
  
  GROOVY_PID=$!
  
  # Wait up to 10 seconds
  WAIT_COUNT=0
  while [ $WAIT_COUNT -lt 10 ]; do
    if ! kill -0 $GROOVY_PID 2>/dev/null; then
      wait $GROOVY_PID
      if [ $? -eq 0 ]; then
        AWS_CREDS_SUCCESS=true
        break 2
      else
        break
      fi
    fi
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
  done
  
  # Kill if still running
  if kill -0 $GROOVY_PID 2>/dev/null; then
    kill -9 $GROOVY_PID 2>/dev/null
    wait $GROOVY_PID 2>/dev/null
  fi
  
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
    sleep 5
  fi
done

########################################
# CLEANUP
########################################
rm -f /tmp/add-aws-creds.groovy

if [ "$AWS_CREDS_SUCCESS" = true ]; then
  log_success "AWS credentials configured"
else
  log_warning "AWS credentials setup failed - you can add them manually"
fi

echo ""
exit 0
