## Purpose

This project spins up an environment that can be used for kicking the tires on Octopus Deploy, used for a workshop, or a self-contained instance for conferences with limited or no network connectivity.  This project assumes you have Docker installed and uses several Docker Compose files to spin up:

- Octopus Deploy server
- Gitea server
  - Git repository
  - Build runner
  - Container registry
- Kubernetes cluster
  - Argo CD

### MacOs Requirements:
 - [Brew](https://brew.sh/)
 
## Starting the environment

This project was meant to be easy for anyone to get up and running quickly.  Once the repo has been cloned, simply run `configure-server.sh` to get up and running.  **Note** The script assumes you have Docker installed, other than that, it's plug-n-play.

### Other scripts in the folder
There are two other scripts within the folder to make note of:
- reset-server.sh
- stop-containers.sh
- start-containers.sh
- configure-offline.sh

#### reset-server.sh
`reset-server.sh` does exactly what it sounds like, deletes all data and containers to completely reset everything.  Use this if you want to start over or just clean up.

#### stop-containers.sh
`stop-containers` stops ALL running containers on the host.  This script assumes that the VM is strictly for testing out Octopus, use with caution.

#### start-containers.sh
`start-containers` starts ALL containers that are listed in `docker ps -a`, use with caution.

#### configure-offline.sh
**Warning** This script is currently under development.  As the name implies, it configures all containers to run without Internet connectivity.  This requires a local Docker container registry be spun up and all reliant images uploaded to it:
- Argo CD images
- Octopus Deploy worker tools image
- Microsoft .NET images so the Gitea build process can still build the container
- Moby image for `docker buildx` commands
- Ubuntu-latest image for Gitea build agent

## Octopus Server license
The Octopus Server license is intentionally blank within the `.env` file for Docker Compose.  Please be aware that everything will configure and start correctly, but Octopus will not be able to add items until a valid license has been added.  This can be done via:
- base64 encoding your license key and adding the value to the `octopusdeploy.env` file
- Pasting the license using the Octopus Deploy UI

## Usage
All of the components of this environment run within Docker, they are all on the same Docker network so their hostnames can be resolveable.  To simplify things, all servers communicate via HTTP.

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

#### Offline mode
If you've configured your instance to be in offline mode, an additional server (container) is created to serve as a local Docker container registry
- Registry server
  - Hostname: registry
  - URL http://localhost:5000

**Note**:  All ports are configured with `0.0.0.0`, meaning you can access these URLs from another machine - `http://<machine name>:<port>`

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

#### Authentication
All servers are configured to use a default username and password, if you need to change this, it will need to be updated within the script files.
- Username: admin
- Password: Admin123!

##### Argo CD
Argo CD is the only exception to the default username and password.  The initial admin password can be retrieved

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

To support Octopus connectivity, the configuration process creates a new user in Argo CD:
- Username: octopus
- Password: Admin123!