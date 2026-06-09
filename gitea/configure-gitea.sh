#!/bin/bash

echo "Creating admin user account"
docker exec -it gitea su git -c "gitea admin user create --username 'admin' --password 'Admin123!' --email gitea-admin@octopus.app --admin --must-change-password=false --config /data/gitea/conf/app.ini"

GITEA_ADMIN_USER="admin"
GITEA_ADMIN_PASSWORD='Admin123!'
GITEA_URL="http://localhost:3000"

sleep 20

echo ""
echo "--- Checking if Token already exists ---"
TOKEN_RESPONSE=$(curl -s -X GET "${GITEA_URL}/api/v1/users/${GITEA_ADMIN_USER}/tokens" \
  -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
  -H "Content-Type: application/json" ) || true

# The token list endpoint never returns the sha1 value, so if the
# instruqt-setup token already exists we delete it and recreate it below
# to obtain a usable token value.
if echo "${TOKEN_RESPONSE}" | grep -q '"name":"instruqt-setup"'; then
  echo "instruqt-setup token already exists - deleting so it can be recreated"
  curl -s -X DELETE "${GITEA_URL}/api/v1/users/${GITEA_ADMIN_USER}/tokens/instruqt-setup" \
    -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" || true
fi

echo "--- Creating API Token ---"
TOKEN_RESPONSE=$(curl -s -X POST "${GITEA_URL}/api/v1/users/${GITEA_ADMIN_USER}/tokens" \
  -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d '{"name":"instruqt-setup","scopes":["write:repository","write:user"]}') || true

echo "Token API response: ${TOKEN_RESPONSE}"

GITEA_TOKEN=$(echo "${TOKEN_RESPONSE}" | grep -o '"sha1":"[^"]*"' | cut -d'"' -f4 || true)
echo "Extracted token: ${GITEA_TOKEN:-NONE}"

echo ""
echo "--- Creating Repository ---"
if [ -n "${GITEA_TOKEN}" ]; then
  REPO_RESPONSE=$(curl -s -X POST "${GITEA_URL}/api/v1/user/repos" \
    -H "Authorization: token ${GITEA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "deployment-config",
      "description": "Octopus Deploy configuration repository",
      "auto_init": true,
      "default_branch": "main",
      "private": false
    }') || true
  echo "Repo API response: ${REPO_RESPONSE}"
else
  echo "✗ Skipping repo creation - no token available"
fi

echo ""
echo "--- Mirroring GitHub sample applications repo into Gitea ---"
GITHUB_REPO="https://github.com/OctopusSolutionsEngineering/instruqt-sample-applications.git"
GITEA_REPO_NAME="instruqt-sample-applications"

if [ -n "${GITEA_TOKEN}" ]; then
  # Create the repo in Gitea
  curl -s -X POST "${GITEA_URL}/api/v1/user/repos" \
    -H "Authorization: token ${GITEA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"${GITEA_REPO_NAME}\",
      \"description\": \"Sample applications for Octopus Deploy track\",
      \"auto_init\": false,
      \"private\": false
    }" || true

  # Clone from GitHub and push to Gitea
  GIT_TERMINAL_PROMPT=0 git clone --mirror "${GITHUB_REPO}" /tmp/${GITEA_REPO_NAME}.git
  cd /tmp/${GITEA_REPO_NAME}.git
  git remote set-url origin "${GITEA_URL}/${GITEA_ADMIN_USER}/${GITEA_REPO_NAME}.git"
  git config http.extraHeader "Authorization: token ${GITEA_TOKEN}"
  GIT_TERMINAL_PROMPT=0 git push --mirror origin
  cd -
  rm -rf /tmp/${GITEA_REPO_NAME}.git
  echo "✓ GitHub repo mirrored to Gitea as ${GITEA_REPO_NAME}"
else
  echo "✗ Skipping GitHub mirror - no token available"
fi

