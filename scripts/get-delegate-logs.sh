#!/bin/bash
# Get Harness Delegate Logs
# Usage: ./scripts/get-delegate-logs.sh [task_id] [minutes]

TASK_ID="${1:-}"
MINUTES="${2:-10}"

# Find delegate container
DELEGATE_CONTAINER=$(docker ps --filter "name=harness-delegate" --format "{{.Names}}" | head -1)

if [ -z "$DELEGATE_CONTAINER" ]; then
  echo "❌ No harness-delegate container found"
  echo ""
  echo "Available containers:"
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
  exit 1
fi

echo "========================================="
echo "Harness Delegate Logs"
echo "========================================="
echo "Container: $DELEGATE_CONTAINER"
echo "Time window: Last $MINUTES minutes"
if [ -n "$TASK_ID" ]; then
  echo "Task ID: $TASK_ID"
fi
echo ""

if [ -n "$TASK_ID" ]; then
  # Get logs for specific task
  echo "========================================="
  echo "Logs for Task: $TASK_ID"
  echo "========================================="
  docker logs "$DELEGATE_CONTAINER" --since "${MINUTES}m" 2>&1 | grep -A 20 -B 5 "$TASK_ID" | tail -100
else
  # Get recent task executions
  echo "========================================="
  echo "Recent Task Executions"
  echo "========================================="
  docker logs "$DELEGATE_CONTAINER" --since "${MINUTES}m" 2>&1 | grep "New Task event received" | tail -20

  echo ""
  echo "========================================="
  echo "Recent Errors"
  echo "========================================="
  docker logs "$DELEGATE_CONTAINER" --since "${MINUTES}m" 2>&1 | grep -E "ERROR|error|Error|FAIL|fail" | grep -v "command not found: error" | tail -20

  echo ""
  echo "========================================="
  echo "Shell Script Executions"
  echo "========================================="
  docker logs "$DELEGATE_CONTAINER" --since "${MINUTES}m" 2>&1 | grep "SHELL_SCRIPT" | tail -10
fi

echo ""
echo "========================================="
echo "Usage Tips"
echo "========================================="
echo "Get logs for specific task:"
echo "  ./scripts/get-delegate-logs.sh <task-id> [minutes]"
echo ""
echo "Get recent task list:"
echo "  ./scripts/get-delegate-logs.sh"
echo ""
echo "Get logs from last hour:"
echo "  ./scripts/get-delegate-logs.sh \"\" 60"
echo ""
echo "View live logs:"
echo "  docker logs -f $DELEGATE_CONTAINER"
echo ""
