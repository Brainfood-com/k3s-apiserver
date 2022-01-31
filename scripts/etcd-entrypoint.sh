#!/bin/sh
set -ex
chown -R 1000:1000 /bitnami/etcd/data
exec "$@"
