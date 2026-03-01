# Runbook: Install Kubernetes/OpenShift MCP (In-Instance)

## Goal
Get Kubernetes/OpenShift MCP installed and registered in OpenClaw runtime.

## Preconditions
- OpenShift API reachable from runtime
- ServiceAccount token/CA present
- Dependency toolchain available

## Steps
1. Pull MCP source/artifact
2. Install dependencies
3. Configure MCP auth to use in-cluster SA
4. Register MCP in OpenClaw config
5. Validate read operations (nodes, namespaces, pods)
6. Validate safe write test (test ConfigMap create/delete)
7. Commit config/docs to backup repo

## Rollback
- Remove MCP registration
- Restart gateway/runtime if required
