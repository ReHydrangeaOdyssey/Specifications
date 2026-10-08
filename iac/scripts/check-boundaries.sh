#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_DIR="${ROOT_DIR}/environments/local"
AWS_DIR="${ROOT_DIR}/environments/aws"

if grep -R --line-number --fixed-strings 'hashicorp/aws' "${LOCAL_DIR}"; then
  echo 'ERROR: Local環境にAWS Provider参照が存在します.' >&2
  exit 1
fi

if grep -R --line-number -E 'CREATE_AWS_ENVIRONMENT_MANUALLY|DEPLOY_AWS_APPLICATION_MANUALLY|ENABLE_BOUNDED_AWS_NODE_AUTOSCALING' "${LOCAL_DIR}"; then
  echo 'ERROR: Local環境にAWS確認文字列が混入しています.' >&2
  exit 1
fi

for expected in \
  CREATE_AWS_ENVIRONMENT_MANUALLY \
  DEPLOY_AWS_APPLICATION_MANUALLY \
  ENABLE_BOUNDED_AWS_NODE_AUTOSCALING; do
  if ! grep -R --quiet --fixed-strings "${expected}" "${AWS_DIR}"; then
    echo "ERROR: AWS Guardが見つかりません: ${expected}" >&2
    exit 1
  fi
done

echo 'OK: Local/AWS境界とAWS手動Guardを確認しました.'
