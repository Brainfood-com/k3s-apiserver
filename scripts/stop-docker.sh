#!/bin/sh

set -e

TOP_DIR="$(cd "$(dirname "$0")/.."; echo "$PWD")"
export TOP_DIR

docker-compose -f "$TOP_DIR/docker-compose.yaml" down "$@"

