# Risk Register

## Active Risks
- API connectivity intermittency between runtime and OpenShift API
- In-instance resource pressure as MCP count grows
- Drift between implementation doc and live runtime behavior

## Mitigations
- Stabilize and validate API access before MCP onboarding
- Promote stable MCPs to GitOps-managed deployments
- Keep authoritative overrides updated in architecture doc
