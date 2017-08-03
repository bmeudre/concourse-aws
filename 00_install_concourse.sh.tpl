#!/usr/bin/env bash

if ! which concourse; then
  curl -v -L https://github.com/concourse/concourse/releases/download/v3.3.4/concourse_linux_amd64 -o concourse
  chmod +x concourse
  mv concourse /usr/local/bin/concourse
fi
