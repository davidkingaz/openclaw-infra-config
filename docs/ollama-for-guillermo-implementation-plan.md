# Ollama for Guillermo — OpenShift Implementation Plan (GitOps, Phased)

## Objective
Deploy an internal Ollama service on OpenShift to provide a **local embedding provider** for Guillermo’s semantic memory recall.

Initial scope: **Guillermo-only access**.

---

## 1) Architecture (Target State)

- New ArgoCD-managed application: `ollama-guillermo`
- Namespace: `ollama-system` (or `ollama-guillermo` if you prefer strict isolation)
- Runtime: `Deployment` (single replica, CPU-first)
- Service exposure: `ClusterIP` only (no public route)
- Persistent cache: PVC on `synology-nfs-storage`
- NetworkPolicy: allow ingress from `openclaw-infra` namespace only
- OpenClaw config: memory embedding provider set to Ollama

---

## 2) Deployment Model and Repo Strategy

### GitOps model
- Manage fully through Git + ArgoCD.
- Keep app manifests in a **new repo** (per your policy).
- ArgoCD app created in `openshift-gitops` project `default`.
- Sync policy: automated (`prune: true`, `selfHeal: true`, `allowEmpty: false`).

### Suggested repo structure
```text
ollama-guillermo/
  base/
    namespace.yaml
    serviceaccount.yaml
    pvc.yaml
    deployment.yaml
    service.yaml
    networkpolicy.yaml
    kustomization.yaml
  overlays/
    homelab/
      kustomization.yaml
  argocd/
    application.yaml
  docs/
    runbook.md
```

---

## 3) Recommended Initial Sizing (Current Hardware-Aware)

Based on observed cluster headroom and node inventory:

- Requests: `cpu: 2`, `memory: 4Gi`
- Limits: `cpu: 6`, `memory: 12Gi`
- Replicas: `1`
- PVC: `20Gi` to start
- StorageClass: `synology-nfs-storage`
- Node placement: worker-only (prefer `wk03`)

Rationale:
- Plenty of CPU/RAM headroom right now
- Single-tenant embedding load is moderate
- Persistent cache prevents costly model re-pulls

---

## 4) Security and Access Boundaries

### Initial policy
- Internal-only service (`ClusterIP`)
- No route/ingress exposed externally
- Namespace-scoped network policy to allow only:
  - `openclaw-infra` ➜ Ollama service port
- Deny all other namespace ingress by default

### Secrets
- No model/API secrets in Git
- If needed, store secret values in OpenShift only

---

## 5) Model Strategy (Embeddings)

### Phase 1 model goal
- Pull and pin a single embedding model suitable for semantic recall
- Keep model footprint modest at first

### Operations
- Warm model once at deploy/first-use
- Keep cache on PVC
- Record model name/version in runbook

---

## 6) OpenClaw Integration Plan

After Ollama app is healthy:

1. Configure OpenClaw memory embedding provider to `ollama`
2. Set embedding model name in config
3. Keep retrieval scoped to Guillermo first
4. Validate end-to-end memory semantic search behavior

Validation checks:
- Memory search stops reporting missing embedding provider
- Semantic results are relevant for known stored context
- Latency acceptable for normal operations

---

## 7) Rollout Phases

## Phase A — Foundation
- Create new Git repo and scaffold manifests
- Add ArgoCD application manifest
- Deploy namespace + PVC + service + deployment + networkpolicy
- Confirm pod/service healthy

## Phase B — Functional
- Pull embedding model
- Run basic embedding query test from inside cluster
- Verify service is reachable only from `openclaw-infra`

## Phase C — OpenClaw enablement
- Update OpenClaw memory provider config to `ollama`
- Restart/reconcile OpenClaw as needed
- Validate memory semantic recall flow

## Phase D — Harden
- Add probes and resource tuning from observed usage
- Add basic monitoring and runbook
- Optional: tune model/runtime for latency vs quality

---

## 8) Risks and Mitigations

1. **Slow first startup/model pull**
   - Mitigation: persistent cache + warm-up step

2. **CPU contention during model pull/inference**
   - Mitigation: requests/limits + worker pinning

3. **Service accidentally over-exposed**
   - Mitigation: no route + restrictive NetworkPolicy

4. **Embedding quality mismatch**
   - Mitigation: start with one model, test recall quality, iterate deliberately

5. **Config drift between Git and runtime**
   - Mitigation: all infra via GitOps; OpenClaw config changes committed and tracked

---

## 9) Decision Defaults (Pre-agreed)

- New repo: **Yes**
- Namespace chosen by Guillermo: **Yes**
- Secrets in OpenShift only: **Yes**
- Argo auto-sync: **Yes**
- Non-destructive autopilot: **Yes**
- Destructive changes: explicit confirmation required

---

## 10) Exit Criteria (Done)

- [ ] Argo app is Synced + Healthy
- [ ] Ollama pod stable (no restart loop)
- [ ] PVC bound and cache persists across pod restart
- [ ] Only `openclaw-infra` can access service
- [ ] OpenClaw memory provider uses Ollama successfully
- [ ] Semantic memory recall returns relevant results
- [ ] Runbook/checklist documented

---

## 11) Next Step (Execution Kickoff)

When approved, Guillermo will:
1. Create/scaffold the new `ollama-guillermo` GitOps repo
2. Add baseline manifests + Argo app
3. Deploy and validate infra layer first
4. Then wire OpenClaw memory provider to Ollama
