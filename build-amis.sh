#!/bin/sh

set -eu

./build-ubuntu-ami.sh
./build-docker-ami.sh
./build-concourse-ami.sh
