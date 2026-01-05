#!/usr/bin/env bash
# 05_create_jobs.sh - Create Jenkins jobs from XML definitions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source /tmp/jenkins-setup-env.sh
source "$SCRIPT_DIR/utils.sh"

JOBS_DIR="$PROJECT_DIR/jobs"
COOKIE_JAR="/tmp/jenkins-cookies.txt"

echo ""
log_info "=========================================="
log_info "STEP 5: Creating Jobs"
log_info "=========================================="
echo ""

########################################
# VALIDATE JOBS DIRECTORY
########################################
if [[ ! -d "$JOBS_DIR" ]]; then
  log_error "Jobs directory not found: $JOBS_DIR"
  exit 1
fi

JOB_COUNT=$(find "$JOBS_DIR" -name "*.xml" | wc -l | tr -d ' ')
if [ "$JOB_COUNT" -eq 0 ]; then
  log_warning "No job XML files found in $JOBS_DIR"
  exit 0
fi

log_info "Found $JOB_COUNT job(s) to create/update"

########################################
# GET CSRF CRUMB
########################################
log_info "Getting CSRF token..."

CRUMB_RESPONSE=$(curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
  -c "$COOKIE_JAR" \
  "$JENKINS_URL/crumbIssuer/api/json")

CRUMB_FIELD=$(echo "$CRUMB_RESPONSE" | jq -r '.crumbRequestField')
CRUMB_VALUE=$(echo "$CRUMB_RESPONSE" | jq -r '.crumb')

log_success "CSRF token obtained"

########################################
# CREATE/UPDATE JOBS
########################################
log_info "Processing jobs..."

shopt -s nullglob
CREATED=0
UPDATED=0
FAILED=0

# First, create folders (TEMPLATES, lab-dev, lab-prod)
for folder in "$JOBS_DIR"/*/; do
  [ -d "$folder" ] || continue
  FOLDER_NAME="$(basename "$folder")"
  
  # Skip if it's not a directory or is hidden
  [[ "$FOLDER_NAME" == .* ]] && continue
  
  log_info "Ensuring folder exists: $FOLDER_NAME"
  
  # Check if folder exists in Jenkins
  if ! curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
    "$JENKINS_URL/job/$FOLDER_NAME/api/json" >/dev/null 2>&1; then
    
    # Create folder using Folder plugin XML with proper AllView configuration
    FOLDER_XML="<?xml version='1.1' encoding='UTF-8'?>
<com.cloudbees.hudson.plugins.folder.Folder plugin=\"cloudbees-folder\">
  <actions/>
  <description>$FOLDER_NAME folder</description>
  <properties/>
  <folderViews class=\"com.cloudbees.hudson.plugins.folder.views.DefaultFolderViewHolder\">
    <views>
      <hudson.model.AllView>
        <owner class=\"com.cloudbees.hudson.plugins.folder.Folder\" reference=\"../../../..\"/>
        <name>All</name>
        <filterExecutors>false</filterExecutors>
        <filterQueue>false</filterQueue>
        <properties class=\"hudson.model.View\$PropertyList\"/>
      </hudson.model.AllView>
    </views>
    <tabBar class=\"hudson.views.DefaultViewsTabBar\"/>
  </folderViews>
  <healthMetrics/>
</com.cloudbees.hudson.plugins.folder.Folder>"
    
    if echo "$FOLDER_XML" | curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
      -b "$COOKIE_JAR" \
      -H "$CRUMB_FIELD: $CRUMB_VALUE" \
      -H "Content-Type: application/xml" \
      --data-binary @- \
      "$JENKINS_URL/createItem?name=$FOLDER_NAME" >/dev/null 2>&1; then
      log_success "  ✓ Folder exists: $FOLDER_NAME"
    fi
  else
    log_success "  ✓ Folder exists: $FOLDER_NAME"
  fi
done

# Then, create jobs inside folders and at root
for folder in "$JOBS_DIR"/ "$JOBS_DIR"/*/; do
  for job_xml in "$folder"*.xml; do
    [ -f "$job_xml" ] || continue
    
    JOB_NAME="$(basename "$job_xml" .xml)"
    FOLDER_PATH=""
    
    # Determine if job is in a folder
    if [[ "$folder" != "$JOBS_DIR/" ]]; then
      FOLDER_NAME="$(basename "$(dirname "$job_xml")")"
      FOLDER_PATH="job/$FOLDER_NAME/"
      JOB_DISPLAY="$FOLDER_NAME/$JOB_NAME"
    else
      JOB_DISPLAY="$JOB_NAME"
    fi
    
    # Check if job exists
    if curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
      "$JENKINS_URL/${FOLDER_PATH}job/$JOB_NAME/api/json" >/dev/null 2>&1; then
      
      log_info "Updating: $JOB_DISPLAY"
      
      # Try to update first
      if curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
        -X POST \
        -b "$COOKIE_JAR" \
        -H "$CRUMB_FIELD: $CRUMB_VALUE" \
        -H "Content-Type: application/xml" \
        --data-binary @"$job_xml" \
        "$JENKINS_URL/${FOLDER_PATH}job/$JOB_NAME/config.xml" >/dev/null 2>&1; then
        UPDATED=$((UPDATED + 1))
        log_success "  ↻ Updated: $JOB_DISPLAY"
      else
        # If update fails, delete and recreate
        log_info "  Update failed, deleting and recreating..."
        curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
          -X POST \
          -b "$COOKIE_JAR" \
          -H "$CRUMB_FIELD: $CRUMB_VALUE" \
          "$JENKINS_URL/${FOLDER_PATH}job/$JOB_NAME/doDelete" >/dev/null 2>&1
        
        sleep 1
        
        if curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
          -b "$COOKIE_JAR" \
          -H "$CRUMB_FIELD: $CRUMB_VALUE" \
          -H "Content-Type: application/xml" \
          --data-binary @"$job_xml" \
          "$JENKINS_URL/${FOLDER_PATH}createItem?name=$JOB_NAME" >/dev/null; then
          CREATED=$((CREATED + 1))
          log_success "  ✓ Recreated: $JOB_DISPLAY"
        else
          FAILED=$((FAILED + 1))
          log_error "  ✗ Failed to recreate: $JOB_DISPLAY"
        fi
      fi
    else
      log_info "Creating: $JOB_DISPLAY"
      if curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
        -b "$COOKIE_JAR" \
        -H "$CRUMB_FIELD: $CRUMB_VALUE" \
        -H "Content-Type: application/xml" \
        --data-binary @"$job_xml" \
        "$JENKINS_URL/${FOLDER_PATH}createItem?name=$JOB_NAME" >/dev/null; then
        CREATED=$((CREATED + 1))
        log_success "  ✓ Created: $JOB_DISPLAY"
      else
        FAILED=$((FAILED + 1))
        log_error "  ✗ Failed: $JOB_DISPLAY"
      fi
    fi
  done
done

########################################
# CLEANUP
########################################
rm -f "$COOKIE_JAR"

########################################
# SUMMARY
########################################
echo ""
log_info "Job Summary:"
log_success "  Created: $CREATED"
log_success "  Updated: $UPDATED"
[ $FAILED -gt 0 ] && log_error "  Failed: $FAILED" || log_success "  Failed: 0"
echo ""

[ $FAILED -eq 0 ] && exit 0 || exit 1
