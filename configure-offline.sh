echo "Pulling Argo CD images for offline installation..."

curl -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  | grep "image:" | sort -u | awk '{print $2}' \
  | while read image; do
      echo "==> Pulling: $image"
      docker pull "$image"

      echo "==> Pushing: $image to local registry"
      #docker tag "$image" "localhost:5000/$image"
      #docker push "localhost:5000/$image"
      kind load docker-image "$image" --name kind
    done