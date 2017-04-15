#!/usr/bin/env bash

set -eu

packer build -var source_ami=$(./latest-ami-ubuntu.sh) concourse-baked.json
