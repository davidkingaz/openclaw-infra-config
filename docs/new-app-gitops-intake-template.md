# New Application GitOps Intake Template (for Guillermo)

Use this template when you want Guillermo to deploy a **new app** via:
1) new Git repository,
2) ArgoCD sync,
3) OpenShift deployment.

Fill this once, and Guillermo can execute with minimal follow-up.

---

## 0) Request Header

- Request name:
- Date:
- Requested by:
- Priority: (Low / Normal / High)
- Change window: (Anytime / specific window)

---

## 1) Application Identity

- Application name (k8s-safe):
- Description/purpose:
- Owning team/person:
- Environment(s): (homelab / dev / test / prod)
- Namespace to create/use:
- ArgoCD app name:
- OpenShift labels/annotations required:

---

## 2) Source Repository (Git)

- New repo name:
- Git provider/org:
- Visibility: (private/public)
- Default branch:
- Branch strategy: (main only / PR required / feature branches)
- Required reviewers:
- Commit signing required? (Y/N)
- Deploy key / robot account method:
- Repo URL (SSH preferred):

### Repo structure preference
Choose one:
- [ ] Plain manifests
- [ ] Kustomize (recommended)
- [ ] Helm chart
- [ ] Hybrid

If Kustomize:
- Base path:
- Overlay path(s):

---

## 3) Build/Artifact

- App type: (containerized app / operator / static content / job)
- Image source repo:
- Image name:
- Tag strategy: (pinned semver / digest / latest-not-allowed)
- Registry:
- Image pull secret needed? (Y/N)
- Build pipeline source: (GitHub Actions / Tekton / external)
- Build trigger:

---

## 4) OpenShift Runtime Requirements

- Deployment kind: (Deployment/StatefulSet/DaemonSet/CronJob/Job)
- Replicas:
- CPU request/limit:
- Memory request/limit:
- Storage needed? (Y/N)
- PVC size/class/access mode:
- Security context constraints/requirements:
  - runAsUser/runAsNonRoot
  - fsGroup
  - readOnlyRootFilesystem
  - capabilities drop/add
- Node selectors/tolerations/affinity:
- PodDisruptionBudget needed? (Y/N)

---

## 5) Config, Secrets, and Credentials

- ConfigMap keys needed:
- Secret keys needed (names only, no values):
- Secret source of truth: (manual, sealed-secrets, external secret manager)
- Who provides secret values?
- Rotation policy:
- Any certificates needed? (TLS cert/key, CA bundle):

---

## 6) Networking and Exposure

- Service needed? (Y/N)
- Service type: (ClusterIP/NodePort/LoadBalancer)
- Service port(s):
- Route/Ingress needed? (Y/N)
- Hostname/FQDN:
- TLS termination mode:
- Path rules:
- Ingress class / router requirements:
- NetworkPolicy requirements:
  - ingress allowed from:
  - egress allowed to:
  - required ports/protocols:
- External dependencies (DNS/IP/FQDN + port):

---

## 7) ArgoCD Configuration

- ArgoCD namespace: (usually `openshift-gitops`)
- ArgoCD project:
- Destination cluster/server:
- Destination namespace:
- Source repo URL:
- Source path:
- Target revision:
- Sync policy:
  - automated prune: (Y/N)
  - automated self-heal: (Y/N)
- Sync options:
  - CreateNamespace=true? (Y/N)
- Ignore differences needed? (list exact resources/fields)
- Health checks/customizations needed? (Y/N)

---

## 8) Observability, Alerts, and SLOs

- Liveness probe:
- Readiness probe:
- Startup probe:
- Metrics endpoint:
- ServiceMonitor/PodMonitor needed? (Y/N)
- Logs destination/format:
- Alert rules required:
- Dashboard required:
- SLO target(s):

---

## 9) Operations and Lifecycle

- Backup requirements:
- Restore requirements:
- Upgrade strategy:
- Rollback strategy:
- Data migration required? (Y/N)
- Maintenance tasks (cron jobs) needed:
- Runbook links:

---

## 10) Security and Compliance

- Access level required (least privilege target):
- RBAC objects required:
- Any cluster-admin requirement? (should be No unless justified)
- Compliance requirements (e.g., CIS/internal):
- Internet access policy:
- Approved external sources:

---

## 11) Validation Plan (Definition of Done)

- [ ] ArgoCD app is Synced + Healthy
- [ ] All pods Ready and stable for N minutes:
- [ ] Probes passing
- [ ] Logs show no critical errors
- [ ] Metrics visible
- [ ] Alerts configured and tested
- [ ] Route/Ingress reachable (if applicable)
- [ ] Secrets loaded and app functional
- [ ] Rollback tested
- [ ] Documentation updated

---

## 12) Guillermo Execution Authorization

- Guillermo may create repo scaffolding commits: (Y/N)
- Guillermo may create/modify ArgoCD Application manifests: (Y/N)
- Guillermo may apply non-destructive runtime checks automatically: (Y/N)
- Guillermo must ask before any destructive action: (Y/N, default Yes)
- Guillermo may post deployment updates to Discord channels:
  - `#general` (Y/N)
  - `#cluster-admin` (Y/N)
  - `#agent-logs` (Y/N)

---

## 13) Quick-Use Command Template (what Dave can say)

> "Guillermo, deploy a new app using the New Application GitOps Intake Template in `docs/new-app-gitops-intake-template.md`. Use the filled values in `<path-to-filled-template>`. Proceed automatically for approved actions, report milestones in `#agent-logs`, and stop only on policy/safety gates."

---

## 14) Optional: Minimal Example (filled)

- Application name: `example-api`
- Namespace: `example-api`
- Repo: `git@github.com:davidkingaz/example-api-gitops.git`
- Structure: `kustomize` (`base/` + `overlays/homelab`)
- Image: `ghcr.io/davidkingaz/example-api:v1.0.0`
- Service: `ClusterIP:8080`
- Route: `example-api.apps.homelab.kingfamilyaz`
- Argo app: `example-api`
- Sync: automated prune+selfHeal
- Secrets: `example-api-secrets` (manual)
- DoD: synced/healthy + probes + route + logs + metrics
