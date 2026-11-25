#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
for root in vpc-ec2 eks; do
  terraform -chdir="$root" init -backend=false -input=false
  terraform -chdir="$root" validate
done
