#!/usr/bin/env bash

SEALOS_DIR="$PWD/.sealos"
SEALOS_BIN="$PWD/sealos"

APISERVER="$1"
APISERVER_SLB="$2"

K8S="/etc/kubernetes"
K8S_CA='/etc/kubernetes/pki/ca.crt'
K8S_CA_KEY='/etc/kubernetes/pki/ca.key'
ETCD_CA='/etc/kubernetes/pki/etcd/ca.crt'
ETCD_CA_KEY='/etc/kubernetes/pki/etcd/ca.key'
FRONT_PROXY_CA='/etc/kubernetes/pki/front-proxy-ca.crt'
FRONT_PROXY_CA_KEY='/etc/kubernetes/pki/front-proxy-ca.key'
SA_PUB='/etc/kubernetes/pki/sa.pub'
SA_KEY='/etc/kubernetes/pki/sa.key'

ADMIN_KUBE_CONFIG='/etc/kubernetes/admin.conf'
CONTROLLER_MANAGE_KUBE_CONFIG='/etc/kubernetes/controller-manager.conf'
SCHEDULER_KUBE_CONFIG='/etc/kubernetes/scheduler.conf'

function exitWhenFileDoesNotExist() {
  if [ ! -f "$1" ]; then
    echo "$1 is not exists"
    exit 1
  fi
}

function checkCA() {
  exitWhenFileDoesNotExist $K8S_CA
  exitWhenFileDoesNotExist $K8S_CA_KEY
  exitWhenFileDoesNotExist $ETCD_CA
  exitWhenFileDoesNotExist $ETCD_CA_KEY
  exitWhenFileDoesNotExist $FRONT_PROXY_CA
  exitWhenFileDoesNotExist $FRONT_PROXY_CA_KEY
  exitWhenFileDoesNotExist $SA_PUB
  exitWhenFileDoesNotExist $SA_KEY
}

function checkKubeConfig() {
  exitWhenFileDoesNotExist $ADMIN_KUBE_CONFIG
  exitWhenFileDoesNotExist $CONTROLLER_MANAGE_KUBE_CONFIG
  exitWhenFileDoesNotExist $SCHEDULER_KUBE_CONFIG
}

function checkDirectory() {
  if [ -e "${SEALOS_DIR}.bak" ]; then
    echo "${SEALOS_DIR}.bak is already exists"
    exit 1
  fi

  if [ -e "${K8S}.bak" ]; then
    echo "${K8S}.bak is already exists"
    exit 1
  fi
}

function preCheck() {
  checkCA
  checkKubeConfig
  checkDirectory
}

function copyCAs() {
  if [ -d "$SEALOS_DIR" ]; then
    if ! mv "$SEALOS_DIR" "${SEALOS_DIR}.bak"; then
      exit
    fi
  fi

  if ! mkdir "$SEALOS_DIR" "$SEALOS_DIR/pki" "$SEALOS_DIR/pki/etcd"; then
    exit 1
  fi

  if ! cp $K8S_CA $K8S_CA_KEY $FRONT_PROXY_CA $FRONT_PROXY_CA_KEY $SA_PUB $SA_KEY "$SEALOS_DIR/pki"; then
    exit 1
  fi

  if ! cp $ETCD_CA $ETCD_CA_KEY "$SEALOS_DIR/pki/etcd"; then
    exit 1
  fi
}

function generateCerts() {
  SERVICE_CIDR=$(grep 'service-cluster-ip-range' /etc/kubernetes/manifests/kube-apiserver.yaml | cut -d "=" -f 2)
  MASTER_NAMES=$(kubectl get node -l node-role.kubernetes.io/master -o=jsonpath='{.items[*].metadata.name}' | tr -s ' ' ',')
  MASTER_IPS=$(kubectl get node -l node-role.kubernetes.io/master -o=jsonpath='{.items[*].status.addresses[?(.type=="InternalIP")].address}' | tr -s ' ' ',')
  $SEALOS_BIN cert \
    --cert-path "$SEALOS_DIR/pki" \
    --cert-etcd-path "$SEALOS_DIR/pki/etcd" \
    --alt-names "$APISERVER_SLB" \
    --service-cidr "$SERVICE_CIDR" \
    --node-ips "$MASTER_IPS" \
    --node-names "$MASTER_NAMES"
}

function generateKubeConfig() {
  $SEALOS_BIN kubeconfig \
    --api-server "$APISERVER"
}

function copyCertsAndKubeConfig() {
  cp -r "$K8S" "${K8S}.bak"

  for f in "$SEALOS_DIR"/*; do
    cp -r "$f" "${K8S}/"
  done
}

function dockerStopContainer() {
  docker kill -s "SIGTERM" "$(docker ps | grep "$1" | awk '{print $1}')"
}

function restartControlPlaneComponents() {
  #  kube-apiserver
  dockerStopContainer k8s_kube-apiserver

  # kube-controller-manager
  dockerStopContainer k8s_kube-controller-manager

  # kube-scheduler
  dockerStopContainer k8s_kube-scheduler

  # etcd
  dockerStopContainer k8s_etcd_etcd
}

function main() {
  chmod +x $SEALOS_BIN

  if ! preCheck; then
    exit 1
  fi

  if ! copyCAs; then
    exit 1
  fi

  if ! generateCerts; then
    exit 1
  fi

  if ! generateKubeConfig; then
    exit 1
  fi

  if ! copyCertsAndKubeConfig; then
    exit 1
  fi

  restartControlPlaneComponents
}

function usage() {
    echo "Usage: bash k8s-certs-renew <apiserver> <apiserver-slb>"
}

if [ -z "$1" ]; then
  echo "ApiServer is not set"
  usage
  exit 1
fi

if [ -z "$2" ]; then
  echo "ApiServer is not set"
  usage
  exit 1
fi

main
