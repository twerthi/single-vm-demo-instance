#! /bin/bash
if command -v kubectl >/dev/null 2>&1; then
    echo "Info: kubectl is already installed." >&2
    exit 0
fi

OS=$(uname -s)
if [ "$OS" = "Darwin" ]; then
    brew install helm
elif [ "$OS" = "Linux" ]; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
else
    echo "Unsupported OS: $OS"
    exit 1
fi