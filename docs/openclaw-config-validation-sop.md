# OpenClaw Config Validation SOP (Guillermo)

## Purpose
Prevent config-related outages by requiring validation before any OpenClaw config change is merged and deployed via GitOps.

This SOP applies to Guillermo (`openclaw-infra`) and any future OpenClaw instances.

---

## Policy

1. **No direct config rollout without validation.**
2. **One logical config change per commit** when possible.
3. **Rollback commit prepared in advance** for every config deploy.
4. **Destructive/risky changes require explicit approval from Dave.**

---

## Scope (files covered)

In `homelabocp`:
- `openclaw-infra/base/configmap-openclaw.yaml` (embedded `config.json`)
- Any OpenClaw-related overlay patches
- Any OpenClaw Deployment manifest fields that affect startup/health/probes

---

## Standard Change Workflow

## 1) Pre-change baseline
- Confirm cluster health:
  - `oc get co`
  - `oc get nodes`
- Confirm app health:
  - `oc get application openclaw-infra -n openshift-gitops`
  - Expect `Synced/Healthy`
- Confirm current pod healthy:
  - `oc get pods -n openclaw-infra`

## 2) Make minimal change in Git
- Modify only needed field(s)
- Avoid bundling unrelated edits

## 3) Validate config (hard gate)
Run validator before push/sync:
- `openclaw config validate`

If config is file-based in repo, validate the rendered/target config used by runtime.

### Gate outcome
- **Pass** → proceed
- **Fail** → stop, fix, re-validate

## 4) Commit and push
- Clear commit message, e.g.:
  - `Enable Discord streaming output`
  - `Set threadBindings spawnSubagentSessions`

## 5) Argo sync + rollout watch
- Trigger refresh if needed:
  - `oc annotate application openclaw-infra -n openshift-gitops argocd.argoproj.io/refresh=hard --overwrite`
- Watch until stable:
  - App: `Synced/Healthy`
  - Pod: `2/2 Running`
  - Restarts not increasing

## 6) Functional verification
- DM test reply works
- Guild channel reply works (`#general` or target channel)
- Expected behavior for changed setting is confirmed

## 7) Close-out
- Record what changed and outcome
- If user-facing behavior changed, post short summary to Dave

---

## Fast Rollback Procedure

Trigger rollback immediately if any of the following:
- no response > 5 minutes after deploy
- app Degraded or pod not Ready
- crashloop/restart storm
- core messaging path broken

Rollback steps:
1. Revert commit in Git
2. Push revert to `main`
3. Refresh Argo app
4. Confirm `Synced/Healthy` and pod `2/2`
5. Validate DM/channel response restored

---

## Recommended Safety Defaults

- Prefer staged rollout windows when Dave has access to OpenShift/Argo
- Keep config changes separate from image upgrades
- Keep probe changes separate from channel behavior changes
- For major version upgrades, perform config validation + canary test first

---

## Evidence Checklist (for each change)

- [ ] Validator output captured (pass)
- [ ] Commit hash recorded
- [ ] Argo status recorded
- [ ] Pod health recorded
- [ ] Functional messaging test recorded
- [ ] Rollback hash identified (or revert plan ready)

---

## Ownership
- **Execution owner:** Guillermo
- **Approval owner (risky/destructive):** Dave

This SOP is mandatory for OpenClaw config changes unless Dave explicitly overrides.
