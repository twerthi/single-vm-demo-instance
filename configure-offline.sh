echo "Configuring local registry for offline installation..."
docker run -d -p 5000:5000 --restart=always --name registry --network octopusdeploy_default registry:3

echo "Pulling Argo CD images for offline installation..."

curl -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  | grep "image:" | sort -u | awk '{print $2}' \
  | while read image; do
      echo "==> Pulling: $image"
      docker pull "$image"


      echo "==> Pushing: $image to local registry"
      docker tag "$image" "localhost:5000/$image"
      docker push "localhost:5000/$image"
      #kind load docker-image "$image" --name kind
#      kind load image-archive "$FILENAME" --name kind
    done

echo "Patching Argo CD manifests to use local registry..."

# Get all deployments in argocd namespace
kubectl get deployments -n argocd -o name | while read deploy; do
  echo "Patching $deploy..."
  kubectl get "$deploy" -n argocd -o json \
    | jq '(.spec.template.spec.containers[].image) |= 
        gsub("quay.io"; "registry:5000/quay.io") |
        gsub("ghcr.io"; "registry:5000/ghcr.io")' \
    | kubectl apply -f -
done