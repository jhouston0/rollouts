.PHONY: install traefik argocd argo-pw demo-apps delete kind-cluster kind-delete

#NOTE the K8_VERSION is only for kind clusters. Docker Desktop you have to take what it gets you.
K8_VERSION = 1.29
#argocd versions https://github.com/argoproj/argo-cd/releases
#ARGOCD_VERSION := 2.4.6
ARGOCD_VERSION := 2.12.3
#traefik chart url https://github.com/traefik/traefik-helm-chart/
TRAEFIK_CHART_VER := 23.2.0

all: install argocd traefik argo-pw

all-kind: kind-cluster install argocd traefik argo-pw

pre: 
	brew install argoproj/tap/kubectl-argo-rollouts
	brew install --cask openlens
 
install: 
	kubectl apply -f metrics/metrics-server.yaml
	helm repo add traefik https://traefik.github.io/charts || true

traefik:
	helm repo add traefik https://traefik.github.io/charts ; helm repo update || true
	kubectl create ns traefik || true
	helm upgrade -i -n traefik traefik traefik/traefik --version $(TRAEFIK_CHART_VER)
	kubectl apply -f ingress.yaml

argocd:
	@kubectl get namespace argocd || kubectl create namespace argocd
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v$(ARGOCD_VERSION)/manifests/install.yaml
	@sleep 10 # Give some time for resources to be created before querying for the secret
	@kubectl get secrets -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode && echo

argo-rollouts:
	kubectl create namespace argo-rollouts || true
	kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
	kubectl apply -k https://github.com/argoproj/argo-rollouts/manifests/crds\?ref\=stable
	sleep 15
	cd rollouts/plugin && kubectl patch configmaps -n argo-rollouts argo-rollouts-config --patch "$(cat prometheus.yaml)"

argo-pw:
	@echo "username: admin"
	@echo "password:"; kubectl get secrets -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode ; echo

demo-apps:	
	kubectl apply -f demo-apps.yaml

delete:
	kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v$(ARGOCD_VERSION)/manifests/install.yaml
	helm delete -n traefik traefik
	kubectl delete -f argocd/demo-apps.yaml

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


#promehteus patch
# kubectl patch ds prometheus-prometheus-node-exporter  --type "json" -p '[{"op": "remove", "path" : "/spec/template/spec/containers/0/volumeMounts/2/mountPropagation"}]'