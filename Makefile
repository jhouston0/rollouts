.PHONY: install traefik argocd argo-pw demo-apps delete kind-cluster kind-delete

#NOTE the K8_VERSION is only for kind clusters. Docker Desktop you have to take what it gets you.
K8_VERSION = 1.29
#argocd versions https://github.com/argoproj/argo-cd/releases
# 2.4.6 has an issue with argo rollout extensions (so old)
ARGOCD_VERSION := 2.4.6
#ARGOCD_VERSION := 2.12.3
#traefik chart url https://github.com/traefik/traefik-helm-chart/
TRAEFIK_CHART_VER := 23.2.0

all: base argocd traefik argo-pw

all-kind: kind-cluster install argocd traefik argo-pw

pre: 
	brew install argoproj/tap/kubectl-argo-rollouts
	brew install --cask openlens
	helm repo add traefik https://traefik.github.io/charts || true
 
base: 
	kubectl apply -f metrics/metrics-server.yaml

traefik:
	helm repo add traefik https://traefik.github.io/charts ; helm repo update || true
	kubectl create ns traefik || true
	helm upgrade -i -n traefik traefik traefik/traefik --version $(TRAEFIK_CHART_VER)
	#kubectl apply -f ingress.yaml

argocd-platform:
	@kubectl create namespace argocd || true
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v$(ARGOCD_VERSION)/manifests/install.yaml
	@sleep 15 # Give some time for resources to be created before querying for the secret
	@kubectl get secrets -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode && echo
	@cd argocd ; kubectl patch deployment argocd-server -n argocd --patch-file=patch.yaml
argocd-devops:
	@kubectl create namespace argocd || true
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@sleep 15 # Give some time for resources to be created before querying for the secret
	@kubectl get secrets -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode && echo
	@cd argocd ; kubectl patch deployment argocd-server -n argocd --patch-file=patch.yaml
##use this step when your not trying to mimic dev/stg etc
argo-rollouts:
	kubectl create namespace argo-rollouts || true
	kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
	kubectl apply -k https://github.com/argoproj/argo-rollouts/manifests/crds\?ref\=stable
	sleep 15
	cd rollouts/plugin && kubectl patch configmaps -n argo-rollouts argo-rollouts-config --patch "$(cat prometheus.yaml)"

argo-pw:
	@echo "username: admin"
	@echo "password:"; kubectl get secrets -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode ; echo

argocd-demo-apps:	
	kubectl apply -f argocd-demo-apps.yaml

delete-demo-apps:
	kubectl delete -f rollouts/blue-green-rollout || true
	kubectl delete -f rollouts/canary || true
	kubectl delete -f rollouts/canary-analyze || true
delete-argo:
	kubectl delete -f argocd-demo-apps.yaml || true
	kubectl delete -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
	kubectl delete -k https://github.com/argoproj/argo-rollouts/manifests/crds\?ref\=stable
	#kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v$(ARGOCD_VERSION)/manifests/install.yaml
	@kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

delete-all:
	kubectl delete -f argocd-demo-apps.yaml || true
	#kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v$(ARGOCD_VERSION)/manifests/install.yaml
	@kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	helm delete -n traefik traefik
	kubectl delete -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
	kubectl delete -k https://github.com/argoproj/argo-rollouts/manifests/crds\?ref\=stable
	helm delete -i prometheus prometheus-community/prometheus

#prometheus patch command is for macOS node exporter metrics
prometheus:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
	helm repo update
	helm upgrade -i prometheus prometheus-community/prometheus
	kubectl patch ds prometheus-prometheus-node-exporter  --type "json" -p '[{"op": "remove", "path" : "/spec/template/spec/containers/0/volumeMounts/2/mountPropagation"}]'


##### KIND CLUSTER CONFIGURATION ####
kind-cluster:
	kind create cluster --config kind/cluster.yaml
	kubectl config use-context kind-kind
kind-delete:
	kind delete cluster -n kind