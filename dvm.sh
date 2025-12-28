#!/bin/bash

# Replace hardcoded paths with dynamic paths
ADMIN_PASSWORD_PATH="$HOME/.jenkins/secrets/initialAdminPassword"
GROOVY_SCRIPT_DIR="$HOME/.jenkins/init.groovy.d"
JENKINS_CLI_JAR="$HOME/.jenkins/war/WEB-INF/jenkins-cli.jar"

# Update and install dependencies
echo "Updating system and installing dependencies..."
brew update
brew install jenkins-lts

# Start Jenkins
echo "Starting Jenkins service..."
brew services start jenkins-lts

# Wait for Jenkins to initialize
echo "Waiting for Jenkins to initialize..."
sleep 30

# Retrieve the initial admin password
echo "Fetching initial admin password..."
ADMIN_PASSWORD=$(cat "$ADMIN_PASSWORD_PATH" 2>/dev/null)

if [ -z "$ADMIN_PASSWORD" ]; then
  echo "Initial Admin Password file not found. Jenkins may not have started properly."
  exit 1
else
  echo "Initial Admin Password: $ADMIN_PASSWORD"
fi

# Automate Jenkins configuration using Groovy script
echo "Configuring Jenkins with default admin credentials and plugins..."
mkdir -p "$GROOVY_SCRIPT_DIR"
cat <<EOL > "$GROOVY_SCRIPT_DIR/basic-setup.groovy"
import jenkins.model.*
import hudson.security.*
import hudson.util.*
import jenkins.install.*

def instance = Jenkins.getInstance()

// Create admin user
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "admin")
instance.setSecurityRealm(hudsonRealm)

// Set authorization strategy
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

// Install plugins
def pluginManager = instance.getPluginManager()
def updateCenter = instance.getUpdateCenter()
updateCenter.updateAllSites()

def plugins = ["git", "pipeline", "workflow-aggregator", "blueocean"]
plugins.each { plugin ->
    if (!pluginManager.getPlugin(plugin)) {
        def pluginInstall = updateCenter.getPlugin(plugin)
        if (pluginInstall) {
            pluginInstall.deploy()
        }
    }
}

// Mark Jenkins as fully initialized
instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)
instance.save()
EOL

# Restart Jenkins to apply the configuration
echo "Restarting Jenkins to apply configuration..."
brew services restart jenkins-lts

# Wait for Jenkins to fully initialize
echo "Waiting for Jenkins to fully initialize..."
sleep 30

# Verify Jenkins is up and running
if ! curl -s -f -o /dev/null "$JENKINS_URL/login"; then
  echo "Jenkins is not accessible. Please check the installation."
  exit 1
fi

# Wait for Jenkins to be ready
JENKINS_URL="http://localhost:8080"
echo "Waiting for Jenkins to be ready..."
while ! curl -s --head  --request GET "$JENKINS_URL/login" | grep "200 OK" > /dev/null; do 
    echo "Jenkins is not ready yet. Retrying in 10 seconds..."
    sleep 10
done

echo "Jenkins is ready. Proceeding with configuration..."

# Ensure Groovy script is applied correctly
if [ ! -f "$GROOVY_SCRIPT_DIR/basic-setup.groovy" ]; then
    echo "Groovy script not found. Recreating it..."
    mkdir -p "$GROOVY_SCRIPT_DIR"
    cat <<EOL > "$GROOVY_SCRIPT_DIR/basic-setup.groovy"
import jenkins.model.*
import hudson.security.*
import hudson.util.*
import jenkins.install.*

def instance = Jenkins.getInstance()

// Create admin user
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "admin")
instance.setSecurityRealm(hudsonRealm)

// Set authorization strategy
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

// Install plugins
def pluginManager = instance.getPluginManager()
def updateCenter = instance.getUpdateCenter()
updateCenter.updateAllSites()

def plugins = ["git", "pipeline", "workflow-aggregator", "blueocean"]
plugins.each { plugin ->
    if (!pluginManager.getPlugin(plugin)) {
        def pluginInstall = updateCenter.getPlugin(plugin)
        if (pluginInstall) {
            pluginInstall.deploy()
        }
    }
}

// Mark Jenkins as fully initialized
instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)
instance.save()
EOL
fi

# Restart Jenkins to apply the configuration
echo "Restarting Jenkins to apply configuration..."
brew services restart jenkins-lts

# Wait for Jenkins to fully initialize
echo "Waiting for Jenkins to fully initialize..."
sleep 30

# Verify Jenkins is up and running
if ! curl -s -f -o /dev/null "$JENKINS_URL/login"; then
  echo "Jenkins is not accessible. Please check the installation."
  exit 1
fi

# Create a job/pipeline using the provided XML configuration
echo "Creating Jenkins job from jenkins_pipeline_config.xml..."
JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_PASS="admin"

# Use Jenkins CLI to create the job
curl -X POST -u "$JENKINS_USER:$JENKINS_PASS" \
    -H "Content-Type: application/xml" \
    --data-binary @jenkins_pipeline_config.xml \
    "$JENKINS_URL/createItem?name=MyPipeline"

# Force plugin installation using Jenkins CLI
PLUGINS=("git" "pipeline" "workflow-aggregator" "blueocean")
echo "Installing plugins using Jenkins CLI..."
for plugin in "${PLUGINS[@]}"; do
    curl -X POST -u "$JENKINS_USER:$JENKINS_PASS" \
        "$JENKINS_URL/pluginManager/installNecessaryPlugins" \
        --data "plugin.$plugin.default=true"
done

# Restart Jenkins after plugin installation
echo "Restarting Jenkins after plugin installation..."
brew services restart jenkins-lts

# Wait for Jenkins to fully initialize
echo "Waiting for Jenkins to fully initialize..."
sleep 30

# Use Jenkins CLI to set initialization state
JENKINS_CLI_JAR="$HOME/.jenkins/war/WEB-INF/jenkins-cli.jar"
JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_PASS="admin"

# Wait for Jenkins to be ready
echo "Waiting for Jenkins to be ready..."
while ! curl -s --head --request GET "$JENKINS_URL/login" | grep "200 OK" > /dev/null; do
    echo "Jenkins is not ready yet. Retrying in 10 seconds..."
    sleep 10
done

echo "Jenkins is ready. Proceeding with initialization..."

# Force Jenkins initialization using Groovy script
cat <<EOL > "$GROOVY_SCRIPT_DIR/force-initialization.groovy"
import jenkins.model.*
import jenkins.install.*

def instance = Jenkins.getInstance()
instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)
instance.save()
EOL

# Apply Groovy script using Jenkins CLI
java -jar "$JENKINS_CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASS" groovy = "$GROOVY_SCRIPT_DIR/force-initialization.groovy"

# Install plugins using CLI
PLUGINS=("git" "pipeline" "workflow-aggregator" "blueocean")
echo "Installing plugins using Jenkins CLI..."
for plugin in "${PLUGINS[@]}"; do
    java -jar "$JENKINS_CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASS" install-plugin "$plugin"
done

# Restart Jenkins after plugin installation
echo "Restarting Jenkins after plugin installation..."
brew services restart jenkins-lts

# Wait for Jenkins to fully initialize
echo "Waiting for Jenkins to fully initialize..."
sleep 30

echo "Jenkins setup is complete. Default credentials are:"
echo "Username: admin"
echo "Password: admin"
echo "Access Jenkins at: $JENKINS_URL"