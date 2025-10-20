# Harness Pipeline Failure Diagnosis: Research Report

**Research Date:** 2025-01-19
**Context:** Diagnosing Harness CD pipeline failures, especially when errors don't appear in API responses
**Focus:** Best practices, API capabilities, and diagnostic workflows

---

## Executive Summary

Based on comprehensive research of Harness documentation and community resources, here are the key findings:

### Critical Discovery
**Harness has a significant gap between UI and API error visibility.** When pipelines fail during stage initialization with "systemUser" aborts, the actual error message is often **only visible in the UI execution console**, not in API responses. This is a known limitation that requires a multi-layered diagnostic approach.

### Recommended Diagnostic Pattern
1. ✅ **Start with Execution Graph API** - Get high-level status and identify failed nodes
2. ✅ **Use Log Service API** - Download step-level logs programmatically
3. ⚠️ **Fall back to UI Console** - For errors not exposed via API (stage initialization, artifact resolution)
4. ✅ **Check Delegate Task Logs** - For connector/artifact fetch failures

### Key Takeaway
**Do not rely solely on the Harness API for error diagnosis.** The API has known limitations around error reporting, especially for:
- Stage initialization failures
- Artifact resolution errors
- System-initiated aborts (abortedBy: "systemUser")
- Errors occurring before step execution begins

---

## 1. Harness API Endpoints for Logs and Errors

### 1.1 Log Service API (Primary Log Retrieval)

**Purpose:** Download pipeline, stage, and step execution logs programmatically

**Endpoint:**
```
POST https://app.harness.io/gateway/log-service/blob/download
```

**Authentication:**
```bash
-H 'x-api-key: <HARNESS-PERSONAL-ACCESS-TOKEN>'
```

**Parameters:**
- `accountID` - Your Harness account identifier
- `prefix` - Multi-part key identifying the execution/stage/step

**Prefix Key Formats:**

| Level | Format |
|-------|--------|
| **Pipeline** | `ACCOUNT_ID/pipeline/PIPELINE_ID/RUN_SEQUENCE/-PLAN_EXECUTION_ID` |
| **Stage** | `ACCOUNT_ID/pipeline/PIPELINE_ID/RUN_SEQUENCE/-PLAN_EXECUTION_ID/STAGE_ID` |
| **Step** | `ACCOUNT_ID/pipeline/PIPELINE_ID/RUN_SEQUENCE/-PLAN_EXECUTION_ID/STAGE_ID/STEP_ID` |

**Important Notes:**
- Note the hyphen (`-`) before `PLAN_EXECUTION_ID`
- `RUN_SEQUENCE` is the execution number (e.g., 1, 2, 3)
- `PLAN_EXECUTION_ID` is the unique execution identifier (from API or UI URL)

**Example - Download Pipeline Logs:**
```bash
curl 'https://app.harness.io/gateway/log-service/blob/download?accountID=_dYBmxlLQu61cFhvdkV4Jw&prefix=_dYBmxlLQu61cFhvdkV4Jw/pipeline/Deploy_Bagel_Store/42/-edde11c7890a' \
  -X 'POST' \
  -H 'content-type: application/json' \
  -H 'x-api-key: pat.xxxxx.yyyyy.zzzzz'
```

**Example - Download Step Logs:**
```bash
curl 'https://app.harness.io/gateway/log-service/blob/download?accountID=_dYBmxlLQu61cFhvdkV4Jw&prefix=_dYBmxlLQu61cFhvdkV4Jw/pipeline/Deploy_Bagel_Store/42/-edde11c7890a/deploy_dev/fetch_changelog' \
  -X 'POST' \
  -H 'content-type: application/json' \
  -H 'x-api-key: pat.xxxxx.yyyyy.zzzzz'
```

**Response:**
```json
{
  "link": "https://storage.googleapis.com/.../download?token=...",
  "status": "SUCCESS"
}
```

**Critical Limitations:**
- ⚠️ **Asynchronous endpoint** - File is only available after success status returned
- ⚠️ **Hard limit: 2000 log files per execution**
- ⚠️ **Returns empty/null for stages that never started execution** (initialization failures)

