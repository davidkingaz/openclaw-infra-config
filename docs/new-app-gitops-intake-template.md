# New App Quick Intake (Minimal) — for Guillermo

Master: this is the **short form**. Fill only what I cannot safely infer.
I will auto-discover defaults from cluster state, existing apps, and homelab docs.

---

## 1) What you want deployed (required)

- App name:
- What it does (1-2 lines):
- Container image (or source repo if image unknown):
- Exposure needed?
  - none / internal service / public route
- Any hard requirement I must respect?
  - (example: no internet egress, read-only mode, must run on workers only)

---

## 2) Ownership + repo target (required)

- Git repo for app manifests (new or existing):
- ArgoCD app name (if you care; else I choose):
- Namespace preference (if you care; else I choose):

---

## 3) Secrets/config you know I cannot infer (required if applicable)

- Secret names + keys (names only, no values):
- Who provides secret values? (you / external secret system)
- Any certs/CA bundles required?

---

## 4) Guardrails (required)

- Auto-sync in ArgoCD?
  - yes / no
- Allow Guillermo to proceed without asking for each non-destructive step?
  - yes / no
- Destructive actions still require explicit confirmation?
  - yes (default)

---

## 5) Optional preferences (only if you care)

- Resource preference: small / medium / large
- Storage needed? size/class if known:
- Preferred domain/hostname for route:
- Monitoring/alerts required? yes/no

---

# What Guillermo will infer automatically

I will derive these from cluster patterns and current deployments unless you override:

- Namespace naming convention
- ArgoCD project/namespace (`openshift-gitops` conventions)
- Kustomize layout (`base` + `overlays/homelab`)
- Default requests/limits based on similar workloads
- Security context defaults (non-root where possible)
- Service type/port defaults from image conventions
- NetworkPolicy baseline (deny-by-default + minimum needed egress/ingress)
- Probe defaults (liveness/readiness/startup)
- Labels/annotations used across existing apps
- Sync policy pattern used in current homelab apps

---

# Guillermo execution contract

When you say “deploy using quick intake”, I will:

1. Validate repo + Argo target
2. Scaffold manifests with sane defaults
3. Commit/push manifests
4. Create/update ArgoCD `Application`
5. Sync and verify health
6. Report status + any blockers

I will stop and ask only when blocked by:
- missing credentials/secrets,
- policy conflicts,
- destructive/risky changes,
- ambiguous requirements that could break intent.

---

# One-line command you can send

> "Guillermo, deploy `<app-name>` using quick intake template in `docs/new-app-gitops-intake-template.md`. Infer defaults from current cluster patterns and proceed automatically under standard safety gates."
