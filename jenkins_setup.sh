#!/usr/bin/env bash
set -euo pipefail

########################################
# CONFIG
########################################
ADMIN_USER="admin"
ADMIN_PASS="admin"
DEFAULT_PORT=8080

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBS_DIR="$SCRIPT_DIR/jobs"
PLUGINS_FILE="$SCRIPT_DIR/plugins.txt"

CLI_JAR="jenkins-cli.jar"
COOKIE_JAR="cookies.txt"

########################################
# OS DETECTION
########################################
OS="$(uname -s)"
if [[ "$OS" == "Darwin" ]]; then
  PLATFORM="mac"
  JENKINS_HOME="$HOME/.jenkins"
elif [[ "$OS" == "Linux" ]]; then
  PLATFORM="linux"
  JENKINS_HOME="/var/lib/jenkins"
else
  echo "❌ Unsupported OS: $OS"
  exit 1
fi

echo "▶ Detected platform: $PLATFORM"

########################################
# INSTALL DEPENDENCIES
########################################
echo "▶ Installing dependencies..."

if [[ "$PLATFORM" == "mac" ]]; then
  command -v brew >/dev/null || {
    echo "❌ Homebrew not installed"
    exit 1
  }
  brew update
  brew install jenkins-lts openjdk jq
  brew services restart jenkins-lts
  export JAVA_HOME="$(brew --prefix openjdk)"
  export PATH="$JAVA_HOME/bin:$PATH"
else
  sudo apt update
  sudo apt install -y openjdk-17-jdk curl jq gnupg
  
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

java -version

########################################
# DETECT JENKINS URL
########################################
echo "▶ Detecting Jenkins URL..."
if curl -s --connect-timeout 2 http://169.254.169.254/latest/meta-data/public-ipv4 >/dev/null 2>&1; then
  PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
  JENKINS_URL="http://$PUBLIC_IP:$DEFAULT_PORT"
  echo "  Running on EC2: $JENKINS_URL"
else
  JENKINS_URL="http://localhost:$DEFAULT_PORT"
  echo "  Running locally: $JENKINS_URL"
fi

########################################
# WAIT FOR JENKINS HTTP
########################################
echo "▶ Waiting for Jenkins HTTP..."
until curl -sf "$JENKINS_URL/login" >/dev/null 2>&1; do
  sleep 5
done
echo "✅ Jenkins HTTP ready"

########################################
# INIT GROOVY (ADMIN + NO WIZARD)
########################################
echo "▶ Setting up security..."
INIT_DIR="$JENKINS_HOME/init.groovy.d"

if [[ "$PLATFORM" == "mac" ]]; then
  mkdir -p "$INIT_DIR"
else
  sudo mkdir -p "$INIT_DIR"
fi

SECURITY_GROOVY="$INIT_DIR/00-security.groovy"

if [[ "$PLATFORM" == "mac" ]]; then
  cat > "$SECURITY_GROOVY" <<'EOF'
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
EOF
else
  sudo tee "$SECURITY_GROOVY" >/dev/null <<'EOF'
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
EOF
fi

########################################
# RESTART JENKINS
########################################
echo "▶ Restarting Jenkins to apply security..."
if [[ "$PLATFORM" == "mac" ]]; then
  brew services restart jenkins-lts
else
  sudo systemctl restart jenkins
fi

echo "▶ Waiting for Jenkins to be ready (checking crumbIssuer)..."
until curl -sf -u "$ADMIN_USER:$ADMIN_PASS" "$JENKINS_URL/crumbIssuer/api/json" >/dev/null 2>&1; do
  sleep 5
done
echo "✅ Jenkins ready with authentication"

########################################
# DOWNLOAD CLI
########################################
echo "▶ Downloading Jenkins CLI..."
curl -sf -o "$CLI_JAR" "$JENKINS_URL/jnlpJars/jenkins-cli.jar"

########################################
# INSTALL PLUGINS FROM FILE
########################################
echo "▶ Installing plugins from $PLUGINS_FILE..."

if [[ ! -f "$PLUGINS_FILE" ]]; then
  echo "❌ $PLUGINS_FILE not found"
  exit 1
fi

# Install all plugins in one command
java -jar "$CLI_JAR" -s "$JENKINS_URL" \
  -auth "$ADMIN_USER:$ADMIN_PASS" \
  install-plugin $(cat "$PLUGINS_FILE")

echo "▶ Restarting Jenkins after plugin installation..."
java -jar "$CLI_JAR" -s "$JENKINS_URL" \
  -auth "$ADMIN_USER:$ADMIN_PASS" \
  safe-restart

echo "▶ Waiting for Jenkins to be ready (checking crumbIssuer)..."
until curl -sf -u "$ADMIN_USER:$ADMIN_PASS" "$JENKINS_URL/crumbIssuer/api/json" >/dev/null 2>&1; do
  sleep 5
done
echo "✅ Plugins installed and Jenkins ready"

########################################
# ADD PLACEHOLDER AWS CREDS
########################################
echo "▶ Adding placeholder AWS credentials..."
cat > add-aws-creds.groovy <<'EOF'
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

java -jar "$CLI_JAR" -s "$JENKINS_URL" \
  -auth "$ADMIN_USER:$ADMIN_PASS" \
  groovy = add-aws-creds.groovy

rm -f add-aws-creds.groovy

########################################
# GET CSRF CRUMB
########################################
echo "▶ Getting CSRF crumb..."
CRUMB_RESPONSE=$(curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
  -c "$COOKIE_JAR" \
  "$JENKINS_URL/crumbIssuer/api/json")

CRUMB_FIELD=$(echo "$CRUMB_RESPONSE" | jq -r '.crumbRequestField')
CRUMB_VALUE=$(echo "$CRUMB_RESPONSE" | jq -r '.crumb')

########################################
# CREATE/UPDATE JOBS
########################################
echo "▶ Creating/updating jobs from $JOBS_DIR..."

shopt -s nullglob
for job_xml in "$JOBS_DIR"/*.xml; do
  JOB_NAME="$(basename "$job_xml" .xml)"
  
  # Check if job exists
  if curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
    "$JENKINS_URL/job/$JOB_NAME/api/json" >/dev/null 2>&1; then
    
    echo "  ↻ Updating job: $JOB_NAME"
    curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
      -b "$COOKIE_JAR" \
      -H "$CRUMB_FIELD: $CRUMB_VALUE" \
      -H "Content-Type: application/xml" \
      --data-binary @"$job_xml" \
      "$JENKINS_URL/job/$JOB_NAME/config.xml" >/dev/null
  else
    echo "  ＋ Creating job: $JOB_NAME"
    curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
      -b "$COOKIE_JAR" \
      -H "$CRUMB_FIELD: $CRUMB_VALUE" \
      -H "Content-Type: application/xml" \
      --data-binary @"$job_xml" \
      "$JENKINS_URL/createItem?name=$JOB_NAME" >/dev/null
  fi
done

########################################
# CLEANUP
########################################
rm -f "$COOKIE_JAR" "$CLI_JAR"

echo ""
echo "✅ Jenkins bootstrap complete!"
echo "🔗 URL: $JENKINS_URL"
echo "🔑 Login: $ADMIN_USER / $ADMIN_PASS"
echo ""
