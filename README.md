## Purpose

This project spins up an environment that can be used for kicking the tires on Octopus Deploy, used for a workshop, or a self-contained instance for conferences with limited or no network connectivity.  This project assumes you have Docker installed and uses several Docker Compose files to spin up:

- Octopus Deploy server
- Gitea server
  - Git repository
  - Build runner
  - Container registry
- Kubernetes cluster
  - Argo CD

## Starting the environment

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

## Usage
All of the components of this environment run within Docker, they are all on the same Docker network so their hostnames can be resolveable.  To simplify things, all servers communicate via HTTP

### Servers
- Octopus Deploy server
  - Hostname: octopus
  - URL: http://localhost:8080
- Gitea server
  - Hostname: gitea
  - URL: http://localhost:3000
- KInD Kubernetes server
  - Hostname: kind-control-plane (Won't really need this one)
- Argo CD
  - Hostname: Installed on KInD server
  - URL: http://localhost:8090

##### Inter server communication
When the servers need to talk to eachother, such as the repo url for Argo CD to watch, they need to refer to eachother by hostname and port.  For example, in the example given, the `repoURL` section of the Argo CD Application Manifest would look similar to this:

```yaml
...
    spec:
      project: default
      source:
        repoURL: http://gitea:3000/admin/instruqt-sample-applications.git
        targetRevision: HEAD
...
```

Similarly, when you install the Kubernetes Agent or the Argo CD Gateway for Octopus Deploy, the wizard will use the location from you address bar; http://localhost:8080.  This will need to be changed to `http://octopus:8080`.  Please note that all inter server communication takes place over `HTTP`, not `HTTPS`.  Any references, such as the Octopus wizards, will use https by default and must be changed to http instead.