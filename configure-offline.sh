echo "Configuring local registry for offline installation..."
docker run -d -p 5000:5000 --restart=always --name registry --network octopusdeploy_default registry:3

echo ""
echo "Pulling Argo CD images for offline installation..."

curl -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  | grep "image:" | sort -u | awk '{print $2}' \
  | while read image; do
      echo "==> Pulling: $image"
      docker pull "$image"


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
docker pull docker.gitea.com/runner-images:ubuntu-latest
docker pull moby/buildkit:buildx-stable-1

echo ""
echo "Tagging and pushing ubuntu image to local registry for Gitea builds"
docker tag docker.gitea.com/runner-images:ubuntu-latest localhost:5000/runner-images:ubuntu-latest
docker push localhost:5000/runner-images:ubuntu-latest
docker tag moby/buildkit:buildx-stable-1 localhost:5000/moby/buildkit:buildx-stable-1
docker push localhost:5000/moby/buildkit:buildx-stable-1

echo ""
echo "Updating gitea runner configuration to use local registry..."
CONFIG_FILE="${1:-$PWD/gitea/config.yaml}"
# Set to localhost because the containers run on the host context and the registry is exposed on the host's network. The runner will be configured to pull from localhost:5000 which is the local registry.
REGISTRY_IMAGE="${2:-localhost:5000/runner-images:ubuntu-latest}"
LABEL="ubuntu-latest"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: config file not found: $CONFIG_FILE"
  exit 1
fi

# Back up the original
cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
echo "Backup saved to ${CONFIG_FILE}.bak"

# Replace the label line
sed -i "s|\"${LABEL}:docker://[^\"]*\"|\"${LABEL}:docker://${REGISTRY_IMAGE}\"|g" "$CONFIG_FILE"

# Verify the change
echo "Updated label:"
grep "$LABEL" "$CONFIG_FILE"

echo ""
echo "Pulling Octopus Deploy Worker Tools image for offline installation..."
docker pull octopusdeploy/worker-tools:6.5.0-ubuntu.22.04
echo "Tagging and pushing Octopus Deploy Worker Tools image to local registry for offline installation..."
docker tag octopusdeploy/worker-tools:6.5.0-ubuntu.22.04 localhost:5000/octopusdeploy/worker-tools:6.5.0-ubuntu.22.04
docker push localhost:5000/octopusdeploy/worker-tools:6.5.0-ubuntu.22.04

echo ""
echo "Pulling dependent images for sample application build..."
docker pull mcr.microsoft.com/dotnet/sdk:9.0
echo "Tagging and pushing dependent images to local registry for offline installation..."
docker tag mcr.microsoft.com/dotnet/sdk:9.0 localhost:5000/mcr.microsoft.com/dotnet/sdk:9.0
docker push localhost:5000/mcr.microsoft.com/dotnet/sdk:9.0 

docker pull mcr.microsoft.com/dotnet/aspnet:9.0
echo "Tagging and pushing dependent images to local registry for offline installation..."
docker tag mcr.microsoft.com/dotnet/aspnet:9.0 localhost:5000/mcr.microsoft.com/dotnet/aspnet:9.0
docker push localhost:5000/mcr.microsoft.com/dotnet/aspnet:9.0

echo ""
echo "Starting a local nuget server container..."
docker run -d --name nuget-server -p 8000:8080 -e ApiKey="Admin123!" -v ./bagetter-data:/data  --network octopusdeploy_default bagetter/bagetter:latest

echo ""
echo "Cloning sample application repository for offline installation..."
git clone http://localhost:3000/admin/instruqt-sample-applications.git

echo ""
echo "Parsing nuget package dependencies..."
find instruqt-sample-applications -name "*.csproj" -exec sh -c 'grep "<PackageReference" "$1" | sed -E "s/.*Include=\"([^\"]*)\".*Version=\"([^\"]*)\".*/\1|\2/p"' sh {} \; | sort -u > nuget-dependencies.txt

echo ""
echo "Downloading nuget packages for offline installation..."
#!/usr/bin/env bash
 
OUTPUT_DIR="./nuget-packages"
mkdir -p "$OUTPUT_DIR"
 
while IFS='|' read -r pkg_id version; do
  pkg_lower=$(echo "$pkg_id" | tr '[:upper:]' '[:lower:]')
  ver_lower=$(echo "$version" | tr '[:upper:]' '[:lower:]')
  echo "Downloading $pkg_id $version..."
  curl -sL -o "$OUTPUT_DIR/${pkg_lower}.${ver_lower}.nupkg" \
    "https://api.nuget.org/v3-flatcontainer/${pkg_lower}/${ver_lower}/${pkg_lower}.${ver_lower}.nupkg"
done < nuget-dependencies.txt
 
echo "Done."

echo "" 
echo "Uploading nuget packages to local nuget server for offline installation..."
for pkg in "$OUTPUT_DIR"/*.nupkg; do
  echo "Uploading $(basename "$pkg")..."
  curl -sL -X POST "http://localhost:6000/nuget" \
    -H "X-NuGet-ApiKey: Admin123!" \
    -F "package=@$pkg"
done

echo ""
echo "Updating git repo for offline builds..."

NUGET_CONFIG='<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <!-- Removes all inherited or default machine sources (including nuget.org) -->
    <clear />
    <!-- Add only the explicit sources you actually want to keep -->
    <add key="LocalFeed" value="http://nuget-server:8080" allowInsecureConnection="true" />
  </packageSources>
</configuration>'

find instruqt-sample-applications -iname "dockerfile*" | while read -r file; do
  dir=$(dirname "$file")
  echo "Updating $file..."
  sed -i 's|^FROM |FROM registry:5000/|g' "$file"
  echo "Creating $dir/nuget.config..."
  echo "$NUGET_CONFIG" > "$dir/nuget.config"
done

cd instruqt-sample-applications
git add .
git config user.name "Setup User"
git config user.email "me@fake.org"
git commit -m "Configure for offline installation"
git push http://admin:Admin123!@localhost:3000/admin/instruqt-sample-applications.git main

echo ""
echo "Your environment has been configured to work without Internet access.  Next steps:
- If you did not provide the base64 encoded license value for Octopus Deploy, you will need to paste the XML license file content using the UI.  The Octopus server will start without it, but will not allow you to add any targets or projects until a license has been applied
- Add the Kubernetes Agent - Agent installation uses a Helm chart, which will need to be run before you disconnect from the Internet.  If you're new to Octopus, there is a wizard that will guide you throught this.
- Add the Octopus Deploy Argo CD Gateway - Gateway installation uses a Helm chart, which will need to be run before you disconnect from the Internet.  If you're new to Octopus, there is a wizard that will guide you throught this."