# Incident: Argo CD prunes ZITADEL's `login-client` secret (label tracking)

*Hit during the Flux→Argo CD migration. The template encodes the fix; this file
explains WHY, so nobody removes the `resourceTrackingMethod` setting.*

## What happened

After bootstrapping Argo CD, the `zitadel` Application stayed **Degraded**: the
`zitadel-login` pod was stuck `Init:0/1` with
`MountVolume.SetUp failed for volume "login-client" : secret "login-client" not found`,
even though the `zitadel-init` and `zitadel-setup` jobs had both **Completed**.

## Root cause

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

## Fix (encoded)

Switch Argo CD to **annotation-based** tracking (its recommended method): it
tags managed resources with an `argocd.argoproj.io/tracking-id` annotation
instead of trusting the `instance` label, so chart-set labels no longer cause
false ownership. Set once, right after installing Argo CD (bootstrap §2):

```bash
kubectl -n argocd patch configmap argocd-cm --type merge \
  -p '{"data":{"application.resourceTrackingMethod":"annotation"}}'
kubectl -n argocd rollout restart statefulset/argocd-application-controller
```

## Prevention

- The bootstrap runbook sets this before any Application is created; CI does the
  same in `.github/workflows/e2e.yml`. Do **not** revert to label tracking.
- General rule: any Helm chart that creates resources at runtime and stamps them
  with `app.kubernetes.io/instance` needs annotation tracking under Argo CD.
