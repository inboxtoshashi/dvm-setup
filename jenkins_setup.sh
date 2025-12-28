#!/bin/bash
set -euo pipefail

############################################
# CONFIG
############################################
JENKINS_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASS="admin"

CLI_JAR="jenkins-cli.jar"
COOKIE_JAR="cookies.txt"
JOBS_DIR="$PWD/jobs"

############################################
# INSTALL DEPENDENCIES
############################################
echo "Installing dependencies..."
brew update
brew install jenkins-lts jq openjdk@21

############################################
# JAVA (NO MANUAL SETUP, NO sudo)
############################################
JAVA_PREFIX="$(brew --prefix openjdk@21)"
export JAVA_HOME="$JAVA_PREFIX/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

echo "Using Java:"
"$JAVA_HOME/bin/java" -version

############################################
# START JENKINS
############################################
echo "Starting Jenkins..."
brew services start jenkins-lts

############################################
# WAIT FUNCTIONS
############################################
wait_for_http() {
  echo "Waiting for Jenkins HTTP..."
  until curl -s "$JENKINS_URL/login" >/dev/null; do
    sleep 5
  done
}

wait_for_core() {
  echo "Waiting for Jenkins core (JSON API)..."
  until curl -s -u "$ADMIN_USER:$ADMIN_PASS" \
    "$JENKINS_URL/api/json" | jq -e 'has("mode")' >/dev/null 2>&1; do
    sleep 5
  done
}

wait_for_cli() {
  echo "Waiting for Jenkins CLI..."
  local retries=60
  until "$JAVA_HOME/bin/java" -jar "$CLI_JAR" \
      -s "$JENKINS_URL" \
      -auth "$ADMIN_USER:$ADMIN_PASS" \
      who-am-i >/dev/null 2>&1; do
    retries=$((retries-1))
    if [ "$retries" -le 0 ]; then
      echo "❌ Jenkins CLI did not become ready"
      exit 1
    fi
    sleep 5
  done
  echo "✅ Jenkins CLI is ready"
}

wait_for_http
wait_for_core

############################################
# DOWNLOAD CLI
############################################
echo "Downloading Jenkins CLI..."
curl -s -o "$CLI_JAR" "$JENKINS_URL/jnlpJars/jenkins-cli.jar"

wait_for_cli

############################################
# INSTALL REQUIRED PLUGINS
############################################
echo "Installing plugins..."
"$JAVA_HOME/bin/java" -jar "$CLI_JAR" \
  -s "$JENKINS_URL" \
  -auth "$ADMIN_USER:$ADMIN_PASS" \
  install-plugin \
    workflow-aggregator \
    credentials \
    credentials-binding \
    aws-credentials

"$JAVA_HOME/bin/java" -jar "$CLI_JAR" \
  -s "$JENKINS_URL" \
  -auth "$ADMIN_USER:$ADMIN_PASS" safe-restart

wait_for_http
wait_for_core
wait_for_cli

############################################
# CREATE PLACEHOLDER AWS CREDENTIALS
############################################
echo "Creating placeholder AWS credentials..."

"$JAVA_HOME/bin/java" -jar "$CLI_JAR" \
  -s "$JENKINS_URL" \
  -auth "$ADMIN_USER:$ADMIN_PASS" groovy = <<'EOF'
import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.jenkins.plugins.awscredentials.AWSCredentialsImpl

def store = Jenkins.get()
  .getExtensionList(SystemCredentialsProvider.class)[0]
  .getStore()

def id = "aws-creds"

if (store.getCredentials(Domain.global()).any { it.id == id }) {
  println("aws-creds already exists")
  return
}

store.addCredentials(
  Domain.global(),
  new AWSCredentialsImpl(
    CredentialsScope.GLOBAL,
    id,
    "Placeholder AWS credentials",
    "DUMMY_ACCESS_KEY",
    "DUMMY_SECRET_KEY"
  )
)

println("aws-creds CREATED")
EOF

############################################
# CREATE / UPDATE JENKINS JOBS
############################################
echo "Creating / updating Jenkins jobs..."

CRUMB_JSON=$(curl -s -u "$ADMIN_USER:$ADMIN_PASS" -c "$COOKIE_JAR" \
  "$JENKINS_URL/crumbIssuer/api/json")

CRUMB_FIELD=$(echo "$CRUMB_JSON" | jq -r '.crumbRequestField')
CRUMB_VALUE=$(echo "$CRUMB_JSON" | jq -r '.crumb')

for jobfile in "$JOBS_DIR"/*.xml; do
  JOB_NAME=$(basename "$jobfile" .xml)
  echo "Processing job: $JOB_NAME"

  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "$ADMIN_USER:$ADMIN_PASS" \
    "$JENKINS_URL/job/$JOB_NAME/api/json")

  if [ "$STATUS" = "200" ]; then
    echo "Updating job: $JOB_NAME"
    curl -s \
      -u "$ADMIN_USER:$ADMIN_PASS" \
      -b "$COOKIE_JAR" \
      -H "$CRUMB_FIELD: $CRUMB_VALUE" \
      -H "Content-Type: application/xml" \
      --data-binary @"$jobfile" \
      "$JENKINS_URL/job/$JOB_NAME/config.xml"
  else
    echo "Creating job: $JOB_NAME"
    curl -s \
      -u "$ADMIN_USER:$ADMIN_PASS" \
      -b "$COOKIE_JAR" \
      -H "$CRUMB_FIELD: $CRUMB_VALUE" \
      -H "Content-Type: application/xml" \
      --data-binary @"$jobfile" \
      "$JENKINS_URL/createItem?name=$JOB_NAME"
  fi
done

rm -f "$COOKIE_JAR"

############################################
# DONE
############################################
echo
echo "✅ Jenkins automation COMPLETE"
echo "🔐 Login: admin / admin"
echo "📦 Jobs loaded from ./jobs"
echo "🔑 aws-creds placeholder created"
