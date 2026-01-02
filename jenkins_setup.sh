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
# HELPER FUNCTIONS
########################################
wait_for_jenkins_http() {
  echo "▶ Waiting for Jenkins HTTP..."
  local max_wait=120  # 2 minutes
  local waited=0
  until curl -sf "$JENKINS_URL/login" >/dev/null 2>&1; do
    if [ $waited -ge $max_wait ]; then
      echo "❌ Jenkins failed to start after ${max_wait} seconds"
      echo "   Check logs: tail -100 ~/.jenkins/jenkins.log"
      exit 1
    fi
    sleep 5
    waited=$((waited + 5))
  done
  echo "✅ Jenkins HTTP ready"
}

wait_for_jenkins_cli() {
  echo "▶ Waiting for Jenkins CLI readiness..."
  local max_wait=60  # 1 minute
  local waited=0
  until java -jar "$CLI_JAR" -s "$JENKINS_URL" \
    -auth "$ADMIN_USER:$ADMIN_PASS" \
    who-am-i >/dev/null 2>&1; do
    if [ $waited -ge $max_wait ]; then
      echo "❌ Jenkins CLI not ready after ${max_wait} seconds"
      exit 1
    fi
    sleep 5
    waited=$((waited + 5))
  done
  echo "✅ Jenkins CLI ready"
}

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
  # Check if Homebrew is installed
  if ! command -v brew >/dev/null 2>&1; then
    echo "▶ Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon
    if [[ $(uname -m) == "arm64" ]]; then
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  fi
  
  echo "▶ Installing Java, Jenkins, jq, git, terraform..."
  brew update
  brew install --quiet jenkins-lts openjdk jq git terraform 2>/dev/null || true
  brew services restart jenkins-lts
  export JAVA_HOME="$(brew --prefix openjdk)"
  export PATH="$JAVA_HOME/bin:$PATH"
  
else
  echo "▶ Installing Java, Jenkins, jq, git, awscli, terraform..."
  sudo apt update
  sudo apt install -y openjdk-17-jdk curl jq gnupg git awscli wget unzip
  
  # Install Terraform if not present
  if ! command -v terraform >/dev/null 2>&1; then
    echo "▶ Installing Terraform..."
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install -y terraform
  fi
  
  # Install Jenkins if not present
  if ! command -v jenkins >/dev/null 2>&1; then
    echo "▶ Installing Jenkins..."
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
      | sudo tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null
    
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
      https://pkg.jenkins.io/debian-stable binary/ \
      | sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null
    
    sudo apt update
    sudo apt install -y jenkins
  fi
  
  sudo systemctl enable jenkins
  sudo systemctl restart jenkins
  
  export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

echo "✅ Installed: Java $(java -version 2>&1 | head -n1), Git $(git --version | head -n1), Terraform $(terraform version | head -n1)"

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
wait_for_jenkins_http

########################################
# DOWNLOAD CLI (EARLY)
########################################
echo "▶ Downloading Jenkins CLI..."
curl -sf -o "$CLI_JAR" "$JENKINS_URL/jnlpJars/jenkins-cli.jar"

########################################
# INIT GROOVY (ADMIN + NO WIZARD)
########################################
echo "▶ Setting up security..."
INIT_DIR="$JENKINS_HOME/init.groovy.d"

if [[ "$PLATFORM" == "mac" ]]; then
  mkdir -p "$INIT_DIR"
  chmod 755 "$INIT_DIR"
else
  sudo mkdir -p "$INIT_DIR"
fi

SECURITY_GROOVY="$INIT_DIR/00-security.groovy"

# Remove existing file if it exists (might be owned by root)
if [[ -f "$SECURITY_GROOVY" ]]; then
  if [[ "$PLATFORM" == "mac" ]]; then
    rm -f "$SECURITY_GROOVY" 2>/dev/null || sudo rm -f "$SECURITY_GROOVY"
  else
    sudo rm -f "$SECURITY_GROOVY"
  fi
fi

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

wait_for_jenkins_http
wait_for_jenkins_cli

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

wait_for_jenkins_http
wait_for_jenkins_cli

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

# Retry loop for AWS credentials (max 6 attempts = 30 seconds)
MAX_RETRIES=6
RETRY_COUNT=0
AWS_CREDS_SUCCESS=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  echo "  Attempt $((RETRY_COUNT + 1))/$MAX_RETRIES..."
  
  # Run in background with manual timeout
  java -jar "$CLI_JAR" -s "$JENKINS_URL" \
    -auth "$ADMIN_USER:$ADMIN_PASS" \
    groovy = add-aws-creds.groovy &
  
  GROOVY_PID=$!
  
  # Wait up to 10 seconds for the command to complete
  WAIT_COUNT=0
  while [ $WAIT_COUNT -lt 10 ]; do
    if ! kill -0 $GROOVY_PID 2>/dev/null; then
      # Process finished
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

if [ "$AWS_CREDS_SUCCESS" = false ]; then
  echo "⚠️  Warning: Failed to add AWS credentials after $MAX_RETRIES attempts"
  echo "⚠️  You may need to add AWS credentials manually in Jenkins"
