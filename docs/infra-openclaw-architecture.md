# Infra OpenClaw Instance — Architecture & Deployment Guide

## King Family Homelab Infrastructure Agent

**Author:** Claude (Anthropic) — Tailored to the King Family homelab environment  
**Date:** February 28, 2026  
**Version:** 1.0  
**Source of Truth:** `king_home_site.md` (private_files repository)  
**LLM Provider:** OpenAI Codex (compliance with Anthropic end-user agreement)  
**Runtime:** OpenClaw Headless (Gateway-only, no UI)  
**Deployment:** ArgoCD → OpenShift  
**Communication:** Discord (private server, dedicated bot)

---

## 0. Authoritative Overrides (Operator-Controlled)

This section supersedes conflicting statements elsewhere in this document.

- **Identity:** Infra instance assistant identity is **Guillermo** (Infrastructure Familiar).
- **Internet behavior policy:** Guillermo must ask Dave before using web access. No broad web scraping. When approved, prefer reputable technical sources (for example: redhat.com, kubernetes.io, and official project/vendor docs).
- **DNS/egress governance:** DNS and most outbound policy enforcement are managed through **NextDNS** and existing network controls.
- **Git auth method:** Repository operations use **SSH** (not PAT-over-HTTPS) for `openclaw-infra-config`.
- **Deployment/access paths:** Existing ArgoCD/OpenShift deployment and access paths are authoritative and currently working; no changes required unless explicitly requested by Dave.
- **LLM provider now/later:** Current provider remains **OpenAI OAuth token via ChatGPT Plus**. Future migration target is **LiteLLM on Mac Studio** when available.
- **Timezone standard:** Operational timezone is **America/Phoenix**.
- **Compliance parser scope:** Deferred until a preferred implementation approach is selected.

---

## 1. Executive Summary

This document defines the architecture, deployment, and self-configuration plan for the **Infra OpenClaw Instance** — a dedicated, headless OpenClaw agent running on the King Family homelab OpenShift cluster. This instance serves as the centralized infrastructure management and automation agent for the entire homelab environment.

The Infra OpenClaw Instance has **admin-level access** to the OpenShift cluster and operates as the primary interface for cluster configuration, infrastructure monitoring, compliance auditing, and homelab support operations. Communication occurs exclusively through a **private Discord server** with a dedicated bot.

**Key design decisions:**

- **OpenAI Codex as the LLM provider** — All LLM-dependent tasks use OpenAI's Codex model via API, complying with Anthropic's end-user agreement for OpenClaw usage. Deterministic checks and basic comparisons require no LLM.
- **No internet access** — The instance has a single egress route to the OpenAI API endpoint. No web browsing, no web search, no other external API access.
- **Headless operation** — Runs the OpenClaw Gateway without the UI or Chromium sidecar. All interaction is through Discord.
- **ArgoCD deploys infrastructure, OpenClaw configures itself** — The ArgoCD Application deploys all OpenShift resources and a bare, unconfigured OpenClaw container. Post-deployment, the operator logs into the OpenClaw instance and instructs it to self-configure using the detailed plan in this document.
- **Certified MCP servers first** — MCP integration begins with officially certified servers (Grafana, OpenShift) before building custom MCPs for other homelab systems.
- **Compliance auditing as an agent** — The former standalone "Compliance Auditor" concept becomes a sub-agent within this broader Infra OpenClaw Instance, serving as a third-party verification agent validating documentation across all homelab components.

---

## 2. Architecture Overview

```
Dave's iPhone / Desktop (Discord App)
        │
        ▼
   Discord API (api.discord.com)
        │
        ▼
┌──────────────────────────────────────────────────────────────┐
│  OpenShift Cluster (5 nodes)                                  │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ openshift-gitops namespace                               │  │
│  │  ArgoCD ──► GitHub Repo (homelabocp)                     │  │
│  │             openclaw-infra/ manifests                     │  │
│  └────────────────────┬────────────────────────────────────┘  │
│                       │ syncs                                  │
│  ┌────────────────────▼────────────────────────────────────┐  │
│  │ openclaw-infra namespace                                 │  │
│  │                                                          │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │ OpenClaw Headless Deployment (1 pod)                │  │  │
│  │  │                                                     │  │  │
│  │  │  Gateway (port 18789)                               │  │  │
│  │  │  ├─ Orchestrator Agent (default)                    │  │  │
│  │  │  ├─ Cluster Admin Agent                             │  │  │
│  │  │  ├─ Compliance Auditor Agent                        │  │  │
│  │  │  ├─ Monitoring Investigator Agent                   │  │  │
│  │  │  └─ Documentation Agent                             │  │  │
│  │  │                                                     │  │  │
│  │  │  MCP Servers (sidecar processes):                    │  │  │
│  │  │  ├─ Grafana MCP (certified)                         │  │  │
│  │  │  ├─ OpenShift/Kubernetes MCP (certified)            │  │  │
│  │  │  ├─ Prometheus MCP (custom)                         │  │  │
│  │  │  ├─ ArgoCD MCP (custom)                             │  │  │
│  │  │  ├─ DNS MCP (custom)                                │  │  │
│  │  │  ├─ pfSense MCP (custom)                            │  │  │
│  │  │  ├─ Synology MCP (custom)                           │  │  │
│  │  │  └─ Loki MCP (custom)                               │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  │                                                          │  │
│  │  OpenShift Resources:                                    │  │
│  │  ├─ ServiceAccount (cluster-admin)                       │  │
│  │  ├─ ClusterRoleBinding                                   │  │
│  │  ├─ PVC (openclaw-infra-data, 10Gi)                      │  │
│  │  ├─ Secret (openclaw-infra-secrets)                      │  │
│  │  ├─ ConfigMap (openclaw-infra-base-config)               │  │
│  │  ├─ NetworkPolicy (egress: OpenAI + Discord only)        │  │
│  │  └─ EgressNetworkPolicy (cluster-wide enforcement)       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                               │
│  Internal Access (allowed by NetworkPolicy):                   │
│  ├─ api.homelab.kingfamilyaz:6443   (OpenShift API)           │
│  ├─ 192.168.100.221:3000            (Grafana)                 │
│  ├─ 192.168.4.21:9090 / .221:9090  (Prometheus)              │
│  ├─ 192.168.100.221:3100            (Loki)                    │
│  ├─ 192.168.4.1:161                 (pfSense SNMP)            │
│  ├─ 192.168.4.21:22 / .221:22      (dns01/dns02 SSH)         │
│  ├─ 192.168.4.233:5000              (Synology NAS)            │
│  └─ openshift-gitops namespace      (ArgoCD API)              │
│                                                               │
│  External Access (NetworkPolicy egress):                       │
│  ├─ api.openai.com:443              (LLM — OpenAI Codex)      │
│  └─ gateway.discord.gg:443 +        (Discord Bot Gateway)     │
│     discord.com:443                                            │
└──────────────────────────────────────────────────────────────┘
```

