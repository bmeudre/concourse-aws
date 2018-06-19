#!/usr/bin/env bash

if ! which concourse; then
  curl -v -L https://github.com/concourse/concourse/releases/download/v3.14.1/concourse_linux_amd64 -o concourse
  chmod +x concourse
  mv concourse /usr/bin/concourse
fi
