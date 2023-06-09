#!/bin/bash

set -e

CONTEXT_DIR="$1"

TOP_DIR="$(cd "$(dirname "$0")/.."; echo "$PWD")"
export TOP_DIR

CONTEXT_DIR="$1"

_compose() {
	docker-compose --project-directory "$CONTEXT_DIR" -f "$TOP_DIR/docker-compose.yaml" "$@"
}

tmpd="$(mktemp -d)"
onexit() {
	[[ $tmpd ]] && rm -rf "$tmpd"
}

trap onexit EXIT

# TODO: Check $TOP_DIR

declare -i count=10
while [[ $count > 0 ]]; do
	if _compose exec -T k3s-master-1 cat /output/kubeconfig.yaml > "$tmpd/config.docker" 2>/dev/null; then
		break
	fi
	sleep 1
	count=$(($count - 1))
done
chmod 600 "$tmpd/config.docker"

MASTER_IP=$(_compose exec -T k3s-master-1 ping -c 1 -q k3s-master-1 | sed -n 's/^PING.*(\(.*\)).*/\1/p')

kubectl config --kubeconfig="$tmpd/config.docker" view --raw=true -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 -d > "$tmpd/cluster-certificate-authority"
kubectl config --kubeconfig="$tmpd/config.docker" view --raw=true -o jsonpath='{.users[].user.client-certificate-data}' | base64 -d > "$tmpd/client-certificate"
kubectl config --kubeconfig="$tmpd/config.docker" view --raw=true -o jsonpath='{.users[].user.client-key-data}' | base64 -d > "$tmpd/client-key"

kubectl config set-cluster "$CONTEXT_DIR" --embed-certs=true --server="https://$MASTER_IP:6443" --certificate-authority="$tmpd/cluster-certificate-authority" > /dev/null
kubectl config set-credentials "$CONTEXT_DIR" --embed-certs=true --client-certificate="$tmpd/client-certificate" --client-key="$tmpd/client-key" > /dev/null
kubectl config set-context "$CONTEXT_DIR" --cluster="$CONTEXT_DIR" --user="$CONTEXT_DIR" > /dev/null
kubectl config use-context "$CONTEXT_DIR"

