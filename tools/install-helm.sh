#! /bin/bash

if command -v helm >/dev/null 2>&1; then
    echo "Info: helm is already installed." >&2
    exit 0
fi

OS=$(uname -s)
if [ "$OS" = "Darwin" ]; then
    brew install helm
elif [ "$OS" = "Linux" ]; then
    sudo apt-get install curl gpg apt-transport-https --yes
    curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update
    sudo apt-get install helm --yes
else
    echo "Unsupported OS: $OS"
    exit 1
fi