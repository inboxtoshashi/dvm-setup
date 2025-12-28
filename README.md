# DVM-Setup: Jenkins Bootstrap Automation

Complete Jenkins automation for macOS, Ubuntu, and AWS EC2. Clone, run one script, get a fully working Jenkins with jobs.

## Features

✅ Zero manual steps  
✅ Works on macOS (Homebrew) and Linux (systemd)  
✅ Auto-detects AWS EC2 and uses public IP  
✅ Installs Jenkins, Java, and required plugins  
✅ Creates admin user (admin/admin)  
✅ Creates placeholder AWS credentials  
✅ Creates all jobs from XML files  
✅ Idempotent (safe to re-run)  

## Quick Start

```bash
git clone <your-repo-url>
cd dvm-setup
sh ./jenkins_setup.sh
```

That's it! Jenkins will be available at:
- **Local**: http://localhost:8080
- **EC2**: http://<public-ip>:8080

**Login**: admin / admin

## Repository Structure

```
dvm-setup/
├── jenkins_setup.sh      # Main bootstrap script
├── plugins.txt           # Jenkins plugins to install
├── jobs/                 # Job XML definitions
│   ├── git-infra.xml
│   ├── git-app.xml
│   ├── git-monitoring.xml
│   ├── deploy-infra.xml
│   ├── deploy-app.xml
│   ├── deploy-monitoring.xml
│   └── destroy-infra.xml
├── add-aws-creds.groovy  # (Generated during setup)
└── .gitignore
```

## How It Works

1. **Detects OS** (macOS or Linux)
2. **Installs dependencies** (Jenkins, Java, jq)
3. **Detects environment** (EC2 or local)
4. **Sets up security** (admin user, no wizard)
5. **Installs plugins** from `plugins.txt`
6. **Restarts Jenkins once**
7. **Waits for readiness** using `/crumbIssuer/api/json`
8. **Creates AWS credentials** (placeholder: DUMMY/DUMMY)
9. **Creates/updates all jobs** from `jobs/*.xml`

## Prerequisites

### macOS
- Homebrew installed
- Internet connection

### Ubuntu / EC2
- `sudo` access
- Internet connection

## Customization

### Add More Plugins

Edit `plugins.txt`:
```
workflow-job
workflow-cps
credentials
credentials-binding
aws-credentials
your-plugin-name
```

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

## License

MIT
