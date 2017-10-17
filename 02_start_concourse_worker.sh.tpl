#!/usr/bin/env bash

iptables -I FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
iptables-save

exec > /var/log/02_start_concourse_worker.log 2>&1
set -x

CONCOURSE_PATH=/var/lib/concourse

mkdir -p $CONCOURSE_PATH

echo "${tsa_host}" > $CONCOURSE_PATH/tsa_host
echo "${tsa_public_key}" > $CONCOURSE_PATH/tsa_public_key
echo "${tsa_worker_private_key}" > $CONCOURSE_PATH/tsa_worker_private_key
curl http://169.254.169.254/latest/meta-data/instance-id > $CONCOURSE_PATH/instance_id
curl http://169.254.169.254/latest/meta-data/local-ipv4 > $CONCOURSE_PATH/peer_ip

cd $CONCOURSE_PATH

concourse worker \
  --name $(cat instance_id) \
  --garden-log-level error \
  --work-dir $CONCOURSE_PATH \
  --peer-ip $(cat peer_ip) \
  --bind-ip $(cat peer_ip) \
  --baggageclaim-bind-ip $(cat peer_ip) \
  --tsa-host $(cat tsa_host) \
  --tsa-public-key tsa_public_key \
  --tsa-worker-private-key tsa_worker_private_key \
  2>&1 > $CONCOURSE_PATH/concourse_worker.log &

echo $! > $CONCOURSE_PATH/pid
