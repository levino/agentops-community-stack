# Incident: disk pressure — every service on the node down

*Inherited from the originating instance (2026-04-18, ~30 min total outage).*

## What happened

k3s detected `DiskPressure`, set a `NoSchedule` taint on the (only) node,
and evicted pods one by one. On a single-node cluster that is a total
outage of everything.

## Root cause

1. PR-preview deployments were never cleaned up — neither on PR close nor
   on new commits to the same PR. 150+ dead pods, 30+ active previews at
   ~200 MB image each.
2. Container images lived on a small system disk instead of the data disk.

## Symptom / diagnosis

```bash
kubectl describe node | grep -E 'DiskPressure|Taints'
# DiskPressure True, Taints node.kubernetes.io/disk-pressure:NoSchedule
```

## Immediate fix

```bash
# delete dead pods
kubectl get pods -A --no-headers | grep -E "Evicted|Error|Unknown" \
  | awk '{print "-n", $1, $2}' | xargs -L1 kubectl delete pod
# prune containerd images (on the node)
crictl --runtime-endpoint unix:///run/k3s/containerd/containerd.sock rmi --prune
```

## Prevention (encoded in this template)

- `scripts/new-app.sh` sets `revisionHistoryLimit: 2` and
  `progressDeadlineSeconds: 300` on every deployment it stamps.
- PR-preview workflows MUST delete all resources (deployment, service,
  ingress, secrets, certificates) on PR close, and use `kubectl rollout
  restart` on new commits so old pods disappear.
- If the server has a small system disk: put k3s data on the big disk
  (`/var/lib/rancher` → symlink/bind-mount) BEFORE the first incident, and
  monitor `df` on the node.