fi

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
# CREATE/UPDATE JOBS AND FOLDERS
########################################
echo "▶ Creating/updating jobs from $JOBS_DIR..."

# Function to create a folder
create_folder() {
  local folder_name="$1"
  
  if curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
    "$JENKINS_URL/job/$folder_name/api/json" >/dev/null 2>&1; then
    echo "  ✓ Folder exists: $folder_name"
  else
    echo "  ＋ Creating folder: $folder_name"
    curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
      -b "$COOKIE_JAR" \
      -H "$CRUMB_FIELD: $CRUMB_VALUE" \
      -H "Content-Type: application/xml" \
      --data-binary '<com.cloudbees.hudson.plugins.folder.Folder plugin="cloudbees-folder">
        <actions/>
        <description></description>
        <properties/>
        <folderViews class="com.cloudbees.hudson.plugins.folder.views.DefaultFolderViewHolder">
          <views>
            <hudson.model.AllView>
              <owner class="com.cloudbees.hudson.plugins.folder.Folder" reference="../../../.."/>
              <name>All</name>
              <filterExecutors>false</filterExecutors>
              <filterQueue>false</filterQueue>
            </hudson.model.AllView>
          </views>
          <tabBar class="hudson.views.DefaultViewsTabBar"/>
        </folderViews>
        <healthMetrics/>
      </com.cloudbees.hudson.plugins.folder.Folder>' \
      "$JENKINS_URL/createItem?name=$folder_name" >/dev/null 2>&1
  fi
}

# Function to create/update a job
create_or_update_job() {
  local job_xml="$1"
  local job_name="$2"
  local job_path="$3"  # e.g., "" or "job/templates" or "job/lab-dev"
  
  if curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
    "$JENKINS_URL/$job_path/job/$job_name/api/json" >/dev/null 2>&1; then
    
    echo "  ↻ Updating job: $job_path/$job_name"
    local response
    response=$(curl -s -w "\n%{http_code}" -u "$ADMIN_USER:$ADMIN_PASS" \
      -b "$COOKIE_JAR" \
      -H "$CRUMB_FIELD: $CRUMB_VALUE" \
      -H "Content-Type: application/xml" \
      --data-binary @"$job_xml" \
      "$JENKINS_URL/$job_path/job/$job_name/config.xml")
    local http_code=$(echo "$response" | tail -n 1)
    if [ "$http_code" != "200" ]; then
      echo "  ⚠️  Update failed (HTTP $http_code) - preserving existing job to keep build history"
      echo "      Fix: Manually delete job via Jenkins UI if you want to recreate it"
    fi
  else
    echo "  ＋ Creating job: $job_path/$job_name"
    local response
    response=$(curl -s -w "\n%{http_code}" -u "$ADMIN_USER:$ADMIN_PASS" \
      -b "$COOKIE_JAR" \
      -H "$CRUMB_FIELD: $CRUMB_VALUE" \
      -H "Content-Type: application/xml" \
      --data-binary @"$job_xml" \
      "$JENKINS_URL/$job_path/createItem?name=$job_name")
    local http_code=$(echo "$response" | tail -n 1)
    if [ "$http_code" != "200" ]; then
      echo "  ⚠️  Failed to create (HTTP $http_code)"
    fi
  fi
}

shopt -s nullglob

# Create folders first
if [ -d "$JOBS_DIR/TEMPLATES" ]; then
  create_folder "TEMPLATES"
fi
if [ -d "$JOBS_DIR/lab-dev" ]; then
  create_folder "lab-dev"
fi
if [ -d "$JOBS_DIR/lab-prod" ]; then
  create_folder "lab-prod"
fi

# Create/update jobs in TEMPLATES folder
if [ -d "$JOBS_DIR/TEMPLATES" ]; then
  for job_xml in "$JOBS_DIR/TEMPLATES"/*.xml; do
    JOB_NAME="$(basename "$job_xml" .xml)"
    create_or_update_job "$job_xml" "$JOB_NAME" "job/TEMPLATES"
  done
fi

# Create/update jobs in lab-dev folder
if [ -d "$JOBS_DIR/lab-dev" ]; then
  for job_xml in "$JOBS_DIR/lab-dev"/*.xml; do
    JOB_NAME="$(basename "$job_xml" .xml)"
    create_or_update_job "$job_xml" "$JOB_NAME" "job/lab-dev"
  done
fi

# Create/update jobs in lab-prod folder
if [ -d "$JOBS_DIR/lab-prod" ]; then
  for job_xml in "$JOBS_DIR/lab-prod"/*.xml; do
    JOB_NAME="$(basename "$job_xml" .xml)"
    create_or_update_job "$job_xml" "$JOB_NAME" "job/lab-prod"
  done
fi

# Create/update root level jobs (backward compatibility)
for job_xml in "$JOBS_DIR"/*.xml; do
  JOB_NAME="$(basename "$job_xml" .xml)"
  create_or_update_job "$job_xml" "$JOB_NAME" ""
done

########################################
# POST-SETUP INSTRUCTIONS
########################################
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ Jenkins Setup Complete!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "🔗 Jenkins URL: $JENKINS_URL"
echo "🔑 Username: $ADMIN_USER"
echo "🔑 Password: $ADMIN_PASS"
echo ""