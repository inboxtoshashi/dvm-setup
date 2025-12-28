# Jenkins Setup Scripts - Quick Reference

## Main Command

```bash
sh ./setup.sh
```

This runs all steps in sequence. Each step must succeed before continuing.

---

## Individual Scripts

If you need to run individual steps (after initial setup):

### 1. Install Dependencies
```bash
bash scripts/01_install_dependencies.sh
```
- Installs Jenkins, Java, jq
- Works on macOS (Homebrew) and Ubuntu (apt)
- Creates environment file: `/tmp/jenkins-setup-env.sh`

### 2. Setup Security
```bash
bash scripts/02_setup_security.sh
```
- Creates admin user (admin/admin)
- Disables setup wizard
- Downloads Jenkins CLI
- Restarts Jenkins

### 3. Install Plugins
```bash
bash scripts/03_install_plugins.sh
```
- Installs all plugins from `plugins.txt`
- Restarts Jenkins to activate plugins
- Waits for CLI readiness

### 4. Setup Credentials
```bash
bash scripts/04_setup_credentials.sh
```
- Creates placeholder AWS credentials
- ID: `aws-creds`
- Access Key: `DUMMY`
- Secret Key: `DUMMY`

### 5. Create Jobs
```bash
bash scripts/05_create_jobs.sh
```
- Creates/updates all jobs from `jobs/*.xml`
- Handles CSRF protection automatically
- Shows summary of created/updated/failed jobs

---

## Utility Functions

The `scripts/utils.sh` file provides:

- `log_info()` - Blue info messages
- `log_success()` - Green success messages
- `log_warning()` - Yellow warning messages
- `log_error()` - Red error messages
- `wait_for_jenkins_http()` - Wait for HTTP endpoint
- `wait_for_jenkins_cli()` - Wait for CLI readiness
- `detect_environment()` - Detect EC2 vs localhost
- `restart_jenkins()` - Platform-aware restart

---

## Environment Variables

These are stored in `/tmp/jenkins-setup-env.sh` between steps:

```bash
PLATFORM          # mac or linux
JENKINS_HOME      # ~/.jenkins or /var/lib/jenkins
JAVA_HOME         # Path to Java installation
JENKINS_URL       # http://localhost:8080 or http://PUBLIC_IP:8080
ADMIN_USER        # admin
ADMIN_PASS        # admin
CLI_JAR           # jenkins-cli.jar
```

---

## Troubleshooting

### Script fails at specific step

Run that step individually with verbose output:
```bash
bash -x scripts/03_install_plugins.sh
```

### Need to reset environment

```bash
rm -f /tmp/jenkins-setup-env.sh
rm -f /tmp/jenkins-cookies.txt
sh ./setup.sh
```

### Check Jenkins logs

**macOS:**
```bash
tail -f /usr/local/var/log/jenkins/jenkins.log
```

**Ubuntu:**
```bash
sudo journalctl -u jenkins -f
```

---

## File Locations

| File | Purpose | Cleanup |
|------|---------|---------|
| `jenkins-cli.jar` | CLI tool | Kept for manual use |
| `/tmp/jenkins-setup-env.sh` | Environment variables | Auto-deleted |
| `/tmp/jenkins-cookies.txt` | Session cookies | Auto-deleted |
| `/tmp/add-aws-creds.groovy` | Temp groovy script | Auto-deleted |

---

## Exit Codes

- `0` - Success
- `1` - Failure (check logs for details)

Each script returns proper exit codes for error handling.
