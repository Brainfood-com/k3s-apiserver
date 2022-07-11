#!/bin/sh

set -e

TOP_DIR="$(cd "$(dirname "$0")/.."; echo "$PWD")"
export TOP_DIR

CONTEXT_DIR="$1"
ETCD_ENDPOINTS="http://etcd1:2380,http://etcd2:2380,http://etcd3:2380"

_compose() {
	docker-compose --project-directory "$CONTEXT_DIR" -f "$TOP_DIR/docker-compose.yaml" "$@"
}

etcdctl() {
	_compose exec etcd1 etcdctl "$@"
}

cnt=5
printf 'Waiting for etcd cluster: '

while [ $cnt -ne 0 ]; do
	_compose up -d etcd1 etcd2 etcd3 1>/dev/null 2>/dev/null
	if etcdctl --endpoints "$ETCD_ENDPOINTS" endpoint health 1>/dev/null 2>/dev/null; then
		if [ $cnt -ne 5 ]; then
			printf ' '
		fi
		printf 'done\n'
		exit
	fi
	printf '.'
	sleep 1
	cnt=$(($cnt - 1))
done
printf ' error\n'

echo "etcd failed to initialize!" 1>&2
exit 1
