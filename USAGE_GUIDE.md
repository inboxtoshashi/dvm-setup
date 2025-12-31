# How to Use the New Jenkins Folder Structure

## 🎯 The New Way: Lab-Based Deployment

No more confusion about dev vs prod! Simply go to the folder you want to deploy to.

## 📁 Structure

```
Jenkins Dashboard
├── 📁 templates/              ← Don't touch! (Template jobs)
├── 📁 lab-dev/               ← Go here for DEV deployments
│   └── 🔧 deploy-url-app     ← Click this
└── 📁 lab-prod/              ← Go here for PROD deployments
    └── 🔧 deploy-url-app     ← Click this
```

## 🚀 Step-by-Step: Deploy to DEV

### Step 1: Navigate to DEV Lab
```
Jenkins Dashboard → lab-dev → deploy-url-app
```

### Step 2: Click "Build with Parameters"
You'll see checkboxes:

```
Build Parameters:

☐ GIT_INFRA          - Clone Infrastructure Repository
☐ GIT_APP            - Clone Application Deployment Repository
☐ GIT_MONITORING     - Clone Monitoring Stack Repository
☐ DEPLOY_INFRA       - Deploy Infrastructure (Terraform - VPC, EC2, etc.)
☐ DEPLOY_APP         - Deploy URL Shortener Application
☐ DEPLOY_MONITORING  - Deploy Monitoring Stack (Prometheus, Grafana)
☐ DESTROY_INFRA      - ⚠️ DESTROY Infrastructure (Tear down everything)

[Build]
```

### Step 3: Select What You Want to Deploy

**For first-time setup:**
```
☑ DEPLOY_INFRA
☑ DEPLOY_APP
☑ DEPLOY_MONITORING
```

**Just monitoring:**
```
☑ DEPLOY_MONITORING
```

**Update app only:**
```
☑ DEPLOY_APP
```

### Step 4: Click "Build"

That's it! The job will:
- ✅ Automatically set `ENV=dev`
- ✅ Call the appropriate template jobs
- ✅ Deploy to DEV environment

## 🏭 Step-by-Step: Deploy to PROD

Same as DEV, but:

### Step 1: Navigate to PROD Lab
```
Jenkins Dashboard → lab-prod → deploy-url-app
```

### Step 2-4: Same as DEV

The job will automatically:
- ✅ Set `ENV=prod`
- ✅ Deploy to PROD environment

## 📊 Console Output Example

When you run the job, you'll see:

```
==========================================
🏗️  LAB-DEV DEPLOYMENT PIPELINE
==========================================
Environment: dev
Git Infra: false
Git App: false
Git Monitoring: false
Deploy Infra: true
Deploy App: true
Deploy Monitoring: true
Destroy Infra: false
==========================================

[Deploy Infrastructure] 🏗️ Deploying Infrastructure...
  ↳ Triggering: /templates/deploy-infra-template
  ↳ With ENV=dev
  ✅ Infrastructure deployed successfully!

[Deploy Application] 🚀 Deploying URL Shortener Application...
  ↳ Triggering: /templates/deploy-app-template
  ↳ With ENV=dev
  ✅ Application deployed successfully!

[Deploy Monitoring] 📊 Deploying Monitoring Stack...
  ↳ Triggering: /templates/deploy-monitoring-template
  ↳ With ENV=dev
  ✅ Monitoring deployed successfully!

==========================================
✅ LAB-DEV Pipeline completed successfully!
==========================================
```

## ❌ What You CAN'T Do Anymore

### ❌ Select wrong environment by mistake
Before (old way):
```
In deploy-app job:
Environment: [dev ▼]  ← Could select prod by mistake!
```

Now (new way):
```
You're in lab-dev folder → Always deploys to dev
You're in lab-prod folder → Always deploys to prod
```

### ❌ Run individual jobs and forget the order
Before (old way):
```
- deploy-infra ← Run this? Or that?
- deploy-app  ← In what order?
- deploy-monitoring ← Did I run infra first?
```

