#!/usr/bin/env bash
# Fetch the cluster's current sealed-secrets public key into the repo root.
# With the key committed, anyone can seal new secrets OFFLINE
# (kubeseal --cert sealed-secrets-public-key.pem) — no cluster access needed.
# The controller decrypts with all historical keys, so a slightly stale key
# still seals valid secrets; refresh periodically anyway.
set -euo pipefail

cd "$(dirname "$0")/.."

kubeseal --fetch-cert \
  --controller-name sealed-secrets-controller \
  --controller-namespace kube-system \
  > sealed-secrets-public-key.pem

echo "Wrote sealed-secrets-public-key.pem — commit it (it is public material)."
