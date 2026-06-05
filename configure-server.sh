# Install tools
echo "Installing KInD..."
bash $PWD/tools/install-kind.sh
echo ""
echo "Installing Helm..."
bash $PWD/tools/install-helm.sh
echo ""
echo "Installing kubectl..."
bash $PWD/tools/install-kubectl.sh
echo "Installing jq..."
bash $PWD/tools/install-jq.sh
echo "Installing terraform..."
bash $PWD/tools/install-terraform.sh

#export DOCKER_DEFAULT_PLATFORM=linux/amd64

echo "Starting Octopus Deploy Server containers"
sudo docker compose --env-file $PWD/octopusdeploy/octopusdeploy.env --file $PWD/octopusdeploy/octopusdeploy.yaml up -d

echo "Starting Gitea containers"
sudo docker compose --file $PWD/gitea/gitea.yaml up -d
echo ""
echo "Letting Gitea server start up before running configuration"
sleep 5

echo "Configuring Gitea"
bash $PWD/gitea/configure-gitea.sh

echo "Creating KInD cluster"
bash $PWD/kind-cluster/install-kind.sh

echo "Installing Argo CD"
bash $PWD/argocd/install-argocd.sh
