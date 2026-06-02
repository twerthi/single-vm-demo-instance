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

# kubectl get deployments -n argocd -o name | while read deploy; do
#   echo "Patching $deploy..."
  
#   # Get current images and build a patch
#   kubectl get "$deploy" -n argocd -o jsonpath='{.spec.template.spec.containers[*].name} {.spec.template.spec.containers[*].image}' | \
#   awk '{
#     n = NF/2
#     for (i=1; i<=n; i++) {
#       name = $i
#       image = $(i+n)
#       print name, image
#     }
#   }' | while read cname cimage; do
#     newimage="registry:5000/$cimage"
#     echo "  $cname: $cimage -> $newimage"
#     kubectl patch "$deploy" -n argocd --type=json \
#       -p "[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/image\",\"value\":\"$newimage\"}]"
#   done
# done

# kubectl get statefulsets -n argocd -o name | while read deploy; do
#   echo "Patching $deploy..."
  
#   # Get current images and build a patch
#   kubectl get "$deploy" -n argocd -o jsonpath='{.spec.template.spec.containers[*].name} {.spec.template.spec.containers[*].image}' | \
#   awk '{
#     n = NF/2
#     for (i=1; i<=n; i++) {
#       name = $i
#       image = $(i+n)
#       print name, image
#     }
#   }' | while read cname cimage; do
#     newimage="registry:5000/$cimage"
#     echo "  $cname: $cimage -> $newimage"
#     kubectl patch "$deploy" -n argocd --type=json \
#       -p "[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/image\",\"value\":\"$newimage\"}]"
#   done
# done

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