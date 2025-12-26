#!/bin/bash

# Update the system
sudo apt-get update -y

# Install Java (required for Jenkins)
sudo apt-get install openjdk-11-jdk -y

# Install Docker
sudo apt-get install docker.io -y
sudo systemctl start docker
sudo systemctl enable docker

# Add Jenkins repository and key
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'

# Update and install Jenkins
sudo apt-get update -y
sudo apt-get install jenkins -y

# Start Jenkins service
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Print Jenkins initial admin password
echo "Jenkins is installed. Access it at http://<your-ec2-public-ip>:8080"
echo "Initial Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Install Git
sudo apt-get install git -y

# Pre-configure Jenkins pipeline
JENKINS_HOME="/var/lib/jenkins"
PIPELINE_SCRIPT="/var/lib/jenkins/jobs/Deploy_URL_App/config.xml"

sudo mkdir -p $(dirname "$PIPELINE_SCRIPT")

sudo cp /path/to/cloned/repo/dvm/jenkins_pipeline_config.xml "$PIPELINE_SCRIPT"

# Restart Jenkins to apply changes
sudo systemctl restart jenkins

# Print completion message
echo "Setup complete. Jenkins and Docker are installed, and the pipeline job is pre-configured."