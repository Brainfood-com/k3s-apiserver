#!/bin/sh

set -e

TOP_DIR="$(cd "$(dirname "$0")/.."; echo "$PWD")"
export TOP_DIR

mkdir -p "$TOP_DIR"/certs
if ! [ -e "$TOP_DIR/certs/root.key" ]; then
	openssl genrsa -out "$TOP_DIR/certs/root.key.tmp" 2048
	mv "$TOP_DIR/certs/root.key.tmp" "$TOP_DIR/certs/root.key"
fi
if ! [ -e "$TOP_DIR/certs/root.crt" ]; then
	openssl req -x509 -new -nodes -key "$TOP_DIR/certs/root.key" -subj "/CN=app.local" -days 1024 -reqexts v3_req -extensions v3_ca -out "$TOP_DIR/certs/root.crt.tmp"
	mv "$TOP_DIR/certs/root.crt.tmp" "$TOP_DIR/certs/root.crt"
fi

if ! [ -e "$TOP_DIR/certs/registry.key" ]; then
	openssl genrsa -out "$TOP_DIR/certs/registry.key.tmp" 4096
	mv "$TOP_DIR/certs/registry.key.tmp" "$TOP_DIR/certs/registry.key"
fi
if ! [ -e "$TOP_DIR/certs/registry.crt" ]; then
	openssl req -new -key "$TOP_DIR/certs/registry.key" -config "$TOP_DIR/etc/ssl/registry.conf" -out "$TOP_DIR/certs/registry.csr"
	openssl x509 -req -days 365 -in "$TOP_DIR/certs/registry.csr" -CA "$TOP_DIR/certs/root.crt" -CAkey "$TOP_DIR/certs/root.key" -CAcreateserial -out "$TOP_DIR/certs/registry.crt.tmp" -extfile "$TOP_DIR/etc/ssl/registry-sign.conf"
	mv "$TOP_DIR/certs/registry.crt.tmp" "$TOP_DIR/certs/registry.crt"
fi
