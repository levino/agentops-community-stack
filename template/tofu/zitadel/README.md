# tofu/zitadel — ZITADEL bootstrap (instance/org only)

> **Identity CONTENT is NOT managed here.** Projects, roles, OIDC clients,
> external IdPs and — above all — **who is in which group/role (user grants)**
> are managed through the **ZITADEL API at runtime**, never in tofu/git
> (invariant 6, `AGENTS.md`). This directory is, at most, the **bare
> instance/org bootstrap**. The day-to-day identity work lives in
> `runbooks/zitadel-identity-via-api.md` and `patterns/`.

## Why content is not code (read before "improving" this)

1. **GDPR.** Membership and role grants are personal data about real people.
   In version control they are practically impossible to delete (history,
   forks, clones, CI caches, tofu state) — exactly what data-protection law
   forbids for personal data. It must therefore never enter git.
2. **Churn.** Members join and leave, roles change weekly. A code-review loop
   for every grant is the wrong tool; the ZITADEL console/API is the right one.

So tofu here is intentionally tiny and **run once**: enough to stand the
instance and org up so a human admin can log in and take over via the console
and the API. Everything after that is API/console work, documented as
runbooks, not committed as state.

## The API credential — operator-held, never in the cluster

The credential used to drive the ZITADEL API is a **service-user PAT held by
the operator** and passed **per session** (e.g. exported into the shell for
one `tofu apply` or one batch of API calls). It is an **infrastructure
credential** (invariants 3 + 6):

- **never** stored in the cluster — no service-account key, no PAT as a k8s
  secret;
- **never** committed — not plaintext, not sealed.

> **Anti-pattern (removed):** earlier versions extracted the chart's
> `iam-admin` service-account key from a k8s secret and parked it on disk /
> in the cluster as the standing provider credential. Do **not** do this.
> Mint a scoped service-user PAT, use it for the session, discard it.

Trade-off, accepted and documented: the API credential is not reproducible
from git. At cluster rebuild you mint a fresh operator PAT by hand (see the
runbook). That is the correct cost of keeping personal data and standing
admin credentials out of the repo.

## Bootstrap (once, after the first ZITADEL deploy)

ZITADEL must be running (`kubectl -n argocd get app zitadel` →
Synced/Healthy). Mint an operator service-user PAT in the ZITADEL console
(Instance → Service Users → create → generate **Personal Access Token**, give
it IAM-owner manager role), then provide it to the provider **per session**:

1. Create the state namespace (once):

   ```bash
   kubectl create namespace terraform-state
   ```

2. Export the operator PAT for this session only (never written to git, never
   stored in the cluster):

   ```bash
   export ZITADEL_TOKEN="<operator-service-user-PAT>"
   ```

3. Apply the bootstrap:

   ```bash
   tofu init
   tofu plan
   tofu apply
   ```

   Read the admin's initial password once:

   ```bash
   tofu output -raw admin_initial_password
   ```

From here, log in at `https://id.{{ domain }}` as `admin` and do all further
identity work through the console / API (`runbooks/zitadel-identity-via-api.md`).

## State

Backend: `kubernetes` secret in namespace `terraform-state`. Access requires
cluster access — the same trust boundary as `kubectl`. Because content lives
in the API and not in tofu, the state stays small and contains **no personal
membership data**. It may still contain the bootstrap admin's initial password
output; treat it as sensitive.

## What is (and is not) managed here

Managed (bootstrap only):

- the org = the community (the shared identity pool)
- the first admin user as `ORG_OWNER` (`admin.tf`) — the human who then takes
  over via the console

**Not** managed here (API/console at runtime — invariant 6):

- projects, roles, OIDC clients
- user grants / who is in which group or role
- external IdPs (Google etc.) and login policy — see
  `patterns/zitadel-login-v2/` and `patterns/zitadel-external-idp/`

For an app that needs its own OIDC client or role claims, create the client
via the API/console and wire the credentials in as a SealedSecret next to the
app — recipe in `patterns/app-native-oidc/`.