---

## 3. Agent Architecture

The Infra OpenClaw Instance uses OpenClaw's native multi-agent routing to host several specialized agents. The Orchestrator is the default agent that receives all incoming messages from Discord and routes to specialists as needed.

### 3.1 Orchestrator Agent (Default)

**Role:** Primary conversational interface and task router. Receives all Discord messages and determines whether to handle directly or delegate to a specialist agent.

**Capabilities:**
- Natural language interaction via Discord
- Task routing to specialist agents
- General homelab questions and guidance
- Status summaries and report generation
- Coordination of multi-agent workflows

### 3.2 Cluster Admin Agent

**Role:** OpenShift cluster administration and configuration. This agent has full cluster-admin privileges and can create, modify, and delete any resource in the cluster.

**Capabilities:**
- Namespace management
- Workload deployments and scaling
- RBAC configuration
- Operator management
- Node management and troubleshooting
- Certificate and secret management
- Network policy configuration
- Storage class and PVC management

**Security:** All destructive operations (delete, scale-down, node drain) require explicit confirmation from Dave via Discord before execution.

### 3.3 Compliance Auditor Agent

**Role:** Third-party verification agent that continuously validates the homelab environment against its documented desired state in `king_home_site.md`. This is the evolution of the former standalone Compliance Auditor concept, now operating as an agent within the broader Infra instance.

**Capabilities:**
- Deterministic compliance checks (no LLM needed for 80%+ of validations)
- LLM-assisted investigation of failed checks (via OpenAI Codex)
- Documentation gap detection
- Daily Discrepancy Report generation
- Real-time alert dispatch for critical findings
- Compliance score tracking and trending

**Compliance Domains (inherited from v3 architecture):**
- pfSense Router (15 checks)
- DNS Infrastructure (22 checks)
- OpenShift Cluster (20 checks)
- Storage / Synology (12 checks)
- ArgoCD / GitOps (13 checks)
- Monitoring Stack (30 checks)
- Service Inventory (16 checks)
- Alert Rules (18+ checks)
- Git / Backup / DR (6 checks)
- **Total: ~152 discrete compliance assertions**

**Check Scheduling (tiered by criticality):**

| Check Category | Interval | Rationale |
|---------------|----------|-----------|
| Interface status (pfSense) | 60s | Critical infrastructure, SNMP already at 30s |
| Node health (OpenShift) | 60s | Critical infrastructure |
| ArgoCD sync status | 5m | Drift detection |
| DNS resolution | 5m | Core service |
| Zone serial sync | 15m | Zone transfer verification |
| Service inventory | 15m | Docker/systemd checks |
| Prometheus targets | 5m | Monitoring integrity |
| Configuration drift | 30m–1h | Grafana, alert rules, dashboards |
| Backup freshness | 24h | DR readiness |

**Daily Discrepancy Report:** Generated at 6:00 AM America/Phoenix, delivered via Discord and archived to the Git repository.

### 3.4 Monitoring Investigator Agent

**Role:** Responds to monitoring alerts and investigates root causes using MCP servers to correlate across systems.

**Capabilities:**
- Alert triage and investigation
- Multi-system correlation (e.g., node issue → pod eviction → PVC pending → ArgoCD degraded)
- Root cause analysis via Prometheus, Loki, and Grafana MCP servers
- Investigation summary delivery via Discord

### 3.5 Documentation Agent

**Role:** Maintains and updates homelab documentation, generates reports, and manages the configuration backup repository.

**Capabilities:**
- Compliance report generation and archival
- Documentation updates and version management
- Git operations for the private backup repository
- Change log generation

---

## 4. Core Design Principles

- **Deterministic first, LLM second:** The majority of compliance checks and basic infrastructure queries run as structured assertions without invoking the LLM. OpenAI Codex is reserved for investigation, analysis, natural language interaction, and ambiguous findings.
- **No internet access:** The instance operates in a network-restricted mode with egress only to api.openai.com and Discord gateway endpoints. All intelligence comes from internal systems via MCP servers.
- **Certified MCP servers first:** Begin with officially certified/maintained MCP servers (Grafana MCP, Kubernetes/OpenShift MCP) before building custom servers for pfSense, DNS, Synology, etc.
- **Admin access with confirmation gates:** The instance has cluster-admin on OpenShift, but destructive operations require explicit Discord confirmation from Dave.
- **Separation of deployment and configuration:** ArgoCD deploys infrastructure; OpenClaw self-configures. Two different concerns, two different repos, two different tools.
- **Self-backing configuration:** The instance backs up its own configuration to a separate private GitHub repository, enabling recovery from scratch.
- **Documentation discipline:** Undocumented changes are surfaced by the Compliance Auditor agent. The system enforces that `king_home_site.md` stays current.

---

## 5. Systems Under Management

| System | IP / Endpoint | Access Level | Scope |
|--------|--------------|-------------|-------|
| OpenShift Cluster (5 nodes) | api.homelab.kingfamilyaz:6443 | **cluster-admin** | Full configuration and management |
| pfSense Router (Netgate 4200) | 192.168.4.1 / 192.168.100.1 | SNMP read + REST API | Monitoring, compliance, firewall rule management |
| dns02 — Primary DNS | 192.168.4.21 | SSH (adminuser) | Service management, config validation |
| dns01 — Secondary DNS + Monitoring Hub | 192.168.100.221 | SSH (adminuser) | Service management, monitoring access |
| Synology NAS | 192.168.4.233 | HTTP/SNMP | Storage health, CSI integration |
| ArgoCD | openshift-gitops namespace | Via OpenShift API | App sync management, GitOps validation |
| Grafana | 192.168.100.221:3000 | API key (Admin role) | Dashboard management, alert rule configuration |
| Prometheus (dns01 + dns02) | :9090 on both | No auth (internal) | Metrics queries, target health |
| Loki | 192.168.100.221:3100 | No auth (internal) | Log queries, pipeline validation |

---

## 6. MCP Server Strategy

### 6.1 Phase 1 — Certified MCP Servers

Start with officially maintained MCP servers that have established quality, security posture, and community support.

| MCP Server | Source | Tools Exposed | Target |
|-----------|--------|--------------|--------|
| **Grafana MCP** | Official Grafana Labs | Search dashboards, get datasources, query Prometheus, query Loki, list alert rules, get annotations | 192.168.100.221:3000 |
| **Kubernetes/OpenShift MCP** | Official/Community certified | get/list/create/update/delete any resource, watch events, logs, exec | api.homelab.kingfamilyaz:6443 |

