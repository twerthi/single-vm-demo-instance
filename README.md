## Purpose

This project spins up an environment that can be used for kicking the tires on Octopus Deploy, used for a workshop, or a self-contained instance for conferences with limited or no network connectivity.  This project assumes you have Docker installed and uses several Docker Compose files to spin up:

- Octopus Deploy server
- Gitea server
  - Git repository
  - Build runner
  - Container registry
- Kubernetes cluster
  - Argo CD

## Usage

This project was meant to be easy for anyone to get up and running quickly.  Once the repo has been cloned, simply run `configure-server.sh` to get up and running.  **Note** The script assumes you have Docker installed, other than that, it's plug-n-play.

### Other scripts in the folder
There are two other scripts within the folder to make note of:
- reset-server.sh
- stop-containers.sh

#### reset-server.sh
`reset-server.sh` does exactly what it sounds like, deletes all data and containers to completely reset everything.  Use this if you want to start all the way over or just clean up.

#### stop-containers.sh
`stop-containers` stops ALL running containers on the host.  This script assumes that the VM is strictly for testing out Octopus, use with caution.

## Octopus Server license
The Octopus Server license is intentionally blank within the `.env` file for Docker Compose.  Please be aware that everything will configure and start correctly, but Octopus will not be able to add items until a valid license has been added.  This can be done via:
- base64 encoding your license key and adding the value to the `octopusdeploy.env` file
- Pasting the license using the Octopus Deploy UI