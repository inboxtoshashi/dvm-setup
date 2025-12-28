# 🚀 Jenkins Bootstrap Automation

**Fully automated Jenkins setup for macOS, Ubuntu, and AWS EC2**

One command to install and configure Jenkins with pre-defined CI/CD jobs for infrastructure, application deployment, and monitoring.

---

## ✨ Features

- ✅ **Zero Manual Configuration** - Fully automated from installation to job creation
- ✅ **Multi-Platform Support** - macOS (Homebrew) and Ubuntu (systemd)
- ✅ **AWS EC2 Auto-Detection** - Automatically uses public IP when running on EC2
- ✅ **Complete Setup** - Jenkins + Java + All required plugins
- ✅ **Pre-configured Security** - Admin user (admin/admin) with proper authentication
- ✅ **AWS Credentials Ready** - Placeholder credentials automatically configured
- ✅ **Production-Ready Jobs** - Git clone, Terraform, and deployment pipelines included
- ✅ **Idempotent** - Safe to run multiple times without breaking existing setup
- ✅ **CLI Readiness Checks** - Robust waiting for Jenkins to be fully operational

---

## 🚦 Quick Start

### Prerequisites

- **macOS**: Homebrew installed
- **Ubuntu**: sudo access
- **Network**: Internet connection for downloading dependencies

### Installation

```bash
# Clone the repository
git clone <your-repo-url>
cd dvm-setup

# Run the main setup script
sh ./setup.sh
```

**That's it!** ☕ Grab a coffee while Jenkins installs (5-10 minutes)

The setup script will automatically:
1. ✅ Install dependencies
2. ✅ Configure security
3. ✅ Install plugins
4. ✅ Setup credentials
5. ✅ Create all jobs

Each step must succeed before proceeding to the next.

### Access Jenkins

- **Local**: http://localhost:8080
- **EC2**: http://YOUR_PUBLIC_IP:8080

**Credentials**: 
- Username: `admin`
- Password: `admin`

---

## 📁 Repository Structure

```
dvm-setup/
├── setup.sh                   # 🎯 Main orchestrator (run this!)
├── plugins.txt                # Jenkins plugins list
├── verify-aws-plugin.groovy   # AWS plugin verification
├── README.md                  # This file
├── scripts/                   # 📂 Modular setup scripts
│   ├── utils.sh               # Shared utility functions
│   ├── 01_install_dependencies.sh  # Install Jenkins & Java
│   ├── 02_setup_security.sh   # Configure admin user
│   ├── 03_install_plugins.sh  # Install all plugins
│   ├── 04_setup_credentials.sh # Setup AWS credentials
│   └── 05_create_jobs.sh      # Create Jenkins jobs
└── jobs/                      # Jenkins job definitions
    ├── Git_Code.xml           # Consolidated git clone job
    ├── deploy-infra.xml       # Deploy Terraform infrastructure
    ├── deploy-app.xml         # Deploy application
    ├── deploy-monitoring.xml  # Deploy monitoring stack
    └── destroy-infra.xml      # Destroy Terraform infrastructure
```

### Why Modular Scripts?

The new modular structure provides:
- ✅ **Better readability** - Each script has a single, clear purpose
- ✅ **Easier debugging** - Identify and fix issues in specific steps
- ✅ **Sequential execution** - Each step only runs if the previous succeeded
- ✅ **Reusable components** - Individual scripts can be run standalone
- ✅ **Progress tracking** - Clear visual feedback on what's happening

---

## 🔧 What Gets Installed

### System Packages
- **macOS**: jenkins-lts, openjdk, jq (via Homebrew)
- **Ubuntu**: jenkins, openjdk-17-jdk, curl, jq (via apt)

### Jenkins Plugins
All plugins listed in [plugins.txt](plugins.txt), including:
- Git, Pipeline, Workflow
- AWS Steps, Credentials
- Job DSL, Script Security
- And many more...

### Jenkins Jobs

| Job Name | Description | Parameters |
|----------|-------------|------------|
| **Git_Code** | Clone repositories with checkboxes | ☑️ App, ☑️ Terraform, ☑️ Monitoring |
| **deploy-infra** | Deploy Terraform infrastructure | Environment, AWS Region |
| **deploy-app** | Deploy application | Environment |
| **deploy-monitoring** | Deploy monitoring stack | - |
| **destroy-infra** | Destroy Terraform resources | Environment confirmation |

