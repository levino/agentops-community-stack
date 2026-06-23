# Incident: ZITADEL bootstrap — six traps in one afternoon

*Inherited from the originating instance (2026-05-09). The template already
encodes every fix — this file documents WHY those settings exist, so they
do not get "simplified" away.*

## 1. Helm hooks block subchart resources in the same release

**Symptom:** with `postgresql.enabled: true` in the zitadel chart, the
`zitadel-init` pod loops forever on `lookup zitadel-postgresql … no such host`.

**Root cause:** `zitadel-init`/`zitadel-setup` are `pre-install` hooks; Helm
runs hooks BEFORE regular manifests. The Postgres subchart is regular →
does not exist yet when the hook starts.

**Fix (encoded):** Postgres as its own Argo CD Application
(`argocd/applications/zitadel-postgresql.yaml`); the `zitadel` Application runs
in a later sync wave so Postgres exists first.

## 2. ghcr.io OCI 404 ≠ auth problem

**Symptom:** the chart pull reports "403 denied" for
`oci://ghcr.io/zitadel/charts/zitadel`.

**Root cause:** wrong path — correct is `zitadel/zitadel-charts`. Anonymous
pull is allowed; a wrong path yields 404/403, not 401.

**How to recognize:** test `helm pull oci://… --version X` WITHOUT auth
before rolling out auth secrets.

## 3. Bitnami HTTPS Helm repo is dead

**Symptom:** `unsupported protocol scheme "oci"` pulling from
`https://charts.bitnami.com/bitnami`.

**Fix (encoded):** the chart source is an OCI Helm repo
(`registry-1.docker.io/bitnamicharts`, `enableOCI: "true"` in
`argocd/repositories.yaml`).

## 4. Bitnami container images moved to `bitnamilegacy/`

**Symptom:** `docker.io/bitnami/postgresql:…: not found` → ImagePullBackOff.

**Root cause:** Bitnami moved public images to `bitnamilegacy/*` in 2025
(subscription model).

**Fix (encoded):** `image.repository: bitnamilegacy/postgresql` in the
Postgres Application's Helm values. Note: a pod stuck in ImagePullBackOff must
be deleted manually once after fixing the reference.

## 5. The zitadel chart does NOT render `ExistingSecret` blocks to env vars

**Symptom:** init pod fails with `FATAL: password authentication failed for
user "postgres"` — while direct `psql` with the same password works.

**Root cause:** values under
`configmapConfig.Database.Postgres.{User,Admin}.ExistingSecret` are rendered
literally into the config. ZITADEL itself cannot read k8s secrets — it only
knows cleartext config or `ZITADEL_*` env vars.

**Fix (encoded):** DB passwords via top-level `env:` with `secretKeyRef`
(`ZITADEL_DATABASE_POSTGRES_USER_PASSWORD` /
`…_ADMIN_PASSWORD`) — see `argocd/applications/zitadel.yaml`.

## 6. Job `activeDeadlineSeconds` default too tight to debug

**Symptom:** `zitadel-init` is killed after exactly 5:00 with
`DeadlineExceeded` — pod and logs vanish before you can look.

**Fix (encoded):** `initJob/setupJob.activeDeadlineSeconds: 900`.

## Lesson learned (general)

If a Helm install hangs in a pre-install hook for more than ~30 seconds:
pull the hook pod's logs IMMEDIATELY —

```bash
INIT_POD=$(kubectl get pods -n zitadel -l job-name=zitadel-init \
  -o jsonpath='{.items[-1:].metadata.name}')
kubectl logs -n zitadel "$INIT_POD" --tail=20
```

The first five seconds of log almost always show whether it is a DNS loop,
an auth failure or a cert mismatch. Do not wait for the deadline.