**Why these first:**
- Grafana MCP unlocks monitoring investigation across Prometheus and Loki with a single server
- Kubernetes MCP provides the cluster-admin tooling the Cluster Admin agent needs
- Both are maintained by their respective project communities with regular updates

### 6.2 Phase 2 — Custom MCP Servers (Homelab-Specific)

Built after certified servers are operational and proven.

| MCP Server | Tools to Expose | Target |
|-----------|----------------|--------|
| **Prometheus MCP** | Direct PromQL queries, target health, config inspection | :9090 on dns01/dns02 |
| **ArgoCD MCP** | App list/get/sync, diff, history, repo status | openshift-gitops namespace |
| **DNS MCP** | dig queries, zone serials, zone transfer checks, BIND status, Stubby status | dns01/dns02 via SSH + dig |
| **Docker/Host MCP** | docker ps, systemctl status, port checks, file content retrieval | dns01/dns02 via SSH |

### 6.3 Phase 3 — Extended MCP Servers

| MCP Server | Tools to Expose | Target |
|-----------|----------------|--------|
| **pfSense MCP** | Interface status, firewall rules, DHCP config, VLANs, system info | 192.168.4.1 (SNMP + REST) |
| **Synology MCP** | System status, disk health, RAID status, volume usage | 192.168.4.233 (SNMP/HTTP) |
| **Loki MCP** | Direct log queries, label discovery, series queries | 192.168.100.221:3100 |

### MCP Design Notes

- All MCP servers expose **read-only tools** by default
- **Write operations** (remediation, configuration changes) are gated behind explicit Discord confirmation
- The Kubernetes MCP is the exception — it has full read-write via the cluster-admin ServiceAccount, but destructive operations still require Discord confirmation
- Custom MCP servers will be built in Python or TypeScript using the MCP Server SDK
- The Prometheus MCP serves as a "meta-collector" — many pfSense, DNS, and system metrics are already in Prometheus and don't need direct collection

---

## 7. Compliance Domains — What to Validate

The Compliance Auditor agent validates the following domains. Each domain uses deterministic JSONPath assertions against live system state, with LLM investigation (via OpenAI Codex) only for failed checks or ambiguous findings.

*Note: The complete assertion tables from the v3 Compliance Auditor document are incorporated by reference. The following is a summary of domains and check counts.*

### 7.1 Network Infrastructure — pfSense Router (15 checks)

Interface status (igc1/igc2/igc3/VLAN20), SNMP service, community string, firewall rules, gateway IPs, DHCP ranges, DNS server assignments, software version, inter-VLAN isolation.

### 7.2 DNS Infrastructure (22 checks)

BIND9 responsiveness, zone serial sync, Stubby DoT resolution, all A records (api, api-int, wildcard apps, nodes, services), SRV records, forward/reverse zones, NextDNS upstream config, DNS Manager accessibility.

### 7.3 OpenShift Cluster (20 checks)

Cluster version, update channel, node readiness (all 5), node roles, node IPs, network plugin (OVNKubernetes), pod/service CIDR, MTU, ClusterOperator health, API server, Console, CRI-O and RHCOS versions.

### 7.4 Storage — Synology NAS & CSI (12 checks)

NAS reachability, DSM accessibility, CSI controller/node DaemonSet health, snapshot controller, secrets, default StorageClass, provisioner, reclaim policy, VolumeSnapshotClass, PVC binding, Loki NFS mount.

### 7.5 ArgoCD — GitOps (13 checks)

Namespace, server/controller/repo-server/redis/dex pod status, app sync and health status, auto-sync configuration, Git repo connectivity, console accessibility, RBAC policies, resource limits.

### 7.6 Monitoring Stack (30 checks)

Grafana health/version/datasources/dashboards/alert rules/contact points; Prometheus health/targets/retention/scrape config on both servers; Loki readiness/retention/storage path; Alloy status on both hosts; all exporters (Node, BIND, SNMP) on both hosts.

### 7.7 Services Running on Each Host (16 checks)

dns02: BIND9, Stubby, Prometheus, BIND Exporter, Node Exporter, SNMP Exporter, Grafana Alloy, DNS Manager.  
dns01: BIND9, Stubby, Grafana, Prometheus, Loki, Grafana Alloy, BIND Exporter, Node Exporter.

### 7.8 Alert Rules Compliance (18+ checks)

All 18 documented Grafana alert rules verified: DNS Alerts (3), System Alerts (5), Network Alerts (1), pfSense Alerts (9).

### 7.9 Git Repository & Backup/DR Compliance (6 checks)

Repo accessibility (homelabocp, home_network), ArgoCD repo connection, branch validation, DNS zone backups, monitoring configs in git, VolumeSnapshotClass, .env gitignore.

---

## 8. Documentation Format

### Compliance Blocks in king_home_site.md

The existing `king_home_site.md` remains human-readable. Each section describing desired state is augmented with embedded `compliance` fenced code blocks that the deterministic engine parses.

```yaml
# Compliance Block Schema
system: string          # Target system identifier
resource: string        # Resource type and/or name
collector: string       # Collection method (snmp, kubernetes_api, argocd_api, 
                        #   grafana_api, prometheus_api, http_probe, dns_query,
                        #   ssh_command, docker_ps, loki_api)
target: string          # Optional target IP/hostname
endpoint: string        # Optional API endpoint path
namespace: string       # Optional Kubernetes namespace
assertions:
  - path: string        # JSONPath or PromQL expression
    operator: string    # equals, not_equals, contains, gte, lte, exists, 
                        #   not_exists, regex, in, resolves_to
    value: any          # Expected value
    severity: string    # critical, warning, info (default: warning)
    description: string # Human-readable description
```

The Documentation Discipline Feedback Loop: if Dave makes a change to the environment but forgets to update the Source of Truth, the Compliance Auditor agent flags it as non-compliant, surfacing documentation gaps as discrepancy findings.

---

## 9. Output Modes — Alerts & Reports

### 9.1 Real-Time Alerts (via Discord)

Critical and warning-level discrepancies trigger immediate Discord messages in a dedicated `#infra-alerts` channel on the private server.

| Severity | Trigger | Example |
|----------|---------|---------|
| **Critical** | Infrastructure down or degraded | Node NotReady, BIND9 unresponsive, WAN down |
| **Warning** | Configuration drift or non-compliance | ArgoCD out of sync, alert rule count changed |
| **Info** | Documentation gap detected | Running service not in Source of Truth |

### 9.2 Daily Discrepancy Report

Generated at 6:00 AM America/Phoenix. Delivered via Discord (`#compliance-reports` channel) and committed to the private backup Git repository.

Report includes: Executive summary with compliance score, discrepancy details with investigation results, compliance by domain breakdown, 7-day trend, documentation gap summary, escalation summary.

### 9.3 Compliance Score