---

## 🎯 How It Works

### Bootstrap Process

1. **OS Detection** - Identifies macOS or Linux
1. **OS Detection** - Identifies macOS or Linux
2. **Install Dependencies** - Jenkins, Java (OpenJDK), jq
3. **Environment Detection** - Checks if running on EC2 or localhost
4. **Wait for HTTP** - Ensures Jenkins web interface is accessible
5. **Download CLI** - Gets jenkins-cli.jar for automation
6. **Security Setup** - Creates admin user and disables setup wizard
7. **First Restart** - Applies security configuration
8. **CLI Readiness Check** - Uses `who-am-i` command to verify Jenkins is ready
9. **Install Plugins** - Installs all plugins from plugins.txt
10. **Second Restart** - Activates plugins
11. **CLI Readiness Check** - Waits again for full readiness
12. **AWS Credentials** - Creates placeholder credentials (with retry logic)
13. **Create Jobs** - Imports all job definitions from jobs/ folder
14. **Cleanup** - Removes temporary files

### Readiness Verification

The script uses **robust CLI-based readiness checks** instead of relying on HTTP endpoints:

```bash
# Waits until Jenkins CLI responds successfully
java -jar jenkins-cli.jar -s $JENKINS_URL -auth admin:admin who-am-i
```

This ensures Jenkins is fully operational before proceeding.

---

## 🎨 Customization

### Add More Plugins

Edit [plugins.txt](plugins.txt):
```txt
workflow-job
workflow-cps
credentials
your-custom-plugin
another-plugin
```

Run the script again - it will install new plugins.

### Add Custom Jobs

1. Export job XML from Jenkins: `http://localhost:8080/job/YOUR_JOB/config.xml`
2. Save as `jobs/your-job.xml`
3. Run the script again - it will create/update the job

### Modify Existing Jobs

Edit any XML file in [jobs/](jobs/) and run the script again. Jobs will be updated (not recreated).

### Change Admin Credentials

Edit the script variables:
```bash
ADMIN_USER="yourusername"
ADMIN_PASS="yourpassword"
```

**Note**: Changes require a fresh Jenkins installation.

---

## 🔐 Security Notes

### Default Credentials
- **Username**: admin
- **Password**: admin

⚠️ **Change these in production!** Go to Jenkins → Manage Jenkins → Manage Users

### AWS Credentials
Placeholder credentials (`DUMMY`/`DUMMY`) are created with ID `aws-creds`.

**To update**:
1. Go to Jenkins → Manage Jenkins → Manage Credentials
2. Update the `aws-creds` entry with real AWS keys
3. Or use IAM roles on EC2 (recommended)

### CSRF Protection
CSRF protection is enabled by default. The script automatically handles CSRF tokens when creating jobs.

---

## 🐛 Troubleshooting

### Script Hangs During Execution

**Symptom**: Script stuck at "Adding placeholder AWS credentials..."

**Solution**: The script includes automatic retry logic with 10-second timeouts. If it still hangs:
```bash
# Stop the script
Ctrl+C

# Clean up Jenkins
brew services stop jenkins-lts  # macOS
sudo systemctl stop jenkins     # Ubuntu

# Remove init scripts
rm -f ~/.jenkins/init.groovy.d/00-security.groovy  # macOS
sudo rm -f /var/lib/jenkins/init.groovy.d/00-security.groovy  # Ubuntu

# Run again
sh ./jenkins_setup.sh
```

### Permission Denied Errors

**macOS**:
```bash
chmod 755 ~/.jenkins/init.groovy.d
```

**Ubuntu**:
```bash
sudo chown -R jenkins:jenkins /var/lib/jenkins
```

### Plugins Not Installing

**Check Java version**:
```bash
java -version  # Should be Java 11 or 17
```

**Manual plugin install**:
```bash
java -jar jenkins-cli.jar -s http://localhost:8080 \
  -auth admin:admin \
  install-plugin workflow-job
```

