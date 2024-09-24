# Assignment
  POC local dev env with k8s and argo


# Comparison
## [Kubernetes via Docker Desktop]( https://docs.docker.com/desktop/kubernetes/):
    Advantages:
      - Built in
      - Ease of development (such as pullsecrets, ingress port forwarding)
    Disadvantages:
      - Mac only
      - No reset capatability of the cluster via the cli
      - Cannot change k8 version without re-installing dmg file

## [Kind]( https://kind.sigs.k8s.io/)
    Advantages:
      - Ability to have an HA configuraiton
      - Supports mac/windows/linux installations
    Disadvantages:
      - Pull secret configuration (low effort to solve)



# Components installed in demo
1. Metrics server (for basic pod resource metrics)
2. Argocd 
3. Traefik (for ingress)

# Pre-setup (for Macs)
1. [Install Docker](https://docs.docker.com/desktop/install/mac-install/)
2. [Enable kubernetes in docker]( https://docs.docker.com/desktop/kubernetes/)
3. Install required tools via homebrew:
  ` brew install kubernetes-cli helm `
4. Add this line to your /etc/hosts file:
  ` 127.0.0.1       argocd.va.local`

# Getting started with Docker-desktop
1. type `kubectl config use-context docker-deskop`
2. run `make all`
3. run `make demo-apps`
4. Navigate to your new local argo instance argocd.va.local

When finished, run `make delete`

# Getting started with kind
1. type `make kind-all`
2. run `make demo-apps`
3. Navigate to your new local argo instance argocd.va.local

When finished, run `make kind-delete`