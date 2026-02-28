# openclaw-infra-config

Configuration backup for the **Infra OpenClaw Instance** ("Atlas") running on
the King Family homelab OpenShift cluster.

## What lives here

This repository holds the OpenClaw runtime configuration that ArgoCD does NOT
manage.  ArgoCD owns the pod infrastructure (namespace, RBAC, PVC, Deployment,
Service, NetworkPolicy, ConfigMaps).  This repo owns everything inside
OpenClaw's brain:

| Directory | Contents |
|-----------|----------|
| `agents/` | Agent definition files (Orchestrator, Cluster Admin, Compliance Auditor, Monitoring Investigator, Documentation) |
| `skills/` | Skill definitions (SKILL.md files) |
| `mcp-servers/` | MCP server configurations and connection details |
| `schedules/` | Cron / heartbeat definitions |
| `compliance/` | Compliance check definitions |
| `compliance/reports/` | Daily discrepancy reports (auto-generated, committed by Documentation agent) |
| `backups/` | Point-in-time snapshots of `config.json` (auto-committed daily at midnight) |

## Self-configuration

After ArgoCD deploys the bare pod and it is Running, follow the Self-
Configuration Plan in `infra-openclaw-instance-v1.md` (Steps 1–3 for Phase 1)
by messaging the bot in the private Discord server.

## Infrastructure repository

OpenShift manifests live in:
`git@github.com:davidkingaz/homelabocp.git` → `openclaw-infra/`

## Source of truth

`king_home_site.md` in the `private_files` repository is the compliance
source of truth used by the Compliance Auditor agent.
