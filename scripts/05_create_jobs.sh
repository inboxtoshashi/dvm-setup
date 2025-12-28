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

for job_xml in "$JOBS_DIR"/*.xml; do
  JOB_NAME="$(basename "$job_xml" .xml)"
  
  # Check if job exists
  if curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
    "$JENKINS_URL/job/$JOB_NAME/api/json" >/dev/null 2>&1; then
    
    log_info "Updating: $JOB_NAME"
    if curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
      -X POST \
      -b "$COOKIE_JAR" \
      -H "$CRUMB_FIELD: $CRUMB_VALUE" \
      -H "Content-Type: application/xml" \
      --data-binary @"$job_xml" \
      "$JENKINS_URL/job/$JOB_NAME/config.xml" >/dev/null 2>&1; then
      UPDATED=$((UPDATED + 1))
      log_success "  Updated: $JOB_NAME"
    else
      # Update failed, try delete and recreate
      log_warning "  Update failed, trying delete and recreate..."
      if curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
        -X POST \
        -b "$COOKIE_JAR" \
        -H "$CRUMB_FIELD: $CRUMB_VALUE" \
        "$JENKINS_URL/job/$JOB_NAME/doDelete" >/dev/null 2>&1; then
        sleep 2
        if curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
          -b "$COOKIE_JAR" \
          -H "$CRUMB_FIELD: $CRUMB_VALUE" \
          -H "Content-Type: application/xml" \
          --data-binary @"$job_xml" \
          "$JENKINS_URL/createItem?name=$JOB_NAME" >/dev/null 2>&1; then
          UPDATED=$((UPDATED + 1))
          log_success "  Recreated: $JOB_NAME"
        else
          FAILED=$((FAILED + 1))
          log_error "  Failed to recreate: $JOB_NAME"
        fi
      else
        FAILED=$((FAILED + 1))
        log_error "  Failed: $JOB_NAME"
      fi
    fi
  else
    log_info "Creating: $JOB_NAME"
    if curl -sf -u "$ADMIN_USER:$ADMIN_PASS" \
      -b "$COOKIE_JAR" \
      -H "$CRUMB_FIELD: $CRUMB_VALUE" \
      -H "Content-Type: application/xml" \
      --data-binary @"$job_xml" \
      "$JENKINS_URL/createItem?name=$JOB_NAME" >/dev/null; then
      CREATED=$((CREATED + 1))
      log_success "  Created: $JOB_NAME"
    else
      FAILED=$((FAILED + 1))
      log_error "  Failed: $JOB_NAME"
    fi
  fi
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
