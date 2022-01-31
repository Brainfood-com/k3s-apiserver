#!/bin/bash

set -e

needed_pods="$1"

echo "Waiting for cluster to be ready"
declare -i column_count=0 system_pod_count=0
while :; do
	system_pods="$(kubectl get pods --namespace kube-system --no-headers 2>/dev/null || true)"
	column_count="$(($column_count + 1))"
	if [[ -z $system_pods ]]; then
		echo -n "."
	else
		system_pod_count="$(egrep -ci '1/1[[:space:]]+Running' <<< "$system_pods" || true)"
		echo -n "$system_pod_count"
		if [[ $system_pod_count -eq ${needed_pods} ]]; then
			break
		fi
	fi
	if [[ $column_count -eq 40 ]]; then
		echo
		column_count=0
	fi
	sleep 1
done
if [[ $column_count -ne 0 ]]; then
	echo
	column_count=0
fi
