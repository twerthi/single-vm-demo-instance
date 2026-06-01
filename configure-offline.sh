echo "Pulling Argo CD images for offline installation..."
mkdir $PWD/argocd/localimages

curl -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
  | grep "image:" | sort -u | awk '{print $2}' \
  | while read image; do
      NAME=$(echo "$image" | awk -F'/' '{print $NF}' | cut -d':' -f1)
      TAG=$(echo "$image"  | awk -F':' '{print $NF}')
      FILENAME="${PWD}/argocd/localimages/${NAME}_${TAG}.tar"
      echo "==> Pulling: $image"
      docker pull "$image"
      docker save -o "$FILENAME" "$image"

      echo "==> Pushing: $image to local registry"
      #docker tag "$image" "localhost:5000/$image"
      #docker push "localhost:5000/$image"
      #kind load docker-image "$image" --name kind
      kind load image-archive "$FILENAME" --name kind
    done