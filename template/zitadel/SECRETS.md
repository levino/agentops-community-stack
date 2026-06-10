# ZITADEL bootstrap secrets

Two secrets must exist before Flux can reconcile `helmrelease.yaml`:

| Secret | Content |
|---|---|
| `zitadel-masterkey` | 32-byte AES key for ZITADEL's internal encryption |
| `zitadel-db-credentials` | `postgresPassword` (Postgres superuser) + `password` (zitadel app user) |

They are committed **only** as SealedSecrets — never as plaintext (hard
invariant, see `AGENTS.md`).

## Procedure

Run from the repo root, with the cluster reachable (the sealed-secrets
controller must be running — it is part of `cluster/`):

```bash
./scripts/fetch-sealing-cert.sh     # writes sealed-secrets-public-key.pem
./scripts/seal-zitadel-secrets.sh   # writes zitadel/sealed-zitadel-*.yaml
git add sealed-secrets-public-key.pem zitadel/sealed-zitadel-*.yaml
git commit -m "Seal ZITADEL bootstrap secrets"
git push
```

Flux picks up the commit and the `zitadel` Kustomization turns green.

With the public key in the repo, later secrets can be sealed **offline**
(`kubeseal --cert sealed-secrets-public-key.pem`) — no cluster access needed.
The controller decrypts with all historical keys, so a slightly stale public
key still works; refresh it periodically via `scripts/fetch-sealing-cert.sh`.

## Rotation

Re-run `scripts/seal-zitadel-secrets.sh` and commit. Note: rotating the
masterkey of a **running** instance is not supported by this script — it
generates fresh values and is meant for bootstrap. For an existing instance,
follow ZITADEL's masterkey rotation documentation.
