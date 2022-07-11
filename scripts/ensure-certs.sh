#!/bin/sh

set -e

APISERVER_DIR="$(cd "$(dirname "$0")/.."; echo "$PWD")"
export APISERVER_DIR

CONTEXT_DIR="$1"

mkdir -p "$CONTEXT_DIR"/certs
if ! [ -e "$CONTEXT_DIR/certs/root.key" ]; then
	openssl genrsa -out "$CONTEXT_DIR/certs/root.key.tmp" 2048
	mv "$CONTEXT_DIR/certs/root.key.tmp" "$CONTEXT_DIR/certs/root.key"
fi
if ! [ -e "$CONTEXT_DIR/certs/root.crt" ]; then
	openssl req -x509 -new -nodes -key "$CONTEXT_DIR/certs/root.key" -subj "/CN=app.local" -days 1024 -reqexts v3_req -extensions v3_ca -out "$CONTEXT_DIR/certs/root.crt.tmp"
	mv "$CONTEXT_DIR/certs/root.crt.tmp" "$CONTEXT_DIR/certs/root.crt"
fi
