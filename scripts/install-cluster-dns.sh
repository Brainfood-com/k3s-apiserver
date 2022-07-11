#!/bin/sh

set -e
TOP_DIR="$(cd "$(dirname "$0")/.."; echo "$PWD")"
export TOP_DIR

CONTEXT_DIR="$1"
_compose() {
	docker-compose --project-directory "$CONTEXT_DIR" -f "$TOP_DIR/docker-compose.yaml" "$@"
}

COREDNS_IP_1=$(_compose exec -T k3s-master-1 ping -c 1 -q k3s-coredns-1 | sed -n 's/^PING.*(\(.*\)).*/\1/p')
COREDNS_IP_2=$(_compose exec -T k3s-master-1 ping -c 1 -q k3s-coredns-2 | sed -n 's/^PING.*(\(.*\)).*/\1/p')
COREDNS_IP_3=$(_compose exec -T k3s-master-1 ping -c 1 -q k3s-coredns-3 | sed -n 's/^PING.*(\(.*\)).*/\1/p')

kubectl apply -f /dev/stdin << _EOF_
apiVersion: v1
kind: Service
metadata:
  name: compose-dns-external-service
spec:
  clusterIP: 10.43.0.10
  ports:
    - protocol: TCP
      name: dns-tcp
      port: 53
      targetPort: 53
    - protocol: UDP
      name: dns-udp
      port: 53
      targetPort: 53
---
apiVersion: v1
kind: Endpoints
metadata:
  name: compose-dns-external-service
subsets:
  - addresses:
      - ip: $COREDNS_IP_1
      - ip: $COREDNS_IP_2
      - ip: $COREDNS_IP_3
    ports:
      - protocol: TCP
        name: dns-tcp
        port: 53
      - protocol: UDP
        name: dns-udp
        port: 53
_EOF_

