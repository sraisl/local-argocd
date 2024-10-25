CLUSTER := "cluster-local"
CONTEXT := "kind-"+CLUSTER
WORKERS := "3"
K8S_VERSION := "v1.23.17"
HOST_PATH := env_var("HOME")+"/"+CLUSTER
CONTAINER_PATH := "/shares"

# list available kindest/node image versions
get_versions:
    @echo "fetching available k8s versions"
    #!/usr/bin/env bash
    ./scripts/k8s-versions.sh list

# helper function to get sha256 digest hash for kindest/node images
get_sha256:
    #!/usr/bin/env bash
    ./scripts/k8s-versions.sh {{ K8S_VERSION }}

# run this recipe after changing one of the variables above
set_config:
    @echo "kind: Cluster\napiVersion: kind.x-k8s.io/v1alpha4\nname: {{ CLUSTER }}\nnodes:\n  - role: control-plane\n    image: kindest/node:{{ K8S_VERSION }}@$(just get_sha256)\n    extraMounts:\n      - hostPath: {{HOST_PATH}}\n        containerPath: {{CONTAINER_PATH}}\n    kubeadmConfigPatches:\n      - |\n        kind: InitConfiguration\n        nodeRegistration:\n          kubeletExtraArgs:\n            node-labels: \"ingress-ready=true\"\n    extraPortMappings:\n      - containerPort: 80\n        hostPort: 80\n        protocol: TCP\n      - containerPort: 443\n        hostPort: 443\n        protocol: TCP" > kind/config.yaml
    @for i in $(seq 1 {{ WORKERS }} ); do \
        echo "  - role: worker" >> kind/config.yaml; \
        echo "    image: kindest/node:{{ K8S_VERSION }}@$(just get_sha256)\n    extraMounts:\n      - hostPath: {{HOST_PATH}}\n        containerPath: {{CONTAINER_PATH}}" >> kind/config.yaml; \
    done
    @mkdir -p {{ HOST_PATH }} || true

create_cluster:
    @kind create cluster --name {{ CLUSTER }} --config kind/config.yaml

delete_cluster:
    kind delete cluster --name {{ CLUSTER }}

delete_hostpath_storage:
    @rm -rf {{ HOST_PATH }}

helm_repo_add:
    @helm repo add argo https://argoproj.github.io/argo-helm || true
    @helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ || true
    @helm repo update

metrics_server_install:
    @helm upgrade --kube-context {{ CONTEXT }} --install --set args={--kubelet-insecure-tls} metrics-server metrics-server/metrics-server --namespace kube-system

nginx_ingress_install:
    @kubectl --context={{ CONTEXT }} apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml && \
    kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=90s

init_argocd_git_repo:
    @[ -d "{{ HOST_PATH }}/repo/app-of-apps/" ] && [ -d "{{ HOST_PATH }}/repo/app-of-apps/.git" ] && echo "local applications repo already created" || (mkdir -p {{ HOST_PATH }}/repo/app-of-apps/applications && git init {{ HOST_PATH }}/repo/app-of-apps)

argocd_local:
    @kubectl --context={{ CONTEXT }} create namespace argocd || true
    @kubectl --context={{ CONTEXT }} apply -f kind/volumes -n argocd
    @helm template --kube-context {{ CONTEXT }} -n argocd argocd --version 7.3.3 argo/argo-cd | kubectl --context {{ CONTEXT }} apply -f -
    @kubectl --context={{ CONTEXT }} patch deployment -n argocd argocd-server --type='json' --patch="[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]"
    @kubectl --context={{ CONTEXT }} apply -f gitops/argocd/selfmanaged.yaml -n argocd
    @kubectl --context={{ CONTEXT }} apply -f gitops/argocd/app-of-apps.yaml -n argocd
    @kubectl --context={{ CONTEXT }} apply -f gitops/argocd/localrepo.yaml

# when using nginx ingress, argocd is reachable at http://argocd.localhost
argocd_ingress:
    @kubectl --context={{ CONTEXT }} -n argocd apply -f ingress/argocd.yaml

# print intial argocd admin password
argo_admin_password:
    @kubectl --context={{ CONTEXT }} -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
