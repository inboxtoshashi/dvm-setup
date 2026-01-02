# 🚀 Quick Start Guide - One Command Setup

**Jenkins CI/CD setup for macOS & Ubuntu in 1 command!**

---

## Installation (3 Easy Steps)

### Step 1: Run Setup Script ⚡

```bash
# Clone repository
git clone <your-repo-url> dvm-setup
cd dvm-setup

# Run automated setup (works on BOTH macOS & Ubuntu)
bash jenkins_setup.sh
```

**The script automatically installs:**
- ✅ Homebrew (macOS only, if needed)
- ✅ Java, Git, Terraform, jq, awscli
- ✅ Jenkins with all plugins
- ✅ All job templates and configurations
- ✅ Placeholder AWS credentials

**Wait time:** 5-10 minutes ☕

---

### Step 2: Configure AWS & SSH 🔐

#### A. AWS Credentials

**macOS:**
```bash
aws configure
```

**Ubuntu:**
```bash
sudo su - jenkins
aws configure
exit
```

Enter your:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., `us-east-1`)
- Output format (press Enter for default)

#### B. SSH Key Setup

**macOS:**
```bash
mkdir -p ~/.ssh
cp /path/to/url_app.pem ~/.ssh/
chmod 400 ~/.ssh/url_app.pem
```

**Ubuntu:**
```bash
sudo mkdir -p /var/lib/jenkins/.ssh
sudo cp /path/to/url_app.pem /var/lib/jenkins/.ssh/
sudo chown jenkins:jenkins /var/lib/jenkins/.ssh/url_app.pem
sudo chmod 400 /var/lib/jenkins/.ssh/url_app.pem
```

---

### Step 3: Verify & Deploy 🎯

#### Verify Setup

**Test AWS:**
```bash
# macOS
aws sts get-caller-identity

# Ubuntu
sudo su - jenkins -c 'aws sts get-caller-identity'
```

**Test SSH:**
```bash
# macOS
ssh -i ~/.ssh/url_app.pem ubuntu@YOUR_EC2_IP echo "SSH works"

# Ubuntu
sudo su - jenkins -c 'ssh -i ~/.ssh/url_app.pem ubuntu@YOUR_EC2_IP echo "SSH works"'
```

#### Deploy Application

1. Open Jenkins:
   - **Local:** http://localhost:8080
   - **EC2:** http://YOUR_PUBLIC_IP:8080

2. Login: `admin` / `admin`

3. Navigate: `lab-dev` → `deploy-url-app`

4. Click: **Build with Parameters**

5. Select options:
   - ✅ `DEPLOY_APP = true`
   - (Optional) Check other options as needed

6. Click: **Build**

7. Watch the magic happen! 🎉

---

## 📊 What's Created

### Jenkins Jobs

| Folder | Job | Purpose |
|--------|-----|---------|
| `TEMPLATES/` | Deploy-App | Deploy URL shortener application |
| `TEMPLATES/` | Deploy-Infra | Deploy AWS infrastructure via Terraform |
| `TEMPLATES/` | Deploy-Monitoring | Deploy Prometheus + Grafana |
| `lab-dev/` | deploy-url-app | DEV environment orchestrator |
| `lab-prod/` | deploy-url-app | PROD environment orchestrator |

---

## 🆘 Quick Troubleshooting

### Jenkins Won't Start?

**macOS:**
```bash
brew services restart jenkins-lts
tail -50 ~/.jenkins/jenkins.log
```

**Ubuntu:**
```bash
sudo systemctl status jenkins
sudo journalctl -u jenkins -n 50
```

### Terraform Not Found?

```bash
# Check installation
which terraform
terraform version

# If missing, manually install
# macOS: brew install terraform
# Ubuntu: (see AWS_EC2_DEPLOYMENT.md)
```

### AWS Credentials Error?

```bash
# Reconfigure
aws configure

# Test
aws sts get-caller-identity
```

### SSH Permission Denied?

```bash
# Fix permissions
chmod 400 ~/.ssh/url_app.pem  # macOS

sudo chmod 400 /var/lib/jenkins/.ssh/url_app.pem  # Ubuntu
sudo chown jenkins:jenkins /var/lib/jenkins/.ssh/url_app.pem  # Ubuntu
```

---

## 🔒 Important Notes

### Default Credentials
- Username: `admin`
- Password: `admin`
- **⚠️ CHANGE IN PRODUCTION!**

### Supported Platforms
- ✅ macOS (Intel & Apple Silicon)
- ✅ Ubuntu 20.04+
- ✅ AWS EC2 (Ubuntu)

### Only 2 Manual Steps Required
1. AWS credentials configuration
2. SSH key placement

**Everything else is 100% automated!**

---

## 📚 Additional Resources

- **[AWS_EC2_DEPLOYMENT.md](AWS_EC2_DEPLOYMENT.md)** - AWS EC2 detailed guide
- **[README.md](README.md)** - Full documentation
- **[USAGE_GUIDE.md](USAGE_GUIDE.md)** - Detailed usage instructions

---

## 🎯 Summary

```bash
# 1. One command to install everything
bash jenkins_setup.sh

# 2. Configure AWS (one-time)
aws configure

# 3. Copy SSH key (one-time)
cp url_app.pem ~/.ssh/ && chmod 400 ~/.ssh/url_app.pem

# 4. Deploy!
# Go to Jenkins UI → lab-dev/deploy-url-app → Build
```

**That's it! You're ready to deploy! 🚀**
