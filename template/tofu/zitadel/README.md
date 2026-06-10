# tofu/zitadel — identity as code

OpenTofu configuration for the ZITADEL instance. Manages **external state**
(org, projects, roles, OIDC clients, users) via the ZITADEL API. **Not**
managed here: the ZITADEL deployment itself — that is Flux (`zitadel/`).

Identity is declarative. No UI clicking for anything that lives here
(hard invariant, see `AGENTS.md`).

## Bootstrap (once, after the first ZITADEL deploy)

ZITADEL must be running (`flux get helmrelease zitadel -n zitadel` →
Ready=True). The chart's setup job automatically creates an IAM-owner
service user `iam-admin` and stores its JWT profile as a k8s secret —
exactly the format the provider expects. No UI involved.

1. Create the state namespace (once):

   ```bash
   kubectl create namespace terraform-state
   ```

2. Pull the service-user key from the cluster:

   ```bash
   kubectl get secret -n zitadel iam-admin \
     -o jsonpath='{.data.iam-admin\.json}' | base64 -d > service-user.json
   chmod 600 service-user.json
   ```

   The file is gitignored. If the key is ever compromised: delete the
   secret, re-run the setup job (`kubectl delete job -n zitadel
   zitadel-setup`, `flux reconcile helmrelease zitadel -n zitadel`) — it
   recreates the secret.

3. First apply:

   ```bash
   tofu init
   tofu plan
   tofu apply
   ```

   Read the admin's initial password once:

   ```bash
   tofu output -raw admin_initial_password
   ```

## State

Backend: `kubernetes` secret in namespace `terraform-state`. Access requires
cluster access — the same trust boundary as `kubectl`. The state contains
plaintext secrets (client secrets, initial passwords); sealed-secrets
protection does **not** apply here.

## What is managed here

- `modules/community` — org = community, one project per association,
  roles per project, boards as project managers (`community.tf`)
- the first admin user (`admin.tf`)
- the `infrastructure` project with the `forwardauth` OIDC client for
  oauth2-proxy (`forwardauth.tf`)
- one OIDC client per native-OIDC app — add as needed, recipe in
  `patterns/app-native-oidc/`

## Drift workflow

Local `tofu plan` is the truth. Runs locally for now; moving it to CI
(GitHub Actions OIDC → ZITADEL API) is an option once the setup is stable —
the CI harness of the template already exercises `tofu apply` end to end.
