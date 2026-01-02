# 🚀 Jenkins CI/CD - One-Command Setup

**Automated Jenkins installation for macOS & Ubuntu - From zero to deployed in 10 minutes!**

---

## ⚡ Quick Start

```bash
# Step 1: Clone and run (fully automated)
git clone <your-repo-url> dvm-setup
cd dvm-setup
bash jenkins_setup.sh

# Step 2: Configure AWS (one-time)
aws configure  # Enter your AWS credentials

# Step 3: Copy SSH key (one-time)  
cp /path/to/url_app.pem ~/.ssh/url_app.pem
chmod 400 ~/.ssh/url_app.pem

# Step 4: Deploy your app!
# Open http://localhost:8080
# Login: admin/admin
# Go to: lab-dev/deploy-url-app → Build
```

**That's it! Jenkins is ready with all jobs configured! 🎉**

---

## 🎯 What This Does

The `jenkins_setup.sh` script **automatically**:
- ✅ Installs all dependencies (Java, Git, Terraform, awscli)
- ✅ Installs Jenkins
- ✅ Configures security & creates admin user
- ✅ Installs all required plugins
- ✅ Creates all job templates and environment folders
- ✅ Sets up AWS credentials placeholder

**Only 2 manual steps needed:**
1. Your AWS credentials (secure, can't be automated)
2. Your SSH private key for EC2 access

---

## 💻 Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| macOS Intel | ✅ | Auto-installs Homebrew if missing |
| macOS Apple Silicon | ✅ | Handles ARM architecture |
| Ubuntu 20.04+ | ✅ | Uses apt & systemd |
| AWS EC2 Ubuntu | ✅ | Auto-detects public IP |

---

## 📚 Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - 3-step quick start guide
- **[AWS_EC2_DEPLOYMENT.md](AWS_EC2_DEPLOYMENT.md)** - Deploy on AWS EC2
- **[CHANGES_SUMMARY.md](CHANGES_SUMMARY.md)** - What changed & why
- **[USAGE_GUIDE.md](USAGE_GUIDE.md)** - Detailed usage instructions

---

## 🔍 What You Get

### Jenkins Jobs Created

```
TEMPLATES/
├── Deploy-App          → Deploy URL shortener application
├── Deploy-Infra        → Deploy AWS infrastructure (Terraform)
└── Deploy-Monitoring   → Deploy Prometheus + Grafana

lab-dev/
└── deploy-url-app      → DEV environment orchestrator

lab-prod/
└── deploy-url-app      → PROD environment orchestrator
```

### After Setup

1. Access Jenkins at `http://localhost:8080` (or EC2 IP)
2. Login with `admin` / `admin`
3. All jobs are ready to use immediately
4. Just configure AWS credentials and SSH key
5. Start deploying!

---

## 🐛 Troubleshooting

<details>
<summary><b>Jenkins not starting?</b></summary>

**macOS:**
```bash
brew services restart jenkins-lts
tail -100 ~/.jenkins/jenkins.log
```

**Ubuntu:**
```bash
sudo systemctl restart jenkins
sudo journalctl -u jenkins -n 100
```
</details>

<details>
<summary><b>AWS credentials not working?</b></summary>

```bash
# Reconfigure
aws configure

# Test
aws sts get-caller-identity
```
</details>

<details>
<summary><b>SSH key permission denied?</b></summary>

```bash
# Fix permissions
chmod 400 ~/.ssh/url_app.pem

# Ubuntu only - fix ownership
sudo chown jenkins:jenkins /var/lib/jenkins/.ssh/url_app.pem
```
</details>

---

## 🔐 Security

- Default credentials: `admin` / `admin` 
- **⚠️ Change these in production!**
- SSH keys must have `400` permissions
- AWS credentials are user-specific (never committed to repo)

---

## 🎓 How It Works

### Automated (No User Action)
1. Script detects OS (macOS or Ubuntu)
2. Installs package manager dependencies
3. Installs Java, Git, Terraform, Jenkins
4. Starts Jenkins service
5. Configures admin user & security
6. Installs plugins from `plugins.txt`
7. Creates all jobs from `jobs/` directory
8. Displays post-setup instructions

### Manual (User Provides)
1. **AWS credentials** - User's own AWS account
2. **SSH key** - For connecting to target EC2 instances

---

## 📦 Repository Structure

```
dvm-setup/
├── jenkins_setup.sh          # 🚀 Main automation script
├── plugins.txt               # Jenkins plugins to install
├── QUICKSTART.md             # Quick start guide
├── AWS_EC2_DEPLOYMENT.md     # AWS EC2 guide
├── CHANGES_SUMMARY.md        # Change documentation
└── jobs/                     # Jenkins job definitions
    ├── TEMPLATES/            # Reusable templates
    │   ├── Deploy-App.xml
    │   ├── Deploy-Infra.xml
    │   └── Deploy-Monitoring.xml
    ├── lab-dev/              # DEV environment
    │   └── deploy-url-app.xml
    └── lab-prod/             # PROD environment
        └── deploy-url-app.xml
```

---

## ⏱️ Time Savings

| Task | Manual | Automated |
|------|--------|-----------|
| Install dependencies | 20 min | 0 min ⚡ |
| Install & configure Jenkins | 15 min | 0 min ⚡ |
| Install plugins | 10 min | 0 min ⚡ |
| Create jobs | 15 min | 0 min ⚡ |
| Configure AWS | 5 min | 5 min |
| Setup SSH key | 2 min | 2 min |
| **TOTAL** | **67 min** | **7 min** 🚀 |

**90% time saved!**

---

## 🤝 Contributing

Issues and pull requests welcome!

---

## 📄 License

See LICENSE file for details.

---

**Made with ❤️ for automated DevOps workflows**

🌟 **Star this repo if it helped you!**
