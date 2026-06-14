# apps/ — one entry per application

Apps are stamped out with `scripts/new-app.sh` — never by hand-copying YAML.

Two kinds of apps, two shapes:

## 1. Own apps (blessed path): the app owns its `deploy/` overlay

The app's repository contains its manifests (e.g.
`deploy/overlays/production`); this repo only **registers** it:

```bash
./scripts/new-app.sh myapp --repo https://github.com/OWNER/myapp
```

This creates `apps/myapp.yaml` with a `GitRepository` + `Kustomization`
(Flux pulls the app repo directly), the namespace, and a namespace-scoped
`RoleBinding` of the `preview-deployer` ClusterRole for the app's CI
identity. Rollout = push to the app repo's `main`.

If the app needs login, give it its own OIDC client:
see `patterns/app-native-oidc/`.

## 2. Third-party / static apps: manifests live here

For software you do not develop (dashboards, internal tools):

```bash
./scripts/new-app.sh grafana --domain grafana.example.org --image grafana/grafana --port 3000
```

This creates `apps/grafana/` with namespace, deployment, service and ingress
(TLS via the `acme` ClusterIssuer). Add `--protected` to put it behind the
central login (ForwardAuth — requires `patterns/app-forwardauth/` to be
deployed once).

## Rules

- One namespace per app. CI identities get the `preview-deployer` role in
  their namespace only — never `cluster-admin`.
- Images must be built for the server architecture (multi-arch builds).
- Only **app/service secrets** enter this repo, and only as SealedSecrets.
  **Infrastructure credentials** (Flux GitHub App key, ZITADEL operator
  credential) live only in the cluster — never committed, not even sealed
  (AGENTS.md inv. 3; `runbooks/flux-github-app.md`).
