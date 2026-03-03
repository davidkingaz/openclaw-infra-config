# New App Quick Intake (Master → Guillermo)

Master, this is the **ultra-short form**.
You provide intent and non-inferable facts. I infer the rest from current OpenShift + ArgoCD patterns.

---

## 1) Required (always)

- **App name**:
- **What it does** (1–2 lines):
- **Source** (pick one):
  - container image: `...`
  - source repo: `...`
- **Exposure intent** (pick one):
  - `internal-only`
  - `public-route`
  - `no-service` (batch/cron/worker)

---

## 2) Required only when I cannot infer

- **External systems this app must reach** (FQDN/IP + port):
- **Secrets needed** (name + key names only, no values):
- **Any hard constraint** I must obey:
  - (examples: must run on workers, no internet egress, read-only rootfs)

---

## 2.5) MCP Addendum (fill only if app is an MCP server)

- **MCP type/name**:
- **Initial safety mode** (pick one):
  - `read-only` (recommended)
  - `disable-destructive`
  - `full-write`
- **Toolsets to enable initially** (default minimal):
- **Auth mode**:
  - `in-cluster ServiceAccount` (default)
  - `kubeconfig` (only if required)
- **OpenClaw registration target**:
  - `global` (default)
  - `specific agents only` (list)
- **Should cluster-admin be the only privileged executor?**
  - `yes` (default)
- **Any resources to explicitly deny** (kinds/namespaces):

---

## 3) Fixed defaults (no need to ask each time)

These are now policy defaults unless you explicitly override:

- Git repo for app manifests: **always a new repo**
- Namespace selection: **Guillermo chooses**
- Secrets: **stored in OpenShift only; never in Git**
- ArgoCD sync policy: **automated (prune + selfHeal + allowEmpty=false)**
- Guillermo may proceed for non-destructive steps without asking each time: **Yes**
- Destructive actions still require explicit confirmation: **Yes**

---

## 4) Exposure recommendation policy (my default guidance)

If you don’t specify, I recommend:

1. **internal-only** by default (safest)
2. **public-route** only when human/browser or external webhook access is required
3. **no-service** for workers/cron jobs that don’t serve traffic

I will call out if the app type suggests a different exposure model.

---

## 5) What I infer automatically from your environment

From current cluster + ArgoCD conventions, I will infer and apply:

- ArgoCD location and pattern:
  - namespace: `openshift-gitops`
  - project: `default`
  - destination: `https://kubernetes.default.svc`
  - syncOptions include `CreateNamespace=true`
  - retry/backoff pattern aligned to existing apps
- GitOps layout pattern:
  - app repo scaffold with clear base/overlay structure or chart structure as appropriate
- Labels/annotations naming conventions
- Resource requests/limits baseline from similar workloads
- Security context defaults (least privilege where compatible)
- Service/Route/NetworkPolicy baseline aligned to exposure choice
- Health probes and rollout strategy defaults
- Validation gates (Synced/Healthy + pod readiness + route/service checks)

---

## 6) Execution contract (what happens when you say deploy)

When you say “deploy using quick intake”, I will:

1. Create and scaffold the **new app repo**
2. Add manifests with inferred defaults + your required inputs
3. Add ArgoCD Application manifest with auto-sync policy
4. Commit/push
5. Verify Argo sync and OpenShift runtime health
6. Report outcome + blockers + next action

I stop and ask only if blocked by:
- missing secret values/credentials,
- policy conflict,
- destructive or ambiguous change risk.

---

## 7) One-line command you can send

> "Guillermo, deploy `<app-name>` using `docs/new-app-gitops-intake-template.md`. Use default policy and infer all non-critical fields from current OpenShift/ArgoCD patterns."

---

## 8) Notes from current environment (baseline I reviewed)

- Existing Argo apps are running with automated sync + self-heal.
- Existing infra app patterns use explicit retry/backoff and CreateNamespace sync option.
- App manifests are maintained GitOps-first and synced into OpenShift through ArgoCD.
