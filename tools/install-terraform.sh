# Install unzip for terraform install
if ! command -v unzip >/dev/null 2>&1; then
  apt-get install -y -q unzip
fi

if ! command -v terraform >/dev/null 2>&1; then
  curl -fsSL https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip -o /tmp/terraform.zip
  unzip -q /tmp/terraform.zip -d /usr/local/bin/
  rm /tmp/terraform.zip
fi
