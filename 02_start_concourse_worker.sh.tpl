#!/usr/bin/env bash

exec > /var/log/02_start_concourse_worker.log 2>&1
set -x

sudo modprobe tcp_bbr
sudo modprobe sch_fq
sudo sysctl -w net.ipv4.tcp_congestion_control=bbr

sudo modprobe crc32c-intel

CONCOURSE_PATH=/concourse

sudo yum install -y btrfs-progs

sudo mkfs.btrfs /dev/nvme1n1
sudo mkdir -p $CONCOURSE_PATH
sudo mount /dev/nvme1n1 $CONCOURSE_PATH

echo "${tsa_host}" > $CONCOURSE_PATH/tsa_host
echo "${tsa_public_key}" > $CONCOURSE_PATH/tsa_public_key
echo "${tsa_worker_private_key}" > $CONCOURSE_PATH/tsa_worker_private_key
curl http://169.254.169.254/latest/meta-data/instance-id > $CONCOURSE_PATH/instance_id
curl http://169.254.169.254/latest/meta-data/local-ipv4 > $CONCOURSE_PATH/peer_ip

cd $CONCOURSE_PATH

concourse worker \
  --name $(cat instance_id) \
  --garden-log-level error \
  --garden-network-pool 10.254.0.0/16 \
  --garden-max-containers 500 \
  --work-dir $CONCOURSE_PATH \
  --peer-ip $(cat peer_ip) \
  --bind-ip 0.0.0.0 \
  --baggageclaim-bind-ip 0.0.0.0 \
  --baggageclaim-driver btrfs \
  --tsa-host $(cat tsa_host):2222 \
  --tsa-public-key tsa_public_key \
  --tsa-worker-private-key tsa_worker_private_key \
  2>&1 > $CONCOURSE_PATH/concourse_worker.log &

echo $! > $CONCOURSE_PATH/pid
