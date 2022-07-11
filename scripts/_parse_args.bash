#!/bin/bash

CONTEXT_DIR="$APISERVER_DIR"

declare -a args
declare -A features=(
	[cert-manager]=1
	[istio]=1
)
declare -a compose_files=(-f "$APISERVER_DIR/docker-compose.yaml")
declare -a k8s_nodes=()

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
		(-n)
			k8s_nodes+=("$1")
			shift
			;;
		(*)
			args+=("$arg")
			;;
	esac
done
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

_compose() {
	docker-compose --project-directory "$CONTEXT_DIR" "${compose_files[@]}" "$@"
}