```
Compliance Score = (Passed Checks / Total Checks) × 100

>= 98%  →  ✅ COMPLIANT (green)
90-97%  →  ⚠️ NON-COMPLIANT (yellow)
< 90%   →  ❌ CRITICAL (red)
```

---

## 10. Network Restrictions

The Infra OpenClaw Instance operates under strict network controls. There is **no internet access** beyond the two required external services.

### External Egress (NetworkPolicy)

| Destination | Protocol | Port | Purpose |
|------------|----------|------|---------|
| api.openai.com | HTTPS | 443 | LLM — OpenAI Codex |
| gateway.discord.gg | WSS | 443 | Discord Bot Gateway |
| discord.com | HTTPS | 443 | Discord REST API |

### Internal Access (NetworkPolicy)

| From | To | Protocol | Port | Purpose |
|------|-----|----------|------|---------|
| openclaw-infra pod | OpenShift API | HTTPS | 6443 | Cluster administration |
| openclaw-infra pod | Prometheus (dns02) | HTTP | 9090 | Metrics queries |
| openclaw-infra pod | Prometheus (dns01) | HTTP | 9090 | Federation metrics |
| openclaw-infra pod | Grafana | HTTP | 3000 | Dashboard/alert management |
| openclaw-infra pod | Loki | HTTP | 3100 | Log queries |
| openclaw-infra pod | pfSense | SNMP | 161 | Router state |
| openclaw-infra pod | dns01/dns02 | SSH | 22 | Service checks, commands |
| openclaw-infra pod | dns01/dns02 | DNS | 53 | Resolution checks |
| openclaw-infra pod | Synology NAS | HTTP | 5000 | DSM availability |
| openclaw-infra pod | Alloy UI | HTTP | 12345 | Collector status |
| openclaw-infra pod | openshift-gitops | HTTPS | in-cluster | ArgoCD API |

### What Is NOT Allowed

- No egress to any general internet endpoints
- No web search capability
- No access to package registries, container registries, or CDNs at runtime
- No access to any Anthropic API endpoints
- The only external routes are OpenAI API and Discord

---

## 11. LLM Configuration — OpenAI Codex

### Provider Details

| Setting | Value |
|---------|-------|
| Provider | OpenAI |
| Model | codex (or gpt-4.1 as appropriate for task) |
| API Endpoint | https://api.openai.com/v1/chat/completions |
| Authentication | OAuth token via ChatGPT Plus account |
| Usage | Investigation, analysis, natural language interaction |

### When LLM Is Used vs. Not Used

| Task | LLM Required? | Rationale |
|------|--------------|-----------|
| JSONPath assertion evaluation | No | Deterministic comparison |
| HTTP probe (status code check) | No | Simple pass/fail |
| DNS query (dig result parsing) | No | Structured response parsing |
| SNMP value comparison | No | Numeric comparison |
| Service inventory diff | No | Set comparison |
| Failed check investigation | **Yes** | Root cause analysis across systems |
| Ambiguous documentation interpretation | **Yes** | Semantic understanding |
| Natural language Discord interaction | **Yes** | Conversational responses |
| Report narrative generation | **Yes** | Summary and trend analysis |
| Multi-system correlation | **Yes** | Complex reasoning across data |
| Cluster administration commands | **Yes** | Intent interpretation and safety checks |

### OpenClaw Model Configuration

```json
{
  "models": {
    "default": {
      "provider": "openai",
      "model": "codex",
      "oauth": true,
      "baseUrl": "https://api.openai.com/v1"
    }
  }
}
```

**Note:** OpenClaw's OpenAI OAuth integration uses the ChatGPT Plus account token rather than a separate API key. The OAuth token is stored in the OpenShift Secret as `OPENAI_OAUTH_TOKEN` and managed through OpenClaw's credential store.

---

## 12. Discord Configuration

### Private Server Structure

| Channel | Purpose | Who Posts |
|---------|---------|-----------|
| `#general` | General interaction with the Infra instance | Dave ↔ Bot |
| `#cluster-admin` | OpenShift administration commands and responses | Dave ↔ Bot |
| `#infra-alerts` | Real-time compliance and monitoring alerts | Bot → Dave |
| `#compliance-reports` | Daily discrepancy reports | Bot → Dave |
| `#agent-logs` | Agent activity logs and audit trail | Bot → Dave |

### Bot Configuration

