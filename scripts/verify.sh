#!/usr/bin/env bash
# Credential-free verification suite. Runs fmt/validate + the mocked-provider
# terraform test suite. No Azure credentials, no cost — safe to run anywhere,
# including on every PR in the pipeline (see Phase 0.5 of the fix plan).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== terraform fmt -check =="
terraform fmt -check -recursive

echo "== terraform init (no backend) =="
terraform init -backend=false -input=false

echo "== terraform validate =="
terraform validate

echo "== terraform test (mocked providers — \$0, no credentials) =="
terraform test

echo "All checks passed."
