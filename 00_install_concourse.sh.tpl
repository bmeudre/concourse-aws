#!/bin/bash

if ! which concourse; then
  curl -v -L https://github.com/concourse/concourse/releases/download/v2.6.0/concourse_linux_amd64 -o concourse
  chmod +x concourse
  mv concourse /usr/local/bin/concourse
fi
