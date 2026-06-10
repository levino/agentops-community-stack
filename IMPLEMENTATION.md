# Implementation plan

This is the build order for turning the concept in [README.md](README.md) into
a working template. Guiding principle: **the CI harness comes first**, and the
substrate is ported *into a green pipeline* piece by piece — not validated at
the end.

Source material: `levino/server-config` (cluster manifests, tofu, incidents,
runbooks). Everything generalizable gets lifted from there; everything
instance-specific (domains, IPs, Coolify leftovers) stays behind.

All content in this repository is written in **English**.

---

## Milestone 0 — Skeleton

Goal: `uvx copier copy` produces a derivative without errors.

- [ ] `copier.yml` with the question set:
      `project_name`, `community_name`, `domain`, `server_ipv4`, `acme_email`,
      `github_owner`, `target_arch` (amd64/arm64), `container_registry`
      (default `ghcr.io`), `associations` (YAML list of `{name, roles}` — each
      becomes a ZITADEL project).
      Use `_subdirectory: template` so the template's own machinery (CI,
      tests, README) is not copied into derivatives.
- [ ] `template/` directory with stubs: `AGENTS.md.jinja` (invariants from
      README §10 + runbook pointers), `cluster/`, `patterns/`, `scripts/`,
      `runbooks/` incl. `incidents/` convention doc.
- [ ] `tests/answers-ci.yml` — fixed answers for the CI-generated derivative
      (use documentation values: `testville.example`, `203.0.113.10`, …).
- [ ] Keep the **Jinja surface minimal**: template only files where actual
      values differ. Everything else is plain files. The smaller the templated
      surface, the cleaner `copier update` merges stay.

## Milestone 1 — CI harness (the primary validation)

Goal: every PR generates a derivative and boots it end to end.

- [ ] `.github/workflows/e2e.yml`:
      1. `uvx copier copy --defaults --data-file tests/answers-ci.yml . /tmp/derivative`
         (catches broken Jinja / invalid YAML immediately),
      2. `k3d cluster create` (k3s in Docker, bundled Traefik included),
      3. `flux install` + reconcile the generated repo (local `GitRepository`
         source or direct Kustomization apply),
      4. deploy **Pebble** (Let's Encrypt test ACME server) in-cluster, point
         cert-manager at it — exercises real ACME order / HTTP-01 / solver
         routing through Traefik,
      5. smoke tests with Pebble's root trusted via `curl --cacert`.
- [ ] **Issuer as overlay/parameter**, never hardcoded: `letsencrypt-prod` in
      real derivatives, `pebble` in CI. This is a hard design constraint that
      falls out of CI-first.
- [ ] **sealed-secrets in CI:** the harness seals fresh dummy secrets against
      the CI controller's freshly generated key on every run — this tests the
      sealing procedure itself (the biggest bootstrap hurdle).
- [ ] **Arch matrix:** run on `ubuntu-24.04` *and* `ubuntu-24.04-arm` (free for
      public repos) to enforce the multi-arch invariant.
- [ ] Generous timeouts for ZITADEL readiness (it needs its Postgres; slow
      first start is normal).

## Milestone 2 — Port the substrate

Goal: the CI derivative runs the real stack, component by component, with the
pipeline staying green after each step.

Order (each step lands as its own PR against a green pipeline):

- [ ] Flux layout + Kustomization structure
- [ ] cert-manager (+ issuer overlay mechanism from milestone 1)
- [ ] sealed-secrets
- [ ] Traefik configuration (hostPort, middleware base)
- [ ] ZITADEL (+ Postgres) at `id.{{ domain }}`
- [ ] Port the existing `incidents/` from `server-config` **early** — each
      reproducible one becomes an assertion in the e2e suite
      (incidents-as-regression-suite, literally).

## Milestone 3 — Identity as code

- [ ] `tofu/zitadel/modules/community/`: reusable module —
      org = community, one project per association, roles per project,
      board members as project managers. Instantiated from the `associations`
      answer.
- [ ] Decide: tofu runs locally vs. via CI OIDC (README §12).
- [ ] CI smoke test: after tofu apply against the CI ZITADEL, the OIDC
      discovery endpoint and a test client work.

## Milestone 4 — Per-app patterns (layer 2)

- [ ] `patterns/app-native-oidc/` — namespace, scoped RBAC, Flux registration,
      OIDC client via tofu; documented as a copyable recipe.
- [ ] `patterns/app-forwardauth/` — one oauth2-proxy instance + reusable
      Traefik middleware, enabled per ingress annotation.
- [ ] `scripts/new-app.sh` (in-repo generator inside the *derivative*): stamps
      out the per-app pattern. CI deploys one dummy app through it.
- [ ] ForwardAuth smoke test in CI: unauthenticated request → redirect to
      `id.<domain>`.

## Milestone 5 — Agent contract & real-world validation

- [ ] `AGENTS.md.jinja` finalized: invariants, verify commands, pointers into
      runbooks; written for an agent with git + kubectl + CI access.
- [ ] `runbooks/bootstrap-from-zero.md`: top to bottom, every step paired with
      a verify command. Covers exactly the residue CI cannot test: k3s install
      (`curl | sh`), systemd, hostPort on a real NIC, real DNS + Let's Encrypt.
- [ ] **Acceptance test:** an agent bootstraps a fresh throwaway VPS using
      only the generated repo + `AGENTS.md` + the runbook. Every failure
      becomes a runbook fix or a new incident → PR back to the template
      (the feedback loop from README §7, exercised once before anyone else
      uses it).
- [ ] First real derivative (e.g. `roessing-infra`) generated and live.

## Milestone 6 — Hardening (ongoing)

- [ ] Guardrails as policy, not prose: Kyverno/OPA policy forbidding
      `cluster-admin` bindings for CI identities; further policies as lessons
      accumulate (README §12).
- [ ] `copier update` round-trip test in CI: generate with an old template
      ref, update to HEAD, assert a clean merge for untouched derivatives.

---

## Non-goals (repeated from README §11)

No HA/multi-node, no instance-specific migration leftovers, no hardcoded
domains/IPs/org names.