echo ""
echo "--- Creating Actions token and secrets ---"
if [ -n "${GITEA_TOKEN}" ]; then
  # Delete existing actions token if it exists
  curl -s -X DELETE "${GITEA_URL}/api/v1/users/${GITEA_ADMIN_USER}/tokens/gitea-actions" \
    -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" || true

  echo ""
  echo "Getting Actions token resopnse"

  # Create a full-scope token for use in Actions secrets
  ACTIONS_TOKEN_RESPONSE=$(curl -s -X POST "${GITEA_URL}/api/v1/users/${GITEA_ADMIN_USER}/tokens" \
    -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d '{"name":"gitea-actions","scopes":["write:repository","write:user","write:package","write:admin","write:activitypub","write:issue","write:organization","write:notification","write:misc"]}') || true
  echo "Actions token response: ${ACTIONS_TOKEN_RESPONSE}"

  ACTIONS_TOKEN=$(echo "${ACTIONS_TOKEN_RESPONSE}" | grep -o '"sha1":"[^"]*"' | cut -d'"' -f4 || true)
  echo "Actions token extracted: ${ACTIONS_TOKEN:-NONE}"

  if [ -n "${ACTIONS_TOKEN}" ]; then
    # Set GITEATOKEN secret (user-level, available to all repos)
    curl -s -X PUT "${GITEA_URL}/api/v1/user/actions/secrets/GITEATOKEN" \
      -H "Authorization: token ${GITEA_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"data\":\"${ACTIONS_TOKEN}\"}" && echo "✓ GITEATOKEN secret set" || echo "✗ Failed to set GITEATOKEN secret"

    # Set GITEAUSERNAME secret
    curl -s -X PUT "${GITEA_URL}/api/v1/user/actions/secrets/GITEAUSERNAME" \
      -H "Authorization: token ${GITEA_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"data\":\"${GITEA_ADMIN_USER}\"}" && echo "✓ GITEAUSERNAME secret set" || echo "✗ Failed to set GITEAUSERNAME secret"
  else
    echo "✗ Could not extract actions token - skipping secrets"
  fi
else
  echo "✗ Skipping Actions secrets - no token available"
fi

echo ""
echo "--- Waiting for Gitea at ${GITEA_URL} ---"
max_attempts=60
for i in $(seq 1 $max_attempts); do
  status=$(curl -s -o /dev/null -w "%{http_code}" "$GITEA_URL" 2>/dev/null || true)
  status=${status:-000}
  echo "Attempt $i/$max_attempts - HTTP status: ${status}"
  if [ "${status}" != "000" ]; then
    echo "✓ Gitea is responding (status: ${status})"
    break
  fi
  sleep 5
  if [ "$i" = "$max_attempts" ]; then
    echo "⚠ Timeout waiting for Gitea - continuing anyway"
  fi
done

echo ""
echo "--- Getting act_runner registration token from Gitea ---"
RUNNER_TOKEN=""
max_token=10
for i in $(seq 1 $max_token); do
  RUNNER_TOKEN=$(curl -s -X POST "${GITEA_URL}/api/v1/admin/actions/runners/registration-token" \
    -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
    -H "Content-Type: application/json" \
    | grep -o '"token":"[^"]*"' | cut -d'"' -f4 || true)
  if [ -n "${RUNNER_TOKEN}" ]; then
    echo "✓ Got runner registration token"
    break
  fi
  echo "Attempt $i/$max_token - waiting for token..."
  sleep 5
done

if [ -z "${RUNNER_TOKEN}" ]; then
  echo "✗ Could not get runner token - act_runner will not be registered"
  exit 0
fi

echo ""
echo "Starting act_runner as a container"

# Set local scoped variable of the same environment variable name to override
GITEA_RUNNER_REGISTRATION_TOKEN="${RUNNER_TOKEN}" docker compose --file $PWD/gitea/act-runner.yaml --env-file $PWD/gitea/act-runner.env up -d #--remove-orphans

if [ "$(docker inspect -f '{{.State.Running}}' gitea-runner 2>/dev/null)" = "true" ]; then
    echo "✓ act_runner container is running"
    echo "Checking to see if the runner has registered with Gitea"
    RUNNER_LIST=$(curl -s -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" "${GITEA_URL}/api/v1/admin/actions/runners" || true)
    if echo $RUNNER_LIST | jq '.total_count' | grep -q '1'; then
      echo "✓ act_runner has registered with Gitea"
    else
      echo "✗ act_runner has not registered with Gitea yet"
      echo "Runner list response: ${RUNNER_LIST}"
    fi
else
    echo "✗ act_runner container is not running"
    docker logs gitea-runner
fi