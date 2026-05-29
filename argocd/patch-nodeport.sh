# Patch the argocd-server service to NodePort on port 30443
kubectl patch svc argocd-server -n argocd --type merge -p '{
  "spec": {
    "type": "NodePort",
    "ports": [
      {
        "name": "https",
        "port": 443,
        "targetPort": 8080,
        "nodePort": 30443
      },
      {
        "name": "http",
        "port": 80,
        "targetPort": 8080,
        "nodePort": 30080
      }
    ]
  }
}'