Now (new way):
```
One job with checkboxes:
☑ Deploy Infra
☑ Deploy App
☑ Deploy Monitoring

Click Build → Everything runs in correct order
```

## 🎨 Visual Comparison

### Old Way (Confusing)
```
Jenkins Dashboard
├── deploy-infra       [Environment: dev ▼]
├── deploy-app         [Environment: dev ▼]
├── deploy-monitoring  [Environment: dev ▼]
└── destroy-infra      [Environment: dev ▼]
     ⚠️  Easy to select prod by mistake!
```

### New Way (Safe)
```
Jenkins Dashboard
├── lab-dev/
│   └── deploy-url-app  ← Checkboxes for what to deploy
│                          Always uses dev
└── lab-prod/
    └── deploy-url-app  ← Checkboxes for what to deploy
                           Always uses prod
```

## 🔒 Safety Features

### 1. Folder Isolation
- Physical separation of dev and prod
- Can't accidentally deploy to wrong environment
- Clear visual indicator of which lab you're in

### 2. Confirmation for Destroy
```
☑ DESTROY_INFRA checked

Before destroying:
  ⚠️ Are you ABSOLUTELY SURE you want to DESTROY the DEV infrastructure?
  [Abort] [Yes, Destroy DEV]
```

For PROD:
```
  ⚠️⚠️⚠️ Are you ABSOLUTELY SURE you want to DESTROY the PRODUCTION infrastructure? ⚠️⚠️⚠️
  [Abort] [Yes, Destroy PRODUCTION]
```

### 3. Clear Labels
- Lab folders clearly labeled: `lab-dev` vs `lab-prod`
- Different emojis: 🏗️ for dev, 🏭 for prod
- Environment shown in console output

## 💡 Common Use Cases

### Use Case 1: First Time Setup
```
1. Go to: lab-dev/deploy-url-app
2. Check: ☑ DEPLOY_INFRA
         ☑ DEPLOY_APP
         ☑ DEPLOY_MONITORING
3. Build
4. Wait for completion
5. Access: http://<EC2_IP>:9090 (app)
6. Access: http://<EC2_IP>:3000 (grafana)
```

### Use Case 2: Update App Code
```
1. Go to: lab-dev/deploy-url-app
2. Check: ☑ DEPLOY_APP only
3. Build
```

### Use Case 3: Add Monitoring to Existing Deployment
```
1. Go to: lab-dev/deploy-url-app
2. Check: ☑ DEPLOY_MONITORING only
3. Build
```

### Use Case 4: Promote to Production
```
1. Test in dev first
2. Go to: lab-prod/deploy-url-app
3. Check: ☑ DEPLOY_INFRA
         ☑ DEPLOY_APP
         ☑ DEPLOY_MONITORING
4. Build
```

### Use Case 5: Tear Down Dev Environment
```
1. Go to: lab-dev/deploy-url-app
2. Check: ☑ DESTROY_INFRA only
3. Build
4. Confirm when prompted
```

## 📝 Quick Reference

| What I Want | Where to Go | What to Check |
|-------------|-------------|---------------|
| Deploy everything to dev | lab-dev/deploy-url-app | All deploy checkboxes |
| Deploy everything to prod | lab-prod/deploy-url-app | All deploy checkboxes |
| Update dev app | lab-dev/deploy-url-app | DEPLOY_APP only |
| Add monitoring to dev | lab-dev/deploy-url-app | DEPLOY_MONITORING only |
| Destroy dev | lab-dev/deploy-url-app | DESTROY_INFRA only |
| Destroy prod | lab-prod/deploy-url-app | DESTROY_INFRA only |

## 🎉 Benefits Summary

✅ **No more environment confusion** - Folder = Environment
✅ **Flexible execution** - Pick what you need
✅ **Single entry point** - One job per environment
✅ **Safe by design** - Can't deploy to wrong place
✅ **Clear and simple** - Just checkboxes
✅ **Complete control** - Run individual steps or all together

---

**Ready to deploy? Go to your lab folder and start checking boxes!** ✨
