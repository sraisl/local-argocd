* Simple local Kubernetes cluster setup with KinD

## Prerequisites
(run the setup_prequ.sh script - hopefully this will find missing dependencies)

* Docker
* KinD
* kubectl
* helm
* Just

## Setup

- clone the repo ;-)
- set the HOST_PATH variable to the path of a local writeable directory (don't change the "+CLUSTER" part). This will be the ArgoCD applications repo. The directory will be mounted in the argocd-repo-server pod.
- use the get_versions recipe to search for available kubernetes versions. Set the desired version, the required sha256 hash digest will be pulled automatically.
- run the set_config recipe to write the KinD cluster configuration file
- start the cluster with the create_cluster recipe
- install the nginx ingress to get rid of port-forwarding, e.g the ArgoCD ingress points to "argocd.localhost"...
- init the local git repo for ArgoCD before installing ArgoCD itself (recipe init_argocd_git_repo)