### Jobs Not Created

**Check CSRF token**:
```bash
curl -u admin:admin http://localhost:8080/crumbIssuer/api/json
```

**Manual job creation**:
```bash
curl -X POST -u admin:admin \
  -H "Content-Type: application/xml" \
  --data-binary @jobs/Git_Code.xml \
  "http://localhost:8080/createItem?name=Git_Code"
```

### AWS Credentials Failed

This is a non-critical warning. Add credentials manually:
1. Jenkins → Manage Jenkins → Manage Credentials
2. Add Credentials → AWS Credentials
3. ID: `aws-creds`

### Jenkins Won't Start

**macOS**:
```bash
brew services restart jenkins-lts
tail -f /usr/local/var/log/jenkins/jenkins.log
```

**Ubuntu**:
```bash
sudo systemctl restart jenkins
sudo journalctl -u jenkins -f
```

---

## 📚 Usage Examples

### Git_Code Job

Run to clone repositories:
1. Go to Jenkins → Git_Code → Build with Parameters
2. Check the repositories you want to clone:
   - ☑️ **CLONE_APP** - Application code
   - ☑️ **CLONE_TERRAFORM** - Infrastructure as Code  
   - ☑️ **CLONE_MONITORING** - Monitoring stack
3. Click **Build**

### Deploy Infrastructure

```bash
# Via Jenkins UI
1. Go to deploy-infra job
2. Set parameters: environment (dev/prod), region
3. Click Build

# Via CLI
java -jar jenkins-cli.jar -s http://localhost:8080 \
  -auth admin:admin \
  build deploy-infra -p environment=dev -p region=us-east-1
```

---

## 🔄 Re-running the Script

The script is **idempotent** - safe to run multiple times:

- ✅ Existing users won't be duplicated
- ✅ Plugins already installed will be skipped
- ✅ Jobs will be updated (not deleted)
- ✅ Credentials won't be overwritten if they exist

Use cases for re-running:
- Add new plugins to plugins.txt
- Update job definitions
- Fix configuration issues
- Add new jobs

---

## 🌍 EC2 Deployment

The script automatically detects EC2 and configures the public IP:

```bash
# On EC2 instance
git clone <your-repo-url>
cd dvm-setup
sh ./jenkins_setup.sh

# Jenkins will be available at:
# http://YOUR_EC2_PUBLIC_IP:8080
```

**Security Group**: Ensure port 8080 is open in your EC2 security group.

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📝 License

This project is licensed under the MIT License.

---

## 🙏 Acknowledgments

- Jenkins community for excellent documentation
- CloudBees for AWS plugins
- All contributors

---

## 📞 Support

- **Issues**: Open an issue in this repository
- **Documentation**: https://www.jenkins.io/doc/

---

**Made with ❤️ for DevOps automation**

### Add More Jobs

1. Create XML file in `jobs/` directory
2. Re-run `sh ./jenkins_setup.sh`

### Change Admin Password

Edit `jenkins_setup.sh`:
```bash
ADMIN_USER="admin"
ADMIN_PASS="your-password"
```

## AWS Credentials

The script creates placeholder AWS credentials with:
- **ID**: `aws-creds`
- **Access Key**: `DUMMY`
- **Secret Key**: `DUMMY`

**Replace these in Jenkins UI**:
1. Go to Jenkins → Manage Jenkins → Credentials
2. Update `aws-creds` with real values

## Troubleshooting

### Script hangs during plugin installation
- The script waits for Jenkins to be fully ready using `/crumbIssuer/api/json`
- This is the only reliable readiness signal
- Wait a few minutes for plugins to install

### Jobs not created
- Check that XML files exist in `jobs/` directory
- Re-run the script (it's idempotent)

### EC2 detection not working
- Ensure EC2 instance has public IP
- Check security group allows port 8080
- Verify IMDSv2 is not enforced (or update script)

## Environment Support

| Environment | Status | Notes |
|------------|--------|-------|
| macOS | ✅ | Requires Homebrew |
| Ubuntu 20.04+ | ✅ | Uses systemd |
| AWS EC2 | ✅ | Auto-detects public IP |
| CentOS/RHEL | ⚠️ | May need yum changes |
