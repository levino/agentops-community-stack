# incidents/ — the regression suite in prose

Every reproducible footgun gets a file here: what happened, root cause,
fix, prevention. A rebuilding agent reads these BEFORE debugging — each
documented incident is a mistake the next agent must not repeat.

Convention: `YYYY-MM-DD-<slug>.md` with sections **What happened**,
**Root cause**, **Fix**, **Prevention**. Write it the day it happens.

Two incidents ship with the template (inherited from the originating
instance — they are general, not instance-specific):

- `disk-pressure.md` — uncleaned PR previews filled the disk; the whole
  single-node cluster went down.
- `zitadel-bootstrap.md` — six distinct traps when bringing up
  ZITADEL/Postgres via Helm. The template already encodes the fixes; the
  file explains *why* those settings exist, so nobody "simplifies" them away.

The feedback loop: if an incident's lesson generalizes beyond this
instance, lift the generalizable part into the template
(runbook fix, guardrail, or CI assertion) via PR.
