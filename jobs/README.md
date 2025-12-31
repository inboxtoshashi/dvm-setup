# Jenkins Jobs Folder Structure

## Overview

This folder structure provides a safe, organized way to manage deployments across different environments.

```
jobs/
├── templates/                          # Template jobs with actual deployment logic
│   ├── git-infra-template.xml         # Clone infrastructure repo
│   ├── git-app-template.xml           # Clone app deployment repo
│   ├── git-monitoring-template.xml    # Clone monitoring repo
│   ├── deploy-infra-template.xml      # Deploy infrastructure (Terraform)
│   ├── deploy-app-template.xml        # Deploy URL Shortener app
│   ├── deploy-monitoring-template.xml # Deploy monitoring stack
│   └── destroy-infra-template.xml     # Destroy infrastructure
│
├── lab-dev/                           # DEV Environment Jobs
│   └── deploy-url-app.xml             # Main orchestrator job for DEV
│
└── lab-prod/                          # PROD Environment Jobs
    └── deploy-url-app.xml             # Main orchestrator job for PROD
```

## How It Works

### 1. Template Jobs
Located in `templates/` folder, these contain the actual deployment logic. They accept an `ENV` parameter to determine which environment to deploy to.

**Never run these directly!** They are called by the orchestrator jobs.

### 2. Lab-Specific Orchestrator Jobs
Each lab folder (`lab-dev/` and `lab-prod/`) contains ONE job: `deploy-url-app`

This job provides **checkboxes** to select what you want to execute:
- ☐ Git Clone Infrastructure
- ☐ Git Clone Application  
- ☐ Git Clone Monitoring
- ☐ Deploy Infrastructure
- ☐ Deploy Application
- ☐ Deploy Monitoring
- ☐ Destroy Infrastructure

When you check boxes and run the job, it triggers the corresponding template jobs with the correct environment (dev or prod).

## Usage

### Deploying to DEV

1. Go to Jenkins → **lab-dev** folder
2. Click on **deploy-url-app** job
3. Click "Build with Parameters"
4. Check the boxes for what you want to do:
   - ☑ Deploy Infrastructure
   - ☑ Deploy Application
   - ☑ Deploy Monitoring
5. Click "Build"

The job will automatically:
- Set `ENV=dev`
- Trigger the selected template jobs
- Deploy to the DEV environment

### Deploying to PROD

1. Go to Jenkins → **lab-prod** folder
2. Click on **deploy-url-app** job
3. Click "Build with Parameters"
4. Check the boxes for what you want to do
5. Click "Build"

The job will automatically:
- Set `ENV=prod`
- Trigger the selected template jobs
- Deploy to the PROD environment

## Safety Features

### Environment Isolation
- **Lab-based separation**: You physically go to the lab folder you want to deploy to
- **No environment confusion**: You can't accidentally deploy to prod when in lab-dev
- **Clear visual separation**: Folders are clearly labeled dev vs prod

### Confirmation for Destructive Actions
- **Destroy Infrastructure** requires manual confirmation
- Different confirmation messages for dev vs prod
- Extra warning for PROD destruction

## Common Workflows

### Initial Setup (New Environment)
```
1. Check: ☑ Deploy Infrastructure
2. Click Build
3. Wait for completion
4. Check: ☑ Deploy Application
5. Click Build
6. Check: ☑ Deploy Monitoring
7. Click Build
```

### Full Deployment (All at Once)
```
1. Check: ☑ Deploy Infrastructure
2. Check: ☑ Deploy Application
3. Check: ☑ Deploy Monitoring
4. Click Build
```

### Update Application Only
```
1. Check: ☑ Deploy Application
2. Click Build
```

### Add Monitoring to Existing Deployment
```
1. Check: ☑ Deploy Monitoring
2. Click Build
```

### Clone Repositories for Local Testing
```
1. Check: ☑ Git Clone Infrastructure
2. Check: ☑ Git Clone Application
3. Check: ☑ Git Clone Monitoring
4. Click Build
```

### Tear Down Environment
```
1. Check: ☑ Destroy Infrastructure
2. Click Build
3. Confirm when prompted
```

## Benefits

### 1. No Environment Mistakes
- You go to `lab-dev` → deploys to dev
- You go to `lab-prod` → deploys to prod
- No dropdown to accidentally select wrong environment

### 2. Flexible Execution
- Run all steps together
- Run individual steps
- Skip steps you don't need

### 3. Single Entry Point
- One job per environment
- Simple checkbox interface
- Clear and intuitive

### 4. Reusable Templates
- Template logic shared across environments
- Easy to update all environments
- Consistent deployment process

## Jenkins Setup

After updating job files, reload Jenkins configuration:

```bash
# Restart Jenkins container
docker restart jenkins

# Or reload configuration
# In Jenkins UI: Manage Jenkins → Reload Configuration from Disk
```

## Migration from Old Structure

If you have the old jobs (deploy-infra, deploy-app, etc.) at the root level:

1. They are now templates
2. Create new lab folders
3. Use the orchestrator jobs instead
4. Old jobs can be disabled/deleted

## Troubleshooting

### Job not found error
- Ensure template jobs exist in `/templates/` folder
- Check job names match exactly
- Reload Jenkins configuration

### Wrong environment deployed
- Check you're in the correct lab folder (dev vs prod)
- Verify the job shows correct environment in console output

### Template job failed
- Check the template job's console output
- Template jobs show detailed logs
- Fix the issue and re-run

## Best Practices

1. **Always work in the appropriate lab folder**
2. **Check the environment in console output** before confirming
3. **Test in dev first** before deploying to prod
4. **Use descriptive build notes** when running jobs
5. **Monitor console output** during deployment
6. **Don't modify template jobs** without testing in dev first

## Next Steps

To use this new structure:
1. Delete or disable old root-level jobs
2. Restart Jenkins
3. Navigate to lab-dev or lab-prod
4. Start using the new orchestrator jobs!
