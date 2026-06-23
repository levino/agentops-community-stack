# Incident: two Argo CD defaults vs this single-node stack

*Hit during the Flux→Argo CD migration. Both fixes live in one `argocd-cm`
patch (bootstrap §2); this file explains WHY, so nobody removes them. The
`zitadel` Application failing to reach Healthy is the symptom of either.*

---

## Trap 1 — Argo prunes ZITADEL's `login-client` secret (label tracking)

### What happened

After bootstrapping Argo CD, the `zitadel` Application stayed **Degraded**: the
`zitadel-login` pod was stuck `Init:0/1` with
`MountVolume.SetUp failed for volume "login-client" : secret "login-client" not found`,
even though the `zitadel-init` and `zitadel-setup` jobs had both **Completed**.

### Root cause

The ZITADEL Helm chart provisions several secrets **imperatively, at runtime**,
from a `pre-install` hook job — `login-client` (the login UI's service-user PAT),
`iam-admin-pat`, etc. — and labels each one:

```
kubectl create secret generic login-client --from-file=pat=/login-client/pat ... \
  | kubectl label ... app.kubernetes.io/instance=zitadel | kubectl apply -f-
```

Argo CD's **default resource-tracking method is the `app.kubernetes.io/instance`
label**. So Argo sees a secret carrying *its* app's instance label that is **not**
in the rendered manifests, concludes it is an orphaned resource of the `zitadel`
Application, and — with `prune: true` + `selfHeal: true` — **deletes it**. The
login deployment can then never mount it. (Same mechanism shows other apps as
spuriously `OutOfSync`.)

### Fix (encoded)

Switch Argo CD to **annotation-based** tracking (its recommended method): it
tags managed resources with an `argocd.argoproj.io/tracking-id` annotation
instead of trusting the `instance` label, so chart-set labels no longer cause
false ownership.

---

## Trap 2 — Ingress never goes Healthy (no LoadBalancer)

### What happened

With Trap 1 fixed, the `zitadel` Application then stayed **Progressing**
forever (the 25-min wait timed out) even though every pod was `1/1 Running`
(`zitadel`, `zitadel-login`, `zitadel-postgresql`) and the `zitadel-tls`
certificate was issued.

### Root cause

Argo CD's built-in health check for `networking.k8s.io/Ingress` reports
**Healthy only once `status.loadBalancer.ingress` is populated**. This stack
runs Traefik as a **ClusterIP service bound to hostPort 80/443 — there is no
LoadBalancer** (single-node, cheap-infra invariant), so no controller ever
writes that status. Every Ingress (ZITADEL's, and every app's) is therefore
stuck `Progressing`, and any Application that owns one never reaches Healthy.

### Fix (encoded)

Override the Ingress health check so presence ⇒ Healthy (correct for an
architecture that deliberately has no LoadBalancer).

### The combined patch

Both fixes are one `argocd-cm` patch, applied right after installing Argo CD
(bootstrap §2):

```bash
kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data":{
  "application.resourceTrackingMethod":"annotation",
  "resource.customizations.health.networking.k8s.io_Ingress":"hs = {} hs.status = \"Healthy\" hs.message = \"single-node hostPort Traefik publishes no load-balancer status\" return hs"
}}'
kubectl -n argocd rollout restart statefulset/argocd-application-controller
```

## Prevention

- The bootstrap runbook applies this before any Application is created; CI does
  the same in `.github/workflows/e2e.yml`. Do **not** revert to label tracking,
  and do **not** drop the Ingress health customization.
- General rules under Argo CD on this stack: (1) any Helm chart that creates
  resources at runtime and stamps them with `app.kubernetes.io/instance` needs
  annotation tracking; (2) anything whose health depends on a LoadBalancer
  needs a custom health check, because there isn't one.