| Setting | Value |
|---------|-------|
| Bot Name | Guillermo (distinct from "Jarvis" main assistant) |
| Privileged Intents | Message Content Intent |
| Public Bot | Disabled |
| DM Policy | Allowlist (Dave's Discord User ID only) |
| Guild | Private server, Dave only |
| Permissions | Send Messages, Read Message History, Add Reactions, Attach Files, Embed Links |

### OpenClaw Discord Channel Config

```json
{
  "channels": {
    "discord": {
      "enabled": true,
      "dm": {
        "policy": "allowlist",
        "allowFrom": ["DAVE_DISCORD_USER_ID"]
      },
      "guilds": {
        "INFRA_GUILD_ID": {
          "allowFrom": ["DAVE_DISCORD_USER_ID"],
          "requireMention": false
        }
      }
    }
  }
}
```

---

## 13. Deployment Architecture — ArgoCD Application

### Separation of Concerns

| Concern | Managed By | Repository | What It Controls |
|---------|-----------|-----------|-----------------|
| OpenShift infrastructure resources | ArgoCD | `homelabocp` (existing) | Namespace, RBAC, PVC, Deployment, Service, NetworkPolicy, ConfigMap (base), Secret |
| OpenClaw agent configuration | OpenClaw (self-configure) | `openclaw-infra-config` (new private repo) | Agents, skills, MCP server configs, scheduling, Discord channel mappings |

**Why the separation:** ArgoCD is excellent at managing Kubernetes resources declaratively. OpenClaw configuration (agents, skills, MCP servers) is internal to the OpenClaw runtime and stored in its data volume. These are different concerns. ArgoCD ensures the pod is running; OpenClaw ensures the pod is configured correctly.

### Repository Structure (homelabocp)

```
homelabocp/
├── openclaw-infra/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── serviceaccount.yaml
│   │   ├── clusterrolebinding.yaml
│   │   ├── pvc.yaml
│   │   ├── configmap.yaml          # Base OpenClaw config (minimal)
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── networkpolicy.yaml
│   └── overlays/
│       └── homelab/
│           ├── kustomization.yaml
│           ├── deployment-patch.yaml
│           └── networkpolicy-patch.yaml   # Environment-specific CIDR ranges
```

### ArgoCD Application Manifest

```yaml
# argocd/applications/openclaw-infra.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: openclaw-infra
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: https://github.com/davidkingaz/homelabocp.git
    targetRevision: main
    path: openclaw-infra/overlays/homelab
  destination:
    server: https://kubernetes.default.svc
    namespace: openclaw-infra
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## 14. OpenShift Resource Manifests

### 14.1 Namespace

```yaml
# openclaw-infra/base/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: openclaw-infra
  labels:
    app: openclaw-infra
    purpose: homelab-infrastructure-agent
```

### 14.2 ServiceAccount with Cluster-Admin

```yaml
# openclaw-infra/base/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: openclaw-infra
  namespace: openclaw-infra
---
# openclaw-infra/base/clusterrolebinding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: openclaw-infra-cluster-admin
subjects:
  - kind: ServiceAccount
    name: openclaw-infra
    namespace: openclaw-infra
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

### 14.3 PersistentVolumeClaim

```yaml
# openclaw-infra/base/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: openclaw-infra-data
  namespace: openclaw-infra
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: synology-nfs-storage
```

### 14.4 ConfigMap (Base / Minimal)

This ConfigMap provides only the bare minimum configuration to get OpenClaw running and connected to Discord. All agent configuration, MCP servers, skills, and scheduling are handled by the self-configuration process (Section 16).

```yaml
# openclaw-infra/base/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: openclaw-infra-base-config
  namespace: openclaw-infra
data:
  config.json: |
    {
      "channels": {
        "discord": {
          "enabled": true,
          "dm": {
            "policy": "allowlist",
            "allowFrom": ["DAVE_DISCORD_USER_ID"]
          },
          "guilds": {
            "INFRA_GUILD_ID": {
              "allowFrom": ["DAVE_DISCORD_USER_ID"],
              "requireMention": false
            }
          }
        }
      },
      "models": {
        "default": {
          "provider": "openai",
          "model": "codex",
          "oauth": true,
          "baseUrl": "https://api.openai.com/v1"
        }
      },
      "gateway": {
        "http": {
          "endpoints": {
            "chatCompletions": {
              "enabled": true
            }
          }
        }
      },
      "security": {
        "exec": {
          "security": "deny",
          "ask": "on-miss",
          "askFallback": "deny"
        }
      }
    }
```

### 14.5 Secret (Created Manually — Not in Git)

```yaml
# Created via: oc create secret generic openclaw-infra-secrets -n openclaw-infra
# This is NOT stored in the Git repository
apiVersion: v1
kind: Secret
metadata:
  name: openclaw-infra-secrets
  namespace: openclaw-infra
  annotations:
    argocd.argoproj.io/compare-options: IgnoreExtraneous
type: Opaque
stringData:
  OPENAI_OAUTH_TOKEN: "..."         # OAuth token from ChatGPT Plus account
  DISCORD_BOT_TOKEN: "..."
  OPENCLAW_GATEWAY_TOKEN: "..."    # Generated with: openssl rand -hex 32
  GITHUB_SSH_PRIVATE_KEY: "..."    # For backup repo push access via SSH
```

### 14.6 Deployment (Headless — No Chromium)

```yaml
# openclaw-infra/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openclaw-infra
  namespace: openclaw-infra
  labels:
    app: openclaw-infra
spec:
  replicas: 1
  strategy:
    type: Recreate          # Single instance — no rolling update
  selector:
    matchLabels:
      app: openclaw-infra
  template:
    metadata:
      labels:
        app: openclaw-infra
    spec:
      serviceAccountName: openclaw-infra
      containers:
        - name: openclaw
          image: ghcr.io/openclaw/openclaw:latest    # Pin in overlay
          args: ["--headless"]                         # No UI, gateway only
          ports:
            - containerPort: 18789
              name: gateway
              protocol: TCP
          envFrom:
            - secretRef:
                name: openclaw-infra-secrets
          volumeMounts:
            - name: openclaw-data
              mountPath: /home/openclaw/.openclaw
            - name: openclaw-config
              mountPath: /home/openclaw/.openclaw/config.json
              subPath: config.json
          resources:
            requests:
              cpu: 500m
              memory: 1Gi
            limits:
              cpu: "2"
              memory: 2Gi
          livenessProbe:
            httpGet:
              path: /api/v1/ping
              port: 18789
            initialDelaySeconds: 30
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /api/v1/ping
              port: 18789
            initialDelaySeconds: 15
            periodSeconds: 10
      volumes:
        - name: openclaw-data
          persistentVolumeClaim:
            claimName: openclaw-infra-data
        - name: openclaw-config
          configMap:
            name: openclaw-infra-base-config
```

### 14.7 Service

```yaml
# openclaw-infra/base/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: openclaw-infra
  namespace: openclaw-infra
spec:
  selector:
    app: openclaw-infra
  ports:
    - port: 18789
      targetPort: 18789
      protocol: TCP
      name: gateway
  type: ClusterIP
```

### 14.8 NetworkPolicy

```yaml
# openclaw-infra/base/networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: openclaw-infra-network
  namespace: openclaw-infra
spec:
  podSelector:
    matchLabels:
      app: openclaw-infra
  policyTypes:
    - Egress
    - Ingress
  ingress: []              # No inbound traffic needed (Discord is outbound WebSocket)
  egress:
    # --- External: OpenAI API ---
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0      # OpenAI uses dynamic IPs; restrict via DNS policy if available
      ports:
        - protocol: TCP
          port: 443
    # --- Internal: OpenShift API ---
    - to:
        - ipBlock:
            cidr: 192.168.4.250/32
      ports:
        - protocol: TCP
          port: 6443
    # --- Internal: Kubernetes service network (for in-cluster ArgoCD, DNS, etc.) ---
    - to:
        - ipBlock:
            cidr: 172.30.0.0/16
      ports:
        - protocol: TCP
          port: 443
        - protocol: TCP
          port: 53
        - protocol: UDP
          port: 53
    # --- Internal: Homelab services (Home network) ---
    - to:
        - ipBlock:
            cidr: 192.168.4.0/24
      ports:
        - protocol: TCP
          port: 9090       # Prometheus (dns02)
        - protocol: TCP
          port: 22          # SSH (dns02)
        - protocol: TCP
          port: 53          # DNS
        - protocol: UDP
          port: 53          # DNS
        - protocol: UDP
          port: 161         # SNMP (pfSense)
        - protocol: TCP
          port: 5000        # Synology DSM
        - protocol: TCP
          port: 9100        # Node Exporter
        - protocol: TCP
          port: 9119        # BIND Exporter
        - protocol: TCP
          port: 9116        # SNMP Exporter
    # --- Internal: Homelab services (Lab network) ---
    - to:
        - ipBlock:
            cidr: 192.168.100.0/24
      ports:
        - protocol: TCP
          port: 3000        # Grafana
        - protocol: TCP
          port: 9090        # Prometheus (dns01)
        - protocol: TCP
          port: 3100        # Loki
        - protocol: TCP
          port: 22          # SSH (dns01)
        - protocol: TCP
          port: 53          # DNS
        - protocol: UDP
          port: 53          # DNS
        - protocol: TCP
          port: 12345       # Alloy UI
        - protocol: TCP
          port: 9100        # Node Exporter
        - protocol: TCP
          port: 9119        # BIND Exporter
        - protocol: TCP
          port: 5000        # DNS Manager
```

**Note on external egress:** The `0.0.0.0/0` CIDR on port 443 is broader than ideal. OpenAI and Discord use dynamic IP ranges. For tighter control, consider using an EgressNetworkPolicy (OpenShift-specific) with DNS-based rules, or a proxy that restricts to the specific FQDNs (api.openai.com, discord.com, gateway.discord.gg). The NetworkPolicy above is a pragmatic starting point — the pfSense firewall provides the additional layer of enforcement.

---

## 15. Prerequisites & Dependencies

### Infrastructure

| Component | Purpose | Status |
|-----------|---------|--------|
| OpenShift Cluster (5 nodes) | Runs the Infra OpenClaw instance | ✅ Existing |
| Synology NAS (NFS storage) | PVC backing via synology-nfs-storage | ✅ Existing |
| ArgoCD | Deploys OpenShift resources | ✅ Existing |
| Git Repositories | homelabocp (deployment), new private repo (config backup) | ✅ / 🔲 |
| Prometheus (dns01 + dns02) | Existing metrics | ✅ Existing |
| Grafana (dns01) | Existing dashboards and alerting | ✅ Existing |

### Accounts & Access

| System | Access Needed | Status |
|--------|--------------|--------|
| OpenAI | OAuth token via ChatGPT Plus account | 🔲 Required |
| Discord | Bot token + private server | 🔲 Create new |
| OpenShift | cluster-admin ServiceAccount | 🔲 Create via ArgoCD |
| Grafana | API key (Admin role) | 🔲 Create |
| GitHub | SSH deploy key for private backup repo | 🔲 Create |
| dns01/dns02 | SSH key for `adminuser` | ✅ Existing |
| pfSense | SNMP read (configured) | ✅ Existing |

### Software

| Component | Purpose | Notes |
|-----------|---------|-------|
| OpenClaw (headless) | Agent orchestration framework | Core runtime, no UI/Chromium |
| OpenAI Codex | LLM for investigation and interaction | Via API, no local model needed |
| Grafana MCP (certified) | Monitoring system integration | Official Grafana Labs MCP |
| Kubernetes MCP (certified) | Cluster administration integration | Official/community certified |
| MCP Server SDK | Build custom MCP servers | Python or TypeScript |
| jq / JSONPath library | Deterministic assertion evaluation | For compliance engine |

---

## 16. Self-Configuration Plan — Full Detailed Deployment Guide

**This is the section the Infra OpenClaw Instance will use to configure itself.**

After ArgoCD deploys the bare infrastructure and the unconfigured OpenClaw pod is running, Dave logs into the OpenClaw instance (via Discord or the Gateway API) and instructs it to follow this plan to fully configure itself.

### Prerequisites (Completed Before Self-Configuration Begins)

- [ ] ArgoCD has synced and the `openclaw-infra` pod is Running
- [ ] Gateway responds on `/api/v1/ping`
- [ ] Discord bot is created (token in Secret) and joined to private server
- [ ] OpenAI OAuth token is in the Secret and the pod can reach api.openai.com
- [ ] Dave can DM the bot or message it in the private server

### Step 1: Verify Base Connectivity

**Instructions to give the Infra OpenClaw Instance:**

> Verify your operational environment:
> 1. Confirm you can reach the OpenAI API by making a simple completion request
> 2. Confirm you are running in headless mode (no Chromium process)
> 3. Report your current configuration — what agents, skills, and MCP servers are configured
> 4. List the environment variables available to you (names only, not values) — confirm OPENAI_OAUTH_TOKEN is present
> 5. Verify you can access the Kubernetes API using your ServiceAccount token — run `kubectl get nodes` and report the result
> 6. Report your persistent storage mount and available space

**Expected outcome:** The instance confirms OpenAI connectivity, headless mode, empty agent/skill/MCP configuration, cluster-admin access showing 5 nodes, and a 10Gi PVC mounted at `~/.openclaw`.

### Step 2: Configure the Private Backup Repository

> Set up your configuration backup system:
> 1. Configure git with your identity (OpenClaw Infra Agent / openclaw-infra@kingfamilyaz.com) and load SSH key-based auth for GitHub push/pull
> 2. Clone the private repository via SSH: `git@github.com:davidkingaz/openclaw-infra-config.git` (or create it if it does not exist)
> 3. Create the following directory structure in the repo:
>    ```
>    openclaw-infra-config/
>    ├── README.md
>    ├── agents/             # Agent definition files
>    ├── skills/             # Skill definitions (SKILL.md files)
>    ├── mcp-servers/        # MCP server configurations
>    ├── schedules/          # Cron/heartbeat definitions
>    ├── compliance/         # Compliance check definitions and reports
>    │   └── reports/        # Daily discrepancy reports
>    └── backups/            # Configuration snapshots
>    ```
> 4. Commit and push the initial structure
> 5. Create a backup of your current `config.json` to `backups/config-{timestamp}.json`
> 6. Set up a recurring task to backup your configuration daily at midnight

**Expected outcome:** Private repo initialized with directory structure, initial backup committed.

### Step 3: Configure the Orchestrator Agent

> Configure yourself as the Orchestrator agent — the primary interface for all Discord interactions:
> 1. Set your identity/soul: You are the "Infra Agent" for the King Family homelab. Your primary role is infrastructure management, compliance auditing, and monitoring for the homelab OpenShift cluster and associated systems. You communicate exclusively via Discord. You use OpenAI Codex as your LLM. You have no internet access beyond OpenAI and Discord.
> 2. Configure agent routing rules:
>    - Messages mentioning "compliance", "audit", "discrepancy", or "documentation drift" → route to Compliance Auditor agent
>    - Messages mentioning "investigate alert", "why is X down", "check logs" → route to Monitoring Investigator agent
>    - Messages mentioning "deploy", "create namespace", "scale", "update", "oc " → route to Cluster Admin agent
>    - Messages mentioning "document", "report", "backup config" → route to Documentation agent
>    - All other messages → handle directly as Orchestrator
> 3. Back up the updated configuration to the Git repo

### Step 4: Configure the Cluster Admin Agent

> Create the Cluster Admin agent:
> 1. Agent name: `cluster-admin`
> 2. Role: OpenShift cluster administration with full cluster-admin privileges
> 3. Safety rules:
>    - Before executing any destructive operation (delete, drain, scale to 0, remove RBAC), present the action to the user on Discord and wait for explicit confirmation
>    - Never modify the `openclaw-infra` namespace resources without confirmation
>    - Never modify the `openshift-gitops` namespace without confirmation
>    - Log all actions to the `#agent-logs` Discord channel
> 4. Tools: kubectl/oc CLI access via the mounted ServiceAccount
> 5. Back up the agent configuration to the Git repo

### Step 5: Install Certified MCP Servers

> Install the certified MCP servers in this order:
>
> **5a. Grafana MCP (Official)**
> 1. Install the official Grafana MCP server
> 2. Configure connection to Grafana at http://192.168.100.221:3000
> 3. Use the Grafana API key from the GRAFANA_API_KEY environment variable (or configure one if it needs to be created first — you have admin access)
> 4. Verify connectivity: list datasources, list dashboards, query a simple Prometheus metric
> 5. Document the MCP server configuration in the backup repo
>
> **5b. Kubernetes/OpenShift MCP (Official)**
> 1. Install the official Kubernetes MCP server
> 2. Configure it to use the in-cluster ServiceAccount (automatic via mounted token)
> 3. Verify connectivity: get nodes, get namespaces, list pods in openclaw-infra namespace
> 4. Test a write operation: create and then delete a test ConfigMap in openclaw-infra namespace
> 5. Document the MCP server configuration in the backup repo
>
> After both are installed, run a basic integration test:
> - Use the Kubernetes MCP to check node status
> - Use the Grafana MCP to query a Prometheus metric for those nodes
> - Report the results correlating both sources

### Step 6: Configure the Compliance Auditor Agent

> Create the Compliance Auditor agent:
> 1. Agent name: `compliance-auditor`
> 2. Role: Third-party verification agent. Validates the homelab environment against `king_home_site.md` (the Source of Truth)
> 3. Access the Source of Truth: Clone or pull `king_home_site.md` from the private_files repository
> 4. Build the deterministic assertion engine:
>    - Parse compliance blocks from `king_home_site.md`
>    - Implement JSONPath evaluation against live system state
>    - No LLM needed for pass/fail comparisons
> 5. Start with the first compliance domain: **ArgoCD** (declarative by nature, clean API, easy to diff)
>    - Use the Kubernetes MCP to query ArgoCD resources in the openshift-gitops namespace
>    - Run the ArgoCD compliance assertions
>    - Report results
> 6. Configure check scheduling based on the tiered intervals in Section 3.3
> 7. Configure alert dispatch: send critical/warning findings to `#infra-alerts` on Discord
> 8. Configure daily report generation at 6:00 AM America/Phoenix → post to `#compliance-reports` on Discord and commit to backup repo
> 9. Back up all configuration to the Git repo

### Step 7: Configure the Monitoring Investigator Agent

> Create the Monitoring Investigator agent:
> 1. Agent name: `monitoring-investigator`
> 2. Role: Alert triage and root cause investigation
> 3. Use the Grafana MCP to query Prometheus and Loki for investigation
> 4. Use the Kubernetes MCP to check pod/node state when investigating cluster issues
> 5. Investigation workflow:
>    - Receive alert context (from Compliance Auditor or direct Discord message)
>    - Query relevant metrics from Prometheus via Grafana MCP
>    - Query relevant logs from Loki via Grafana MCP
>    - Check Kubernetes resource state via Kubernetes MCP
>    - Correlate findings across sources
>    - Report investigation summary to Discord
> 6. Back up configuration to Git repo

### Step 8: Configure the Documentation Agent

> Create the Documentation agent:
> 1. Agent name: `documentation`
> 2. Role: Report generation, documentation maintenance, and backup management
> 3. Capabilities:
>    - Generate and format the Daily Discrepancy Report
>    - Commit reports to the backup repository
>    - Maintain change logs
>    - Support documentation update workflows
> 4. Configure Git push access using SSH key auth
> 5. Back up configuration to Git repo

### Step 9: Build Custom MCP Servers (Phase 2)

> Build the following custom MCP servers in priority order. For each:
> - Create the MCP server code
> - Test connectivity and basic operations
> - Document in the backup repo
> - Wire into relevant agents
>
> **9a. Prometheus MCP** (direct access, supplements Grafana MCP)
> - Target: http://192.168.4.21:9090 and http://192.168.100.221:9090
> - Tools: query, query_range, get_targets, get_config, get_alerts
> - Value: Direct PromQL access, target health checks, SNMP-proxied metrics for pfSense
>
> **9b. ArgoCD MCP**
> - Target: openshift-gitops namespace (via Kubernetes API or ArgoCD CLI)
> - Tools: list_apps, get_app, get_sync_status, get_app_diff, get_app_history
> - Value: Detailed GitOps compliance and drift detection
>
> **9c. DNS MCP**
> - Target: dns01 and dns02 via SSH and dig
> - Tools: dig_query, get_zone_serial, check_zone_transfer, get_bind_status, get_stubby_status
> - Value: DNS infrastructure validation
>
> **9d. Docker/Host MCP**
> - Target: dns01 and dns02 via SSH
> - Tools: docker_ps, systemctl_status, check_port, get_file_content
> - Value: Service inventory validation on non-Kubernetes hosts

### Step 10: Build Extended MCP Servers (Phase 3)

> **10a. pfSense MCP**
> - Target: 192.168.4.1 (SNMP + REST API if package installed)
> - Tools: get_interfaces, get_firewall_rules, get_dhcp_config, get_vlans, get_system_info
>
> **10b. Synology MCP**
> - Target: 192.168.4.233 (HTTP/SNMP)
> - Tools: get_system_status, get_disk_status, get_raid_status, get_volume_usage
>
> **10c. Loki MCP** (direct access, supplements Grafana MCP)
> - Target: http://192.168.100.221:3100
> - Tools: query_logs, check_ready, get_labels, query_series

### Step 11: Expand Compliance Coverage

> With all MCP servers operational, expand the Compliance Auditor to cover all domains:
> 1. Add compliance checks for pfSense Router (15 checks)
> 2. Add compliance checks for DNS Infrastructure (22 checks)
> 3. Add compliance checks for OpenShift Cluster (20 checks)
> 4. Add compliance checks for Storage/Synology (12 checks)
> 5. Add compliance checks for Monitoring Stack (30 checks)
> 6. Add compliance checks for Service Inventory (16 checks)
> 7. Add compliance checks for Alert Rules (18+ checks)
> 8. Add compliance checks for Git/Backup/DR (6 checks)
> 9. Run a full compliance audit and generate the first complete Daily Discrepancy Report
> 10. Back up all compliance configurations to the Git repo

### Step 12: Final Configuration and Validation

> Complete the deployment:
> 1. Run a full system health check — verify all agents respond, all MCP servers connect, all compliance checks execute
> 2. Generate a comprehensive configuration backup to the Git repo
> 3. Test disaster recovery: document the exact steps needed to restore this instance from the backup repo to a fresh OpenClaw deployment
> 4. Post a summary report to `#general` on Discord with:
>    - Total agents configured
>    - Total MCP servers operational
>    - Total compliance checks active
>    - Compliance score from first full audit
>    - Backup repository status
>    - Next scheduled daily report time

---

## 17. Implementation Roadmap

### Phase 1 — Foundation (Week 1-2)

- [ ] Obtain OpenAI OAuth token from ChatGPT Plus account
- [ ] Create Discord bot and private server with channel structure
- [ ] Create private GitHub repo for configuration backup (`openclaw-infra-config`)
- [ ] Add OpenClaw Infra manifests to homelabocp repo
- [ ] Create OpenShift Secret manually (OpenAI OAuth token, Discord token, Gateway token, GitHub SSH key)
- [ ] Commit and push to homelabocp — let ArgoCD sync
- [ ] Verify pod is Running, Gateway responds on ping
- [ ] Verify Discord bot is online and responds
- [ ] Execute Self-Configuration Steps 1-3 (connectivity, backup repo, orchestrator)

### Phase 2 — Certified MCP + Core Agents (Week 2-3)

- [ ] Execute Step 4 (Cluster Admin agent)
- [ ] Execute Step 5a (Grafana MCP — certified)
- [ ] Execute Step 5b (Kubernetes MCP — certified)
- [ ] Execute Step 6 (Compliance Auditor agent — start with ArgoCD domain)
- [ ] Execute Step 7 (Monitoring Investigator agent)
- [ ] Execute Step 8 (Documentation agent)
- [ ] First partial compliance audit (ArgoCD + OpenShift domains)
- [ ] First daily discrepancy report (partial coverage)

### Phase 3 — Custom MCP Servers (Week 3-5)

- [ ] Execute Step 9a (Prometheus MCP)
- [ ] Execute Step 9b (ArgoCD MCP)
- [ ] Execute Step 9c (DNS MCP)
- [ ] Execute Step 9d (Docker/Host MCP)
- [ ] Expand compliance coverage to DNS, monitoring, and service inventory domains
- [ ] Augment `king_home_site.md` with compliance blocks for newly covered domains

### Phase 4 — Extended MCP + Full Coverage (Week 5-7)

- [ ] Execute Step 10a (pfSense MCP)
- [ ] Execute Step 10b (Synology MCP)
- [ ] Execute Step 10c (Loki MCP)
- [ ] Execute Step 11 (full compliance coverage — all ~152 checks)
- [ ] Execute Step 12 (final validation and disaster recovery documentation)

### Phase 5 — Polish & Automation (Week 7-8)

- [ ] Build compliance dashboard in Grafana
- [ ] Add compliance status to Kids' Status Page
- [ ] Implement weekly comprehensive audit (Sunday full review)
- [ ] Add trend tracking (7-day and 30-day) to daily reports
- [ ] Implement contradiction detection between prose and compliance blocks
- [ ] Add remediation suggestions (gated behind Discord confirmation)
- [ ] Document the Infra OpenClaw Instance itself in `king_home_site.md`

---

## 18. Key Design Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| LLM provider | OpenAI Codex (via ChatGPT Plus OAuth) | Anthropic end-user agreement compliance |
| Internet access | None (OpenAI + Discord only) | Security — minimize attack surface |
| Runtime mode | Headless (no UI, no Chromium) | No web browsing needed; reduces resource footprint |
| OpenShift access level | cluster-admin | Full infrastructure management capability |
| Deployment tool | ArgoCD | Existing GitOps workflow, declarative infrastructure |
| Configuration management | Self-configure via OpenClaw | Separation from ArgoCD — different concern |
| Communication channel | Discord (private server) | Existing pattern, rich features, mobile access |
| First MCP servers | Grafana + Kubernetes (certified) | Quality, security, community support |
| Compliance auditing | Sub-agent of Infra instance | Broader scope than standalone; shares MCP infrastructure |
| Destructive operations | Discord confirmation required | Safety gate for cluster-admin power |
| Configuration backup | Separate private GitHub repo | Recovery capability, version history |
| Documentation format | Augmented king_home_site.md with compliance blocks | Zero migration cost, single source of truth |
| Deterministic checks | No LLM (JSONPath assertions) | Fast, reliable, zero token cost for 80%+ of checks |
| Daily report timing | 6:00 AM America/Phoenix | Catch overnight drift before workday |
| Secret management | OpenShift Secrets (manual, not in Git) | No Sealed Secrets dependency; ArgoCD IgnoreExtraneous |

---

## Appendix A: Compliance Check Count

| Domain | Approximate Checks |
|--------|--------------------|
| pfSense Router | 15 |
| DNS Infrastructure | 22 |
| OpenShift Cluster | 20 |
| Storage / Synology | 12 |
| ArgoCD / GitOps | 13 |
| Monitoring Stack | 30 |
| Service Inventory | 16 |
| Alert Rules | 18+ |
| Git / Backup / DR | 6 |
| **Total** | **~152 discrete compliance assertions** |

---

## Appendix B: Separation of Concerns — ArgoCD vs OpenClaw

| What | Managed By | Stored In | Changes Via |
|------|-----------|----------|------------|
| Namespace | ArgoCD | homelabocp repo | Git commit → ArgoCD sync |
| ServiceAccount + RBAC | ArgoCD | homelabocp repo | Git commit → ArgoCD sync |
| PVC | ArgoCD | homelabocp repo | Git commit → ArgoCD sync |
| Deployment (pod spec) | ArgoCD | homelabocp repo | Git commit → ArgoCD sync |
| Service | ArgoCD | homelabocp repo | Git commit → ArgoCD sync |
| NetworkPolicy | ArgoCD | homelabocp repo | Git commit → ArgoCD sync |
| Base ConfigMap | ArgoCD | homelabocp repo | Git commit → ArgoCD sync |
| Secret | Manual (oc create) | OpenShift only | `oc` CLI |
| Agent definitions | OpenClaw | PVC + backup repo | Self-configure via Discord |
| Skill files | OpenClaw | PVC + backup repo | Self-configure via Discord |
| MCP server configs | OpenClaw | PVC + backup repo | Self-configure via Discord |
| Cron/heartbeat schedules | OpenClaw | PVC + backup repo | Self-configure via Discord |
| Discord channel mappings | OpenClaw | PVC + backup repo | Self-configure via Discord |

---

*This document is tailored to the King Family homelab as documented in `king_home_site.md` (February 2026). The Infra OpenClaw Instance serves as the centralized infrastructure management agent with cluster-admin access, compliance auditing, monitoring investigation, and documentation management capabilities. All LLM operations use OpenAI Codex in compliance with Anthropic's end-user agreement. The instance has no internet access beyond OpenAI and Discord. Implementation details should be refined iteratively as each self-configuration step is completed.*
