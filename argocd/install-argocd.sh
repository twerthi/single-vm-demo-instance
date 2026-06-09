kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side


# 1. Download the latest binary
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

# 2. Install it to /usr/local/bin
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# 3. Clean up the downloaded file
rm argocd-linux-amd64

kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

echo "Patching to nodeport"
bash $PWD/argocd/patch-nodeport.sh

#argocd account update-password --current-password $argoPassword --new-password 'Admin123!' --insecure --plaintext

echo ">>> Configuring Argo CD octopus account..."
kubectl patch configmap argocd-cm \
  -n argocd \
  --type merge \
  -p '{"data":{"accounts.octopus":"apiKey,login","accounts.octopus.enabled":"true"}}' \
  && echo "✓ argocd-cm patched" || echo "✗ argocd-cm patch failed"

kubectl patch configmap argocd-rbac-cm \
  -n argocd \
  --type merge \
  -p '{"data":{"policy.csv":"p, octopus, applications, get, *, allow\np, octopus, applications, sync, *, allow\np, octopus, clusters, get, *, allow\np, octopus2, logs, get, */*, allow"}}' \
  && echo "✓ argocd-rbac-cm patched" || echo "✗ argocd-rbac-cm patch failed"

kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}'
kubectl rollout restart deployment argocd-server -n argocd

echo ""
echo "checking rollout status of argocd"

kubectl rollout status deployment/argocd-server -n argocd --timeout=120s

echo "Getting initial admin secret from argocd"

argoPassword=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo)
echo "Got admin password. Attempting login"
argocd login localhost:9443 --username admin --password $argoPassword --insecure --plaintext

echo "Creating password for octopus user in argocd"

argocd account update-password \
  --account octopus \
  --new-password 'Admin123!' \
  --current-password $argoPassword \
  --insecure \
  --plaintext

  echo "Finished configuring argocd!"