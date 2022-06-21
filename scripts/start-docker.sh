#!/bin/bash

set -e

TOP_DIR="$(cd "$(dirname "$0")/.."; echo "$PWD")"
export TOP_DIR

. "$TOP_DIR/scripts/_parse_args.bash"

case "$1" in
	(switch-to)
		"$TOP_DIR/scripts/update-docker-kubeconfig.sh" "$CONTEXT_DIR"
		exit
		;;
	("")
		;;
	(*)
		echo "Unknown command: $1" 1>&2
		exit 1
		;;
esac

"$TOP_DIR/scripts/ensure-certs.sh"
"$TOP_DIR/scripts/wait-for-etcd.sh"

docker-compose -f "$TOP_DIR/docker-compose.yaml" up -d k3s-master-1
"$TOP_DIR/scripts/update-docker-kubeconfig.sh" "$CONTEXT_DIR"
"$TOP_DIR/scripts/wait-for-master-1.sh"

docker-compose -f "$TOP_DIR/docker-compose.yaml" up -d k3s-coredns-1 k3s-coredns-2 k3s-coredns-3
"$TOP_DIR/scripts/install-cluster-dns.sh"
docker-compose -f "$TOP_DIR/docker-compose.yaml" up -d k3s-agent-1 k3s-agent-2
docker-compose -f "$TOP_DIR/docker-compose.yaml" up -d k3s-master-2 k3s-master-3
"$TOP_DIR/scripts/wait-for-system-pods.sh" 2

#docker-compose -f "$TOP_DIR/docker-compose.yaml" up -d k3s-proxy

[[ ${features[istio]} ]] && istioctl install -yf "$TOP_DIR/istio-minimal-operator.yaml"

cd "$TOP_DIR"

helmfile --debug apply
