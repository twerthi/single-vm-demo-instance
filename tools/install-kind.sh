#! /bin/bash

# https://oneuptime.com/blog/post/2026-02-26-argocd-with-kind/view
# or using Brew on MacOs

if command -v kind >/dev/null 2>&1; then
    echo "Info: kind is already installed." >&2
    exit 0
fi
OS=$(uname -s)
if [ "$OS" = "Darwin" ]; then
    brew install kind
elif [ "$OS" = "Linux" ]; then
    [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.26.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
else
    echo "Unsupported OS: $OS"
    exit 1
fi
