#!/usr/bin/env bash
set -euo pipefail

########################################
# CONFIG
########################################
JENKINS_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASS="admin"
JENKINS_HOME="${HOME}/.jenkins"
JOBS_DIR="$(pwd)/jobs"

COOKIE_JAR="cookies.txt"
CRUMB_JSON="crumb.json"
CLI_JAR="jenkins-cli.jar"

REQUIRED_PLUGINS=(
  workflow-job
  workflow-cps
  credentials
  credentials-binding
  aws-credentials
)

########################################
# OS DETECTION
########################################
OS="$(uname -s)"
if [[ "$OS" == "Darwin" ]]; then
  PLATFORM="mac"
elif [[ "$OS" == "Linux" ]]; then
  PLATFORM="linux"
else
  echo "❌ Unsupported OS: $OS"
  exit 1
fi

echo "▶ Detected platform: $PLATFORM"

########################################
# INSTALL DEPENDENCIES
########################################
install_deps_mac() {
  command -v brew >/dev/null || {
    echo "❌ Homebrew not installed"
    exit 1
  }

  brew update
  brew install jenkins-lts openjdk jq
  brew services restart jenkins-lts

  export JAVA_HOME="$(brew --prefix openjdk)"
  export PATH="$JAVA_HOME/bin:$PATH"
}

install_deps_linux() {
  sudo apt update
  sudo apt install -y \
    openjdk-17-jdk \
    curl \
    jq \
    gnupg

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
}

if [[ "$PLATFORM" == "mac" ]]; then
  install_deps_mac
else
  install_deps_linux
fi

java -version

########################################
# WAIT FOR JENKINS
########################################
echo "▶ Waiting for Jenkins HTTP..."
until curl -s "$JENKINS_URL/login" >/dev/null; do
  sleep 5
done
echo "✅ Jenkins HTTP ready"

########################################
# INIT GROOVY (ADMIN + NO WIZARD)
########################################
INIT_DIR="$JENKINS_HOME/init.groovy.d"
mkdir -p "$INIT_DIR"

cat <<'EOF' > "$INIT_DIR/00-basic-security.groovy"
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

echo "▶ Restarting Jenkins to apply security..."
if [[ "$PLATFORM" == "mac" ]]; then
  brew services restart jenkins-lts
else
  sudo systemctl restart jenkins
fi

echo "▶ Waiting for Jenkins after restart..."
until curl -s "$JENKINS_URL/login" >/dev/null; do
  sleep 5
done
echo "✅ Jenkins ready"

########################################
# JENKINS CLI
########################################
echo "▶ Downloading Jenkins CLI..."
curl -s -o "$CLI_JAR" "$JENKINS_URL/jnlpJars/jenkins-cli.jar"

########################################
# INSTALL PLUGINS
########################################
echo "▶ Installing plugins..."
for p in "${REQUIRED_PLUGINS[@]}"; do
  java -jar "$CLI_JAR" -s "$JENKINS_URL" \
    -auth "$ADMIN_USER:$ADMIN_PASS" \
    install-plugin "$p"
done

java -jar "$CLI_JAR" -s "$JENKINS_URL" \
  -auth "$ADMIN_USER:$ADMIN_PASS" safe-restart

echo "▶ Waiting for Jenkins after plugin restart..."
until curl -s "$JENKINS_URL/login" >/dev/null; do
  sleep 5
done
echo "✅ Plugins ready"

########################################
# ADD PLACEHOLDER AWS CREDS
########################################
cat <<'EOF' > add-aws-creds.groovy
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
  println("Created placeholder aws-creds")
} else {
  println("aws-creds already exists")
}
EOF

java -jar "$CLI_JAR" -s "$JENKINS_URL" \
  -auth "$ADMIN_USER:$ADMIN_PASS" \
  groovy = add-aws-creds.groovy

########################################
# CSRF CRUMB
########################################
curl -s -u "$ADMIN_USER:$ADMIN_PASS" \
  -c "$COOKIE_JAR" \
  "$JENKINS_URL/crumbIssuer/api/json" > "$CRUMB_JSON"

CRUMB_FIELD=$(jq -r '.crumbRequestField' "$CRUMB_JSON")
CRUMB_VALUE=$(jq -r '.crumb' "$CRUMB_JSON")

########################################
# CREATE / UPDATE JOBS
########################################
echo "▶ Processing jobs in $JOBS_DIR"

for job in "$JOBS_DIR"/*.xml; do
  NAME="$(basename "$job" .xml)"

  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "$ADMIN_USER:$ADMIN_PASS" \
    "$JENKINS_URL/job/$NAME/api/json")

  if [[ "$STATUS" == "200" ]]; then
    echo "↻ Updating job $NAME"
    curl -s -u "$ADMIN_USER:$ADMIN_PASS" \
      -b "$COOKIE_JAR" \
      -H "$CRUMB_FIELD: $CRUMB_VALUE" \
      -H "Content-Type: application/xml" \
      --data-binary @"$job" \
      "$JENKINS_URL/job/$NAME/config.xml"
  else
    echo "＋ Creating job $NAME"
    curl -s -u "$ADMIN_USER:$ADMIN_PASS" \
      -b "$COOKIE_JAR" \
      -H "$CRUMB_FIELD: $CRUMB_VALUE" \
      -H "Content-Type: application/xml" \
      --data-binary @"$job" \
      "$JENKINS_URL/createItem?name=$NAME"
  fi
done

########################################
# CLEANUP
########################################
rm -f "$COOKIE_JAR" "$CRUMB_JSON" add-aws-creds.groovy

echo
echo "✅ Jenkins setup COMPLETE"
echo "🔑 Login: admin / admin"
