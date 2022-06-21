#!/bin/bash

set -e

TOP_DIR="$(cd "$(dirname "$0")/.."; echo "$PWD")"
export TOP_DIR

. "$TOP_DIR/scripts/_parse_args.bash"

docker-compose -f "$TOP_DIR/docker-compose.yaml" down "$@"

