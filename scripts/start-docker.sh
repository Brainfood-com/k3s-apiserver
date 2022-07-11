#!/bin/bash

set -e

APISERVER_DIR="$(cd "$(dirname "$0")/.."; echo "$PWD")"
export APISERVER_DIR

. "$APISERVER_DIR/scripts/_parse_args.bash"

case "$1" in
	(switch-to)
		"$APISERVER_DIR/scripts/update-docker-kubeconfig.sh" "$CONTEXT_DIR"
		exit
		;;
	("")
		;;
	(*)
		echo "Unknown command: $1" 1>&2
		exit 1
		;;
esac

"$APISERVER_DIR/scripts/ensure-certs.sh"
"$APISERVER_DIR/scripts/wait-for-etcd.sh" "$CONTEXT_DIR"

_compose up -d k3s-master-1
"$APISERVER_DIR/scripts/update-docker-kubeconfig.sh" "$CONTEXT_DIR"
"$APISERVER_DIR/scripts/wait-for-master-1.sh"

_compose up -d k3s-coredns-1 k3s-coredns-2 k3s-coredns-3
"$APISERVER_DIR/scripts/install-cluster-dns.sh" "$CONTEXT_DIR"
_compose up -d k3s-agent-1 k3s-agent-2 "${k8s_nodes[@]}"
_compose up -d k3s-master-2 k3s-master-3
"$APISERVER_DIR/scripts/wait-for-system-pods.sh" 1
#_compose up -d k3s-proxy

#[[ ${features[istio]} ]] && istioctl install -yf "$APISERVER_DIR/istio-minimal-operator.yaml"

cd "$APISERVER_DIR"

#helmfile apply
