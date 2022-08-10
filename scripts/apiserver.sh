#!/bin/bash
set -e

APISERVER_DIR="$(cd "$(dirname "$0")/.."; echo "$PWD")"
export APISERVER_DIR

CONTEXT_DIR="$APISERVER_DIR"

declare -a args
declare -A features=(
	[cert-manager]=1
	[istio]=1
)
declare -a compose_files=(-f "$APISERVER_DIR/docker-compose.yaml")
declare -a k8s_nodes=()
declare -i agent_count=2

while [[ $# -gt 0 ]]; do
	arg="$1"
	shift
	case "$arg" in
		(--context-dir)
			CONTEXT_DIR="$1"
			shift
			;;
		(--feature)
			features[$1]=1
			shift
			;;
		(--no-feature)
			features[$1]=
			shift
			;;
		(-f)
			compose_files+=(-f "$1")
			shift
			;;
		(--agent-count)
			agent_count="$1"
			shift
			;;
		(-n)
			k8s_nodes+=("$1")
			shift
			;;
		(*)
			args+=("$arg")
			;;
	esac
done

_create_agent_compose() {
	sed -e "s/agent-1/agent-$1/g" < "$APISERVER_DIR/agent-compose.yaml"
}

set -- "${args[@]}"

for feature in "${!features[@]}"; do
	fixed_feature="${feature^^*}"
	fixed_feature="${fixed_feature//-/_}"
	feature_enabled=false
	[[ ${features[$feature]} ]] && feature_enabled=true
	eval "${fixed_feature}_ENABLED"="$feature_enabled"
	export "${fixed_feature}_ENABLED"
done

export CONTEXT_DIR

ETCD_ENDPOINTS="http://etcd1:2380,http://etcd2:2380,http://etcd3:2380"

declare -a animations=('-' '\' '|' '/')
declare -i animation_index=0

_compose() {
	declare -a agent_files
	declare -i agent_index=0
	for ((agent_index=1; agent_index < $(($agent_count + 1)); agent_index++)); do
		agent_files+=("-f <(_create_agent_compose $agent_index)")
	done
	eval docker-compose --project-directory "$CONTEXT_DIR" "${compose_files[@]}" "${agent_files[@]}" "$@"
}
declare -i agent_index=0
for ((agent_index=1; agent_index < $(($agent_count + 1)); agent_index++)); do
	k8s_nodes+=(k3s-agent-$agent_index)
done

etcdctl() {
	_compose exec etcd1 etcdctl "$@"
}


_start_animation() {
	animation_index=0
	animation_message="$1"
}

_animation_progress() {
	printf "$animation_message: %s %s\r" "${animations[$animation_index]}" "$1"
	animation_index=$(( ($animation_index + 1) % ${#animations[*]} ))
}

_stop_animation() {
	printf "\r\33[2K"
	if [[ $1 -eq 0 ]]; then
		printf "$animation_message: done\n"
	else
		printf "$animation_message: error\n"
	fi
}

_wait_for_etcd() {
	declare -i cnt=5
	_start_animation 'Waiting for etcd cluster'
	while [ $cnt -ne 0 ]; do
		_animation_progress
		_compose up -d etcd1 etcd2 etcd3 1>/dev/null 2>/dev/null
		if etcdctl --endpoints "$ETCD_ENDPOINTS" endpoint health 1>/dev/null 2>/dev/null; then
			if [ $cnt -ne 5 ]; then
				printf ' '
			fi
			_stop_animation 0
			return
		fi
		sleep 1
		cnt=$(($cnt - 1))
	done
	_stop_animation 1
	echo "etcd failed to initialize!" 1>&2
	exit 1
}

_wait_for_master() {
	declare -i cnt=10
	_start_animation "Waiting for k3s-master-1"
	while [ $cnt -ne 0 ]; do
		_animation_progress
		if kubectl get --raw '/readyz' > /dev/null 2>/dev/null; then
			if [ $cnt -ne 10 ]; then
				printf ' '
			fi
			_stop_animation 0
			return
		fi
		sleep 1
		cnt=$(($cnt - 1))
	done
	_stop_animation 1
	echo 'k3s-master-1 failed to initialize!' 1>&2
	exit 1
}

_wait_for_system_pods() {
	declare -i wanted got total
	declare -A items
	declare -a output
	declare item output
	for item in "$@"; do
		items[$item]=0/0
	done
	_start_animation "Waiting for system pods"
	while :; do
		total=$#
		while read item status rest; do
			wanted=${status%/*}
			got=${status%*/}
			if [[ $wanted -eq $got && ! $wanted -eq 0 ]]; then
				total=$(($total - 1))
			fi
			items[$item]="$status"
		done < <(kubectl get --namespace kube-system --no-headers --show-kind "$@" 2>/dev/null || true)
		output=()
		for item in "$@"; do
			: item "$item"
			output+=("${items[$item]}")
		done
		_animation_progress "${output[*]}"
		if [[ $total -eq 0 ]]; then
			break
		fi
		sleep 1
	done
	_stop_animation 0
}

_wait_for_system() {
	_wait_for_system_pods deployment.apps/metrics-server
}

cmd="$1"
shift
case "$cmd" in
	(switch-to)
		"$APISERVER_DIR/scripts/update-docker-kubeconfig.sh" "$CONTEXT_DIR"
		exit
		;;
	(wait-for-system)
		_wait_for_system
		;;
	(start)
		# Verify that the compose files have valid syntax.
		if ! _compose ls 1>/dev/null 2>/dev/null; then
			_compose ls
		fi

		"$APISERVER_DIR/scripts/ensure-certs.sh" "$CONTEXT_DIR"
		_wait_for_etcd

		_compose up -d k3s-master-1
		"$APISERVER_DIR/scripts/update-docker-kubeconfig.sh" "$CONTEXT_DIR"
		_wait_for_master

		_compose up -d k3s-coredns-1 k3s-coredns-2 k3s-coredns-3
		"$APISERVER_DIR/scripts/install-cluster-dns.sh" "$CONTEXT_DIR"
		_compose up -d "${k8s_nodes[@]}"
		_compose up -d k3s-master-2 k3s-master-3
		#"$APISERVER_DIR/scripts/wait-for-system-pods.sh" 1
		_wait_for_system
		#_compose up -d k3s-proxy

		#[[ ${features[istio]} ]] && istioctl install -yf "$APISERVER_DIR/istio-minimal-operator.yaml"
		;;
	(stop)
		_compose down "$@"
		;;
	("")
		;;
	(*)
		echo "Unknown command: $1" 1>&2
		exit 1
		;;
esac

