#!/bin/sh

cnt=10
printf 'Waiting for k3s-master-1: '
while [ $cnt -ne 0 ]; do
	if kubectl get --raw '/readyz' > /dev/null 2>/dev/null; then
		if [ $cnt -ne 10 ]; then
			printf ' '
		fi
		printf 'done\n'
		exit
	fi
	printf '.'
	sleep 1
	cnt=$(($cnt - 1))
done
printf ' error\n'

echo 'k3s-master-1 failed to initialize!' 1>&2
exit 1
