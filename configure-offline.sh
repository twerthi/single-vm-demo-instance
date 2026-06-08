#! /bin/bash
OS=$(uname -s)

echo "Configuring local registry for offline installation..."
docker run --platform linux/amd64 -d -p 5000:5000 --restart=always --name registry --network octopusdeploy_default registry:3

echo ""
echo "Pulling Argo CD images for offline installation..."

curl -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  | grep "image:" | sort -u | awk '{print $2}' \
  | while read image; do
      echo "==> Pulling: $image"
      docker pull --platform linux/amd64 "$image"


      echo "==> Pushing: $image to local registry"
      docker tag "$image" "localhost:5000/$image"
      docker push "localhost:5000/$image"
    done

echo ""
echo "Patching Argo CD manifests to use local registry..."
kubectl get deployments,statefulsets -n argocd -o name | while read resource; do
  echo "Patching $resource..."

  # Patch containers
  kubectl get "$resource" -n argocd -o jsonpath='{range .spec.template.spec.containers[*]}{.name} {.image}{"\n"}{end}' | \
  while read cname cimage; do
    idx=$(kubectl get "$resource" -n argocd -o json | jq -r --arg name "$cname" '.spec.template.spec.containers | to_entries[] | select(.value.name == $name) | .key')
    newimage="registry:5000/$cimage"
    echo "  [container/$idx] $cname: $cimage -> $newimage"
    kubectl patch "$resource" -n argocd --type=json \
      -p "[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/$idx/image\",\"value\":\"$newimage\"}]"
  done

  # Patch initContainers
  kubectl get "$resource" -n argocd -o jsonpath='{range .spec.template.spec.initContainers[*]}{.name} {.image}{"\n"}{end}' | \
  while read cname cimage; do
    [ -z "$cname" ] && continue  # skip if no initContainers
    idx=$(kubectl get "$resource" -n argocd -o json | jq -r --arg name "$cname" '.spec.template.spec.initContainers | to_entries[] | select(.value.name == $name) | .key')
    newimage="registry:5000/$cimage"
    echo "  [initContainer/$idx] $cname: $cimage -> $newimage"
    kubectl patch "$resource" -n argocd --type=json \
      -p "[{\"op\":\"replace\",\"path\":\"/spec/template/spec/initContainers/$idx/image\",\"value\":\"$newimage\"}]"
  done

done

echo ""
echo "Pre-pulling ubuntu image for Gitea builds"
docker pull --platform linux/amd64 docker.gitea.com/runner-images:ubuntu-latest
docker pull --platform linux/amd64 moby/buildkit:buildx-stable-1

echo ""
echo "Tagging and pushing ubuntu image to local registry for Gitea builds"
docker tag docker.gitea.com/runner-images:ubuntu-latest localhost:5000/runner-images:ubuntu-latest
docker push localhost:5000/runner-images:ubuntu-latest
docker tag moby/buildkit:buildx-stable-1 localhost:5000/moby/buildkit:buildx-stable-1
docker push localhost:5000/moby/buildkit:buildx-stable-1

echo ""
echo "Updating gitea runner configuration to use local registry..."
CONFIG_FILE="${1:-$PWD/gitea/config.yaml}"
#REGISTRY_IMAGE="${2:-registry:5000/runner-images:ubuntu-latest}"
REGISTRY_IMAGE="${2:-localhost:5000/runner-images:ubuntu-latest}"
LABEL="ubuntu-latest"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: config file not found: $CONFIG_FILE"
  exit 1
fi

if [ "$OS" = "Darwin" ]; then
  sed -i .bak "s|\"${LABEL}:docker://[^\"]*\"|\"${LABEL}:docker://${REGISTRY_IMAGE}\"|g" "$CONFIG_FILE"
elif [ "$OS" = "Linux" ]; then

  # Back up the original
  cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
  echo "Backup saved to ${CONFIG_FILE}.bak"

  # Replace the label line
  sed -i "s|\"${LABEL}:docker://[^\"]*\"|\"${LABEL}:docker://${REGISTRY_IMAGE}\"|g" "$CONFIG_FILE"
else
    echo "Unsupported OS: $OS"
    exit 1
fi

# Verify the change
echo "Updated label:"
grep "$LABEL" "$CONFIG_FILE"

# set -euo pipefail
 
# DAEMON_JSON="/etc/docker/daemon.json"
# REGISTRY="${1:?Usage: sudo $0 <registry>}"
 
# [[ $EUID -eq 0 ]]          || { echo "ERROR: Run as root."; exit 1; }
# command -v jq &>/dev/null  || { echo "ERROR: jq is required."; exit 1; }
 
# # Create file if missing, validate if it exists
# [[ -f "$DAEMON_JSON" ]] || echo "{}" > "$DAEMON_JSON"
# jq empty "$DAEMON_JSON" 2>/dev/null || { echo "ERROR: Invalid JSON in $DAEMON_JSON"; exit 1; }
 
# # Check if already present
# if jq -e --arg r "$REGISTRY" '.["insecure-registries"] // [] | contains([$r])' "$DAEMON_JSON" &>/dev/null; then
#   echo "'$REGISTRY' already in insecure-registries. No changes made."
#   exit 0
# fi
 
# # Back up and update
# cp "$DAEMON_JSON" "${DAEMON_JSON}.bak"
# jq --arg r "$REGISTRY" '.["insecure-registries"] = ((.["insecure-registries"] // []) + [$r])' \
#   "$DAEMON_JSON" > /tmp/daemon.json.tmp && mv /tmp/daemon.json.tmp "$DAEMON_JSON"
 
# echo "Added '$REGISTRY' to insecure-registries. Restart Docker to apply: sudo systemctl restart docker"
 

# echo "Restarting Gitea runner to apply changes..."
# docker restart --platform linux/amd64 gitea-runner