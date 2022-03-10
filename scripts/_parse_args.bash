#!/bin/bash

CONTEXT_DIR="$TOP_DIR"

declare -a args
declare -A features=(
	[cert-manager]=1
	[istio]=1
)

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
