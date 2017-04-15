#!/usr/bin/env bash

set -eu

./build-ubuntu-ami.sh
./build-concourse-ami.sh
