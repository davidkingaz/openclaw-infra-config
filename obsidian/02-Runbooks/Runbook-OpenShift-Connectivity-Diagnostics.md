# Runbook: OpenShift Connectivity Diagnostics

## Checks
1. `oc whoami`
2. `oc get nodes`
3. API endpoint resolution and cert SAN alignment
4. In-cluster path to `kubernetes.default.svc:443`
5. NetworkPolicy egress to API server

## Common failures
- DNS resolution failure for external API hostname
- TLS SAN mismatch
- Timeout to `172.30.0.1:443`