**Documentation:**
- [Download Execution Logs](https://developer.harness.io/docs/platform/pipelines/executions-and-logs/download-logs/)

---

### 1.2 Execution Graph API (Execution Status & Structure)

**Purpose:** Get structured representation of pipeline execution, including flow, dependencies, statuses, and outcomes

**Key Endpoints:**

#### A. Pipeline Execution Summary
```
GET https://app.harness.io/gateway/pipeline/api/pipelines/execution/summary
```

**Parameters:**
- `routingId` - Account identifier
- `accountIdentifier` - Account ID
- `projectIdentifier` - Project identifier
- `orgIdentifier` - Organization identifier
- `pipelineIdentifier` - Pipeline identifier
- `planExecutionId` - Execution ID

#### B. Execution Subgraph (Node-Level Details)
```
GET /executions/{executionId}/subgraph/{nodeExecutionId}
```

**Purpose:** Get detailed information about a specific node's execution (stage, step, step group)

**Response Structure:**
```json
{
  "executionGraph": {
    "nodeMap": {
      "node_id": {
        "uuid": "...",
        "name": "Step Name",
        "identifier": "step_identifier",
        "status": "Failed|Success|Aborted|Running",
        "failureInfo": {
          "message": "Error message text",
          "failureTypeList": ["AUTHENTICATION_ERROR", "..."],
          "responseMessages": []
        },
        "skipInfo": null,
        "nodeType": "Deployment|Execution|..."
      }
    }
  }
}
```

**failureInfo Fields:**
- `message` - Human-readable error description
- `failureTypeList` - Array of failure categories
- `responseMessages` - Additional error context

**Critical Discovery:**
- ✅ **Works well for step-level failures** (after execution begins)
- ⚠️ **Returns null/empty failureInfo for initialization failures**
- ⚠️ **Status shows "Aborted" but no error details for systemUser aborts**

**Alternative GraphQL API:**
```graphql
{
  execution(executionId: "xyz") {
    failureDetails {
      message
      code
    }
  }
}
```

**Documentation:**
- [Understanding Execution Graph API](https://developer.harness.io/docs/platform/pipelines/pipeline-execution-graph/)
- [Harness APIs](https://apidocs.harness.io/)

---

### 1.3 Delegate Task Logs (Connector & Artifact Failures)

**Purpose:** Access detailed delegate-side logs for connector validation and artifact fetch operations

**How to Access:**
1. Navigate to connector in Harness UI
2. Click "Connection Test" (for validation failures)
3. If `executeOnDelegate: true`, a **"View Delegate Tasks Logs"** option appears
4. Opens Delegate Task Logs dialog with Google StackDriver logs for the `taskId`

**Where These Logs Help:**
- ✅ Connector authentication failures
- ✅ Artifact repository connection issues
- ✅ Network connectivity problems
- ✅ GCP/AWS IAM permission errors
- ✅ Image tag fetch failures

**Example Use Case:**
```
Error: Failed to find artifact: changelog-main-edde11c

Where to look:
1. Check connector validation logs in UI
2. View delegate task logs for the artifact fetch operation
3. Verify GitHub connector credentials
4. Check artifact naming pattern in configuration
```

**Documentation:**
- [Troubleshooting Harness](https://developer.harness.io/docs/troubleshooting/troubleshooting-nextgen/)
- [CD Artifact Source FAQs](https://developer.harness.io/docs/continuous-delivery/x-platform-cd-features/services/cd-artifact-sources-faqs/)

---

## 2. Common Causes of "systemUser" Aborts

### 2.1 What is "systemUser"?

When `abortedBy: "systemUser"` appears in execution details, it indicates the **Harness platform itself** initiated the abort, not a human user. This is a **system-level automatic abort** triggered by:

1. **Stage initialization failures**
2. **Authentication/authorization failures**
3. **Resource unavailability** (delegate offline, infrastructure not found)
4. **Timeout during pre-execution setup**
5. **Artifact resolution failures** (missing artifacts, invalid tags)
6. **Configuration validation errors** (invalid YAML, missing variables)

### 2.2 Key Implementation Detail

**Abort Method:**
```java
io.harness.delegate.service.DelegateAgentServiceImpl#abortDelegateTask
```

Uses `Thread.interrupt()` to initiate abort process. The pipeline finishes its current task, then stops execution.

### 2.3 Why "systemUser" Instead of Clear Errors?

**Root Cause:** Harness aborts the stage during initialization **before error details are fully propagated** to the execution graph. This results in:

- ❌ Status: "Aborted"
- ❌ abortedBy: "systemUser"
- ❌ failureInfo: null or empty object
- ✅ **Actual error message: Only in UI console logs**

### 2.4 Common Scenarios

| Scenario | API Response | Where Error Appears |
|----------|-------------|---------------------|
| **Artifact not found** | `status: "Aborted"`, `abortedBy: "systemUser"`, `failureInfo: null` | UI console: "Failed to find artifact: xyz" |
| **Delegate offline** | `status: "Aborted"`, `abortedBy: "systemUser"` | UI console: "No delegate available" |
| **Infrastructure invalid** | `status: "Aborted"`, `abortedBy: "systemUser"` | UI console: "Infrastructure definition not found" |
| **Variable undefined** | `status: "Aborted"`, `abortedBy: "systemUser"` | UI console: "Variable 'XYZ' is not defined" |

### 2.5 Important Distinction: Abort vs. Mark as Failed

**Abort:**
- ❌ Does NOT clean up resources (pods, containers, etc.)
- ❌ Does NOT apply failure strategies (rollback, retry)
- ⚠️ Resources remain orphaned

**Mark as Failed:**
- ✅ Cleans up resources properly
- ✅ Applies defined failure strategies
- ✅ Executes rollback steps

**Best Practice:** Configure proper failure strategies instead of relying on aborts.

**Documentation:**
- [Abort a Pipeline](https://developer.harness.io/docs/platform/pipelines/failure-handling/abort-pipeline/)
- [Define Failure Strategies](https://developer.harness.io/docs/platform/pipelines/failure-handling/define-a-failure-strategy-on-stages-and-steps/)

---

## 3. Artifact Resolution Errors

### 3.1 Common Artifact Fetch Failures

**GitHub Packages:**
- ✅ **Supported:** GitHub Personal Access Token (PAT) connector
- ❌ **NOT supported:** GitHub App connectors
- **Required PAT permissions:** `write:packages`, `read:packages`
- **Connector requirement:** API access must be enabled

**Common Errors:**

| Error | Cause | Solution |
|-------|-------|----------|
| **"Failed to find artifact: xyz"** | Artifact doesn't exist with specified tag/digest | Verify artifact name, check GitHub Actions upload step |
| **"Image not found in registry"** | Tag/digest combination doesn't exist | Check Docker/container registry, verify tag format |
| **"Authentication failed"** | Invalid credentials or expired token | Regenerate PAT, update Harness secret |
| **"No artifacts found"** | Artifact pattern too generic (e.g., `*.jar`) | Make pattern more specific |

### 3.2 Custom Artifact Configuration

**Requirements:**
- ✅ Must return JSON formatted as array
- ✅ Supported: Kubernetes, SSH, WinRM deployments only
- ❌ Cannot accept array directly - needs root element

**Configuration Fields:**
- `Artifacts Array Path` - JSONPath to artifact array (e.g., `$.items`)
- `Version Path` - Path to version field in array
- `Script` - Fetch script that outputs JSON to `$HARNESS_ARTIFACT_RESULT_PATH`

**Example Script:**
```bash
#!/bin/bash
# Fetch artifacts from custom repository
ARTIFACTS=$(curl -s https://repo.example.com/api/artifacts)
echo "$ARTIFACTS" > $HARNESS_ARTIFACT_RESULT_PATH
```

### 3.3 Network & Connectivity Issues

**Delegate-Side Problems:**
- Port configuration changes
- Misconfigured proxies
- Firewall rules blocking artifact repositories
- DNS resolution failures

**Diagnostic Steps:**
1. Test connector from Harness UI (Connection Test button)
2. View delegate task logs for fetch operation
3. SSH into delegate pod/container
4. Manually test connectivity:
   ```bash
   curl -v https://ghcr.io/v2/
   curl -v https://your-artifact-repo.com/api/v1/health
   ```

### 3.4 Where to Find Artifact Error Details

**Visibility Matrix:**

| Error Location | Accessible Via API? | Where to Look |
|----------------|---------------------|---------------|
| **Connector validation logs** | ❌ No | UI → Connector → Connection Test → View Logs |
| **Delegate task logs** | ❌ No | UI → Connector → View Delegate Tasks Logs |
| **Execution console logs** | ⚠️ Partial (via Log Service API) | UI → Execution → Console View |
| **Step-level errors** | ✅ Yes | Execution Graph API → failureInfo field |

**Documentation:**
- [CD Artifact Sources](https://developer.harness.io/docs/continuous-delivery/x-platform-cd-features/services/artifact-sources/)
- [Custom Artifact Source](https://developer.harness.io/docs/continuous-delivery/x-platform-cd-features/services/add-a-custom-artifact-source-for-cd/)

---

## 4. Harness Diagnostic Best Practices

### 4.1 Official Troubleshooting Workflow

**Step 1: Locate Execution ID**
```bash
# From UI URL
https://app.harness.io/ng/account/ACCOUNT/cd/orgs/ORG/projects/PROJECT/pipelines/PIPELINE/executions/EXECUTION_ID/pipeline

# From API
GET /pipeline/api/pipelines/execution/v2
```

**Step 2: View Execution as JSON**
```
UI: Execution Details → View as JSON
```

**Why:** May reveal important failure information not visible in standard UI views

**Step 3: Verify Variables**
```bash
# Check variables at each stage
UI: Execution → Stage → Variables tab

# Critical checks:
- Are expected variables defined?
- Do variable values match expectations?
- Are secrets properly resolved?
```

**Step 4: Check Delegate Status**
```bash
# UI verification (most reliable)
Project Settings → Delegates → Look for:
- Status: "Connected"
- Last Heartbeat: < 1 minute ago

# Common delegate issues:
- Delegate offline/disconnected
- Connector validation failures
- Network connectivity problems
```

**Step 5: Examine Logs Hierarchically**
```
1. Pipeline-level logs (overall execution)
2. Stage-level logs (specific deployment stage)
3. Step-level logs (individual task)
4. Delegate task logs (connector/artifact operations)
```

### 4.2 Debug Mode for CI Pipelines

**Feature:** Re-run failed builds with SSH access to debug session

**How to Use:**
1. Locate failed build in execution history
2. Click **"Re-run in Debug Mode"**
3. When Run step fails, log output includes SSH command
4. SSH into session on remote host
5. Inspect:
   - System and application logs
   - Runtime environment variables
   - Network configurations
   - Resource consumption (CPU, memory, disk)

**Example SSH Command:**
```bash
ssh -p 2222 harness@debug-runner-xyz.harness.io
```

**Benefits:**
- ✅ Real-time debugging in failed execution context
- ✅ Access to full environment state at failure point
- ✅ Significantly reduces troubleshooting time

**Documentation:**
- [Debug with SSH](https://developer.harness.io/docs/continuous-integration/troubleshoot-ci/debug-mode/)

### 4.3 Common Diagnostic Patterns

#### Pattern 1: Pipeline Aborted During Stage Init

**Symptoms:**
- Status: "Aborted"
- abortedBy: "systemUser"
- failureInfo: null
- No step logs available

**Diagnostic Steps:**
```bash
# 1. Check UI console immediately
UI → Execution → Console View (expand all stages)

# 2. Look for initialization errors:
- "Failed to find artifact: xyz"
- "Infrastructure definition 'abc' not found"
- "No delegate available for task"
- "Variable 'XYZ' is not defined"

# 3. Verify prerequisites:
# - Infrastructure exists in Harness
# - Delegate is connected
# - Artifacts exist in registry
# - Required variables are set

# 4. API won't help here - UI is source of truth
```

#### Pattern 2: Step Execution Failures

**Symptoms:**
- Status: "Failed"
- Specific step shows red X
- failureInfo populated in API

**Diagnostic Steps:**
```bash
# 1. Get execution graph
GET /executions/{executionId}/subgraph/{nodeExecutionId}

# 2. Check failureInfo
{
  "failureInfo": {
    "message": "Command exited with code 1",
    "failureTypeList": ["UNKNOWN_ERROR"]
  }
}

# 3. Download step logs via API
POST /log-service/blob/download?prefix=ACCOUNT/.../STEP_ID

# 4. Analyze step output for root cause
```

#### Pattern 3: Connector/Artifact Failures

**Symptoms:**
- "Authentication failed"
- "Failed to connect to repository"
- "Image not found"

**Diagnostic Steps:**
```bash
# 1. Test connector in UI
Connectors → Select connector → Connection Test

# 2. If test fails, view delegate logs
Connection Test → View Delegate Tasks Logs

# 3. Check delegate connectivity manually
kubectl exec -it harness-delegate-xyz -- bash
curl -v https://connector-endpoint.com/api/v1/health

# 4. Verify credentials
- Check secret expiration
- Verify IAM permissions
- Test credentials outside Harness
```

### 4.4 Best Practices for Robust Pipelines

**Failure Strategies:**
```yaml
# Configure at stage level
failureStrategies:
  - onFailure:
      errors:
        - AllErrors
      action:
        type: StageRollback  # Clean rollback

# Configure at step level
failureStrategies:
  - onFailure:
      errors:
        - Timeout
      action:
        type: Retry
        spec:
          retryCount: 3
          retryIntervals: 10s
```

**Health Checks:**
```yaml
# Add explicit verification steps
- step:
    type: ShellScript
    name: Health Check
    spec:
      script: |
        curl -f http://service:8080/health || exit 1
```

**Logging Best Practices:**
```yaml
# Enable detailed logging in scripts
- step:
    type: ShellScript
    name: Deploy Application
    spec:
      script: |
        set -x  # Enable command tracing
        echo "Starting deployment..."
        echo "VERSION: <+pipeline.variables.VERSION>"
        ./deploy.sh
```

**Documentation:**
- [Failure Strategies](https://developer.harness.io/docs/platform/pipelines/failure-handling/define-a-failure-strategy-on-stages-and-steps/)
- [Building Robust Pipelines](https://www.harness.io/blog/building-robust-and-resilient-harness-pipelines-with-failure-handling-support)

---

## 5. Harness API Limitations & Gaps

### 5.1 Known API Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| **Execution history limit: 10,000 records** | Cannot retrieve executions beyond 10,000th | Use time-based filtering, export data regularly |
| **Log file limit: 2,000 per execution** | Large pipelines may hit limit | Download critical logs only, archive to external storage |
| **No account-wide execution view** | Must query per project/org | Iterate through projects programmatically |
| **Approval details only if pending** | Historical approval data not available | Store approval audit logs externally |
| **Dynamic execution API-only** | Cannot trigger dynamic pipelines via UI | Use API exclusively for dynamic execution |

### 5.2 API vs. UI Visibility Gaps

**Errors Only Visible in UI:**
- ❌ Stage initialization failures
- ❌ Artifact resolution errors (before fetch begins)
- ❌ Infrastructure validation errors
- ❌ Variable resolution failures
- ❌ Connector validation details
- ❌ Delegate task logs

**Errors Available in Both:**
- ✅ Step execution failures (after step starts)
- ✅ Script output and exit codes
- ✅ High-level execution status

**API-Exclusive Features:**
- ✅ Dynamic pipeline execution
- ✅ Programmatic trigger configuration
- ✅ Bulk execution queries
- ✅ Integration with external monitoring

### 5.3 Asynchronous API Behavior

**Log Download Endpoint:**
```bash
# Request
POST /log-service/blob/download

# Response (immediate)
{
  "status": "PROCESSING"
}

# Must poll until success
{
  "status": "SUCCESS",
  "link": "https://..."
}
```

**Implication:** Cannot stream logs in real-time, must wait for completion

### 5.4 Error Field Null Conditions

**When failureInfo Returns Null/Empty:**
1. Execution aborted before stage started
2. Initialization failures (delegate selection, infrastructure lookup)
3. Pre-execution validation errors
4. systemUser aborts (most common)

**Example Response:**
```json
{
  "status": "Aborted",
  "abortedBy": "systemUser",
  "failureInfo": null,
  "executionErrorInfo": null,
  "nodeMap": {}
}
```

**What This Means:**
- ⚠️ Error details NOT available via API
- ⚠️ Must check UI console for actual error message
- ⚠️ Cannot build fully automated diagnostics

**Documentation:**
- [Pipeline FAQs](https://developer.harness.io/kb/platform/pipeline-faq/)
- [Harness Platform FAQs](https://developer.harness.io/kb/platform/harness-platform-faqs/)

---

## 6. Recommended Diagnostic Workflow

### 6.1 Quick Diagnostic Decision Tree

```
Pipeline Failed?
│
├─> Check execution status API
│   │
│   ├─> Status: "Failed" (step-level failure)
│   │   └─> Use Execution Graph API
│   │       └─> Check failureInfo field
│   │           └─> Download step logs via Log Service API
│   │
│   └─> Status: "Aborted" + abortedBy: "systemUser"
│       └─> ⚠️ API won't help - go to UI console
│           └─> Check for initialization errors:
│               ├─> Artifact resolution
│               ├─> Infrastructure definition
│               ├─> Variable resolution
│               └─> Delegate availability
│
└─> Check Harness UI first (fastest path)
    └─> Execution → Console View
        └─> Expand all stages/steps
            └─> Look for red error messages
```

### 6.2 Step-by-Step Diagnostic Process

#### Phase 1: Initial Assessment (API)

```bash
# 1. Get latest execution status
GET /pipeline/api/pipelines/execution/summary?planExecutionId={id}

# 2. Check high-level status
STATUS=$(jq -r '.status' response.json)

# 3. Identify abortedBy field
ABORTED_BY=$(jq -r '.abortedBy' response.json)

# Decision point:
if [ "$STATUS" = "Aborted" ] && [ "$ABORTED_BY" = "systemUser" ]; then
  echo "⚠️ Skip API, go directly to UI console"
  exit 1
fi
```

#### Phase 2: Execution Graph Analysis (API)

```bash
# 4. Get execution graph
GET /executions/{executionId}/subgraph/{nodeExecutionId}

# 5. Find failed nodes
jq '.executionGraph.nodeMap |
    to_entries |
    map(select(.value.status == "Failed")) |
    .[].value' response.json

# 6. Extract error details
jq '.executionGraph.nodeMap |
    to_entries |
    map(select(.value.failureInfo != null)) |
    .[].value.failureInfo' response.json
```

#### Phase 3: Log Retrieval (API)

```bash
# 7. Download failed step logs
STEP_PREFIX="ACCOUNT/pipeline/PIPELINE_ID/RUN/-EXEC_ID/STAGE_ID/STEP_ID"

curl -X POST \
  "https://app.harness.io/gateway/log-service/blob/download?accountID=ACCOUNT&prefix=$STEP_PREFIX" \
  -H "x-api-key: $HARNESS_API_KEY" \
  -H "content-type: application/json"

# 8. Extract download link
DOWNLOAD_LINK=$(jq -r '.link' response.json)

# 9. Download and analyze logs
curl "$DOWNLOAD_LINK" > step_logs.txt
grep -i "error\|fail\|exception" step_logs.txt
```

#### Phase 4: UI Console Review (Manual)

```
10. Open Harness UI
11. Navigate to: Executions → Select failed execution
12. Click "Console View"
13. Expand all stages (keyboard shortcut: Cmd+A, then click expand)
14. Look for:
    - Red error messages
    - "Failed to find artifact"
    - "Infrastructure not found"
    - "No delegate available"
    - Variable resolution errors
15. Search logs: Cmd+F (macOS) or Ctrl+F (Windows/Linux)
```

#### Phase 5: Delegate & Connector Verification

```bash
# 16. Check delegate status (UI)
Project Settings → Delegates
- Verify "Connected" status
- Check last heartbeat < 1 minute

# 17. Test connectors (UI)
Connectors → Select connector → Connection Test

# 18. If test fails, view delegate logs
Connection Test → View Delegate Tasks Logs

# 19. SSH into delegate (if needed)
kubectl exec -it harness-delegate-pod -- bash
# Or
docker exec -it harness-delegate-container bash

# 20. Test connectivity manually
curl -v https://connector-endpoint.com
ping artifact-registry.example.com
nslookup github.com
```

### 6.3 When to Use Each Diagnostic Method

| Method | When to Use | Strengths | Limitations |
|--------|-------------|-----------|-------------|
| **Execution Graph API** | Step-level failures, programmatic monitoring | Structured data, automation-friendly | Null errors for init failures |
| **Log Service API** | Need step output, script errors | Complete log output | Asynchronous, 2000 file limit |
| **UI Console** | systemUser aborts, initialization failures | Shows ALL errors including pre-execution | Manual process, not scriptable |
| **Delegate Logs** | Connector/artifact issues, network problems | Detailed delegate-side diagnostics | UI-only access |
| **Debug Mode (CI)** | Complex build failures, environment issues | SSH access to failed environment | CI pipelines only |

### 6.4 Automation Strategy

**Recommended Approach: Hybrid API + UI**

```bash
#!/bin/bash
# Automated diagnostic script with UI fallback

# 1. Try API first
EXEC_ID=$1
STATUS=$(curl -s "https://app.harness.io/gateway/pipeline/api/pipelines/execution/summary?planExecutionId=$EXEC_ID" \
  -H "x-api-key: $HARNESS_API_KEY" | jq -r '.status')

# 2. Check if API will be useful
if [[ "$STATUS" == "Aborted" ]]; then
  ABORTED_BY=$(curl -s "..." | jq -r '.abortedBy')

  if [[ "$ABORTED_BY" == "systemUser" ]]; then
    echo "⚠️ systemUser abort detected"
    echo "❌ Error details NOT available via API"
    echo "✅ Manual action required:"
    echo "   1. Open Harness UI"
    echo "   2. Navigate to execution: $EXEC_ID"
    echo "   3. Check Console View for error message"
    echo ""
    echo "🔗 Direct link:"
    echo "   https://app.harness.io/ng/.../executions/$EXEC_ID/pipeline"
    exit 1
  fi
fi

# 3. If not systemUser abort, continue with API diagnostics
echo "✅ Analyzing via API..."
# ... download logs, check failureInfo, etc.
```

---

## 7. Documentation Links & Resources

### 7.1 Official Harness Documentation

**Core Platform:**
- [Harness Developer Hub](https://developer.harness.io/)
- [Harness API Reference](https://apidocs.harness.io/)

**Execution & Logs:**
- [Understanding Execution Graph API](https://developer.harness.io/docs/platform/pipelines/pipeline-execution-graph/)
- [Download Execution Logs](https://developer.harness.io/docs/platform/pipelines/executions-and-logs/download-logs/)
- [Pipeline Execution History](https://developer.harness.io/docs/continuous-delivery/x-platform-cd-features/executions/execution-history/)
- [Search Console View](https://developer.harness.io/docs/platform/pipelines/searching-the-console-view/)

**Failure Handling:**
- [Abort a Pipeline](https://developer.harness.io/docs/platform/pipelines/failure-handling/abort-pipeline/)
- [Define Failure Strategies](https://developer.harness.io/docs/platform/pipelines/failure-handling/define-a-failure-strategy-on-stages-and-steps/)
- [Mark as Failed](https://developer.harness.io/docs/platform/pipelines/failure-handling/mark-as-failed/)
- [Retry Failed Executions](https://developer.harness.io/docs/platform/pipelines/failure-handling/resume-pipeline-deployments/)

**Troubleshooting:**
- [Troubleshooting Harness](https://developer.harness.io/docs/troubleshooting/troubleshooting-nextgen/)
- [Debug with SSH (CI)](https://developer.harness.io/docs/continuous-integration/troubleshoot-ci/debug-mode/)
- [Harness Platform FAQs](https://developer.harness.io/kb/platform/harness-platform-faqs/)
- [Pipeline FAQs](https://developer.harness.io/kb/platform/pipeline-faq/)

**Artifact Sources:**
- [CD Artifact Sources](https://developer.harness.io/docs/continuous-delivery/x-platform-cd-features/services/artifact-sources/)
- [Custom Artifact Source](https://developer.harness.io/docs/continuous-delivery/x-platform-cd-features/services/add-a-custom-artifact-source-for-cd/)
- [CD Artifact Source FAQs](https://developer.harness.io/docs/continuous-delivery/x-platform-cd-features/services/cd-artifact-sources-faqs/)

**Delegates:**
- [Harness Delegate FAQs](https://developer.harness.io/docs/faqs/harness-delegate-faqs/)
- [Delegate Release Notes](https://developer.harness.io/release-notes/delegate/)

### 7.2 Community Resources

**Stack Overflow:**
- [Harness Tag on Stack Overflow](https://stackoverflow.com/questions/tagged/harness)
- Active community discussing pipeline failures, debugging, and best practices

**Blogs & Articles:**
- [Building Robust Pipelines with Failure Handling](https://www.harness.io/blog/building-robust-and-resilient-harness-pipelines-with-failure-handling-support)
- [Troubleshooting Guide: Harness CI](https://harness-community.github.io/blog/troubleshooting-harness-ci)
- [SSH Remote Debugger in Harness CI](https://www.harness.io/blog/introducing-powerful-remote-debugger)

**GitHub:**
- [Harness Developer Hub GitHub](https://github.com/harness/developer-hub)
- [Harness Performance Tool](https://github.com/harness/harness-performance-tool)

### 7.3 API Deep Dives

**Third-Party Resources:**
- [Harness StartExecution API Deep Dive](https://hackmd.io/@AbCws2gnRhifQM1glYXdNA/Bkya9uEj8)
- [API Tracker - Harness API Overview](https://apitracker.io/a/harness-io)
- [Postman Collection - Pipeline Execution Details](https://www.postman.com/api-evangelist/harness/request/8h2i9n1/get-the-pipeline-execution-details-for-given-planexecution-id)

### 7.4 Related Best Practices

**CI/CD General:**
- [Harness CI Best Practices](https://www.linkedin.com/pulse/harness-ci-best-practices-ronak-patil)
- [Pipeline Design Guide](https://developer.harness.io/docs/continuous-delivery/cd-onboarding/new-user/pipeline-design-guide/)

---

## 8. Actionable Recommendations

### 8.1 For Immediate Troubleshooting

**When a pipeline fails RIGHT NOW:**

1. ✅ **Check Harness UI first** (fastest path to error message)
   - Execution → Console View → Expand all

2. ✅ **If you need automation, use this priority:**
   - Try Execution Graph API
   - Download logs via Log Service API
   - If API returns null errors → Fall back to UI

3. ✅ **For artifact failures:**
   - Test connector in UI
   - View delegate task logs
   - Verify artifact exists in registry

### 8.2 For Building Diagnostic Scripts

**Script Pattern:**
```bash
#!/bin/bash
# harness-diagnose.sh

EXEC_ID=$1

# 1. Get status via API
STATUS=$(curl -s "$HARNESS_API/executions/$EXEC_ID" | jq -r '.status')

# 2. Decision: Can API help?
if [[ "$STATUS" == "Aborted" ]]; then
  # Check if systemUser abort
  if [[ $(curl -s ... | jq -r '.abortedBy') == "systemUser" ]]; then
    echo "⚠️ UI manual review required"
    echo "🔗 https://app.harness.io/.../executions/$EXEC_ID/pipeline"
    exit 0
  fi
fi

# 3. API diagnostics
FAILED_NODES=$(curl -s "$HARNESS_API/executions/$EXEC_ID/subgraph" | \
  jq '.executionGraph.nodeMap | to_entries | map(select(.value.status == "Failed"))')

echo "Failed steps: $(echo $FAILED_NODES | jq 'length')"

# 4. Download logs
for node in $(echo $FAILED_NODES | jq -r '.[].key'); do
  echo "Downloading logs for: $node"
  # ... log download logic
done
```

### 8.3 For Long-Term Pipeline Health

**Implement These Patterns:**

1. **Robust Failure Strategies:**
```yaml
failureStrategies:
  - onFailure:
      errors:
        - AllErrors
      action:
        type: StageRollback
```

2. **Explicit Health Checks:**
```yaml
- step:
    type: ShellScript
    name: Verify Deployment
    spec:
      script: |
        curl -f http://service:8080/health || exit 1
```

3. **Detailed Logging:**
```yaml
- step:
    type: ShellScript
    spec:
      script: |
        set -x  # Command tracing
        echo "Variables: VERSION=<+pipeline.variables.VERSION>"
        ./deploy.sh
```

4. **Pre-Execution Validation:**
```yaml
- step:
    type: ShellScript
    name: Validate Prerequisites
    spec:
      script: |
        # Check artifact exists
        curl -f "$ARTIFACT_URL" || exit 1

        # Check infrastructure ready
        kubectl get deployment myapp || exit 1
```

### 8.4 Documentation to Create

**Recommended Internal Docs:**

1. **"Harness Failure Diagnosis Playbook"**
   - Decision tree: API vs. UI
   - Common error patterns and solutions
   - Links to relevant scripts

2. **"Harness API Quick Reference"**
   - Common endpoints with examples
   - Authentication setup
   - Response parsing patterns

3. **"Harness Delegate Troubleshooting"**
   - Connectivity tests
   - Log locations
   - Common delegate errors

4. **"Artifact Configuration Guide"**
   - Supported artifact types
   - Connector setup for each type
   - Troubleshooting artifact fetch failures

---

## 9. Key Takeaways

### 9.1 Critical Insights

1. **API Has Blind Spots**
   - Initialization failures often have null error fields
   - systemUser aborts don't expose root cause via API
   - UI console is sometimes the only source of truth

2. **Multi-Layered Approach Required**
   - Start with API for automation
   - Fall back to UI when API returns null
   - Use delegate logs for connector/artifact issues

3. **Proactive > Reactive**
   - Implement failure strategies before failures occur
   - Add explicit validation steps
   - Enable detailed logging by default

### 9.2 What Works Well via API

✅ Step execution failures (after step starts)
✅ Script output and exit codes
✅ High-level execution status
✅ Downloading logs after execution completes
✅ Monitoring execution progress

### 9.3 What Requires UI Access

❌ Stage initialization failures
❌ Artifact resolution errors (pre-fetch)
❌ Infrastructure validation errors
❌ systemUser abort root causes
❌ Connector validation details
❌ Delegate task logs

### 9.4 Best Practice Summary

| Scenario | Recommended Approach |
|----------|---------------------|
| **Building monitoring dashboard** | Use Execution Graph API + UI fallback alerts |
| **Debugging failed deployment** | Check UI console first, then API for details |
| **Automating diagnostics** | Hybrid script: API with UI manual review trigger |
| **Artifact issues** | Test connector in UI → View delegate logs |
| **CI build failures** | Use Debug Mode (SSH into failed environment) |
| **Production pipeline design** | Add explicit validation + failure strategies |

---

## 10. Conclusion

Harness provides powerful APIs for pipeline execution and monitoring, but there are **significant gaps** between what's available via API versus the UI. The most critical limitation is around **initialization failures** and **systemUser aborts**, where error details are often **only visible in the UI console**.

**For effective diagnosis:**
- ✅ Use APIs for automation and monitoring
- ✅ Always have UI as a fallback option
- ✅ Build hybrid diagnostic scripts that guide users to UI when needed
- ✅ Implement robust failure handling proactively

**The reality:** You cannot build a **fully automated** diagnostic system using only the Harness API. UI access will always be required for certain classes of errors, particularly those occurring during stage initialization.

**Recommendation:** Accept this hybrid model and build tooling that recognizes when to use API vs. when to direct users to the UI, rather than trying to force API-only solutions.

---

**Research Completed:** 2025-01-19
**Sources:** Official Harness documentation, community forums, Stack Overflow, API references
**Next Steps:** Implement findings in project diagnostic scripts and update HARNESS_API_PLAYBOOK.md
