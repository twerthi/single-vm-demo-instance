GITEA_ADMIN_USER="admin"
GITEA_ADMIN_PASSWORD="Admin123!"
GITEA_URL="http://localhost:3000"
GITEA_AUTH="Authorization: Basic $(printf '%s' "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" | base64)"

echo ""
echo "--- Checking act_runner is online ---"
if [ "$(docker inspect -f '{{.State.Running}}' gitea-runner 2>/dev/null)" = "true" ]; then
  echo "✓ act_runner container is running"
else
  echo "⚠ act_runner container is not running — starting it"
  docker start gitea-runner || echo "✗ Failed to start gitea-runner"
fi

max_attempts=12
for i in $(seq 1 $max_attempts); do
  RUNNER_COUNT=$(curl -s -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
    "${GITEA_URL}/api/v1/admin/actions/runners" 2>/dev/null \
    | jq -r '.total_count // 0' 2>/dev/null || echo "0")
  if [ "${RUNNER_COUNT:-0}" -ge 1 ] 2>/dev/null; then
    echo "✓ act_runner registered with Gitea (${RUNNER_COUNT} runner(s))"
    break
  fi
  echo "Attempt $i/$max_attempts - waiting for runner registration..."
  sleep 5
  if [ "$i" = "$max_attempts" ]; then
    echo "⚠ Runner not registered after timeout — workflow dispatch may queue"
    docker logs gitea-runner --tail 20 2>/dev/null || true
  fi
done

echo "Dispatching build-and-push workflow..."
DISPATCH_HTTP=$(curl -s -o /tmp/workflow-dispatch.json -w "%{http_code}" \
  -X POST "${GITEA_URL}/api/v1/repos/${GITEA_ADMIN_USER}/instruqt-sample-applications/actions/workflows/build-and-push.yaml/dispatches" \
  -H "${GITEA_AUTH}" \
  -H "Content-Type: application/json" \
  -d '{"ref":"refs/heads/main"}')
if [ "${DISPATCH_HTTP}" = "204" ]; then
  echo "✓ Build workflow dispatched"
else
  echo "✗ Failed to dispatch build workflow (HTTP ${DISPATCH_HTTP})"
  cat /tmp/workflow-dispatch.json 2>/dev/null || true
  exit 1
fi

max_attempts=50  # up to ~4 minutes 10 seconds
for i in $(seq 1 $max_attempts); do
  RUN=$(curl -s \
    "${GITEA_URL}/api/v1/repos/${GITEA_ADMIN_USER}/instruqt-sample-applications/actions/runs?limit=1" \
    -H "${GITEA_AUTH}" | jq '.workflow_runs[0] // empty')

  if [ -z "$RUN" ]; then
    echo "Attempt $i/$max_attempts - no runs found yet..."
    sleep 5
    continue
  fi

  STATUS=$(echo "$RUN" | jq -r '.status // ""')
  CONCLUSION=$(echo "$RUN" | jq -r '.conclusion // ""')
  echo "Attempt $i/$max_attempts - status: ${STATUS}, conclusion: ${CONCLUSION}"

  if [ "$STATUS" = "completed" ]; then
    if [ "$CONCLUSION" = "success" ]; then
      echo "✓ Build workflow completed successfully"
      break
    else
      echo "✗ Build workflow completed with conclusion: ${CONCLUSION}"
      exit 1
    fi
  fi

  if [ "$i" = "$max_attempts" ]; then
    echo "✗ Timed out waiting for build workflow to complete"
    exit 1
  fi
  sleep 5
done