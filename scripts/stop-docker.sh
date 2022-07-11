#!/bin/bash

set -e

APISERVER_DIR="$(cd "$(dirname "$0")/.."; echo "$PWD")"
export APISERVER_DIR

. "$APISERVER_DIR/scripts/_parse_args.bash"

_compose down "$@"

