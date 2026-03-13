# Architecture

**Analysis Date:** 2026-03-13

## Pattern Overview

**Overall:** Event-Driven Compliance Automation with Scan-Driven Remediation Pipeline

**Key Characteristics:**
- Layered architecture separating scanning, remediation, monitoring, and orchestration
- Map-driven remediation approach that decouples control definitions from implementation
- Event-driven automation (EDA) integration for webhook-triggered auto-remediation
- Prometheus/Grafana observability with AlertManager for compliance violations
- Multi-tier Windows version support (2019/2022) with pluggable remediation backends

## Layers

**Orchestration Layer:**
- Purpose: AAP job templates and EDA rulebooks that trigger workflows
- Location: `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/playbooks/aap/`
- Contains: Job template configs, credential mappings, workflow definitions
- Depends on: Scan, remediation, report roles; Kubernetes API
- Used by: AAP controller, EDA activation engine

**Scanning Layer:**
- Purpose: Execute DISA SCC compliance scans on target Windows VMs
- Location: `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/scan/`
- Contains: Preflight checks, SCC execution, XCCDF parsing, metric calculation
- Depends on: DISA SCC tool installed on Windows, Pushgateway for metrics
- Used by: Scan playbook, scan-driven workflow, periodic compliance checks

**Remediation Layer:**
- Purpose: Apply compliance fixes based on failed controls (CAT I/II/III)
- Location: `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/remediate/`
- Contains: Remediation routing logic, category dispatch, external role integration
- Depends on: OS-specific STIG roles (win2019_stig, win2022_stig), remediation maps
- Used by: Remediate playbook, EDA rules, scan-driven workflows

**OS-Specific Implementation Layer:**
- Purpose: Windows version-specific control implementations
- Location:
  - `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/win2019_stig/`
  - `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/win2022_stig/`
  - `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/win_stig_wrapper/` (external CoP role integration)
- Contains: Registry edits, security policies, audit policies, user rights assignments, firewall rules
- Depends on: Remediation maps (cat2_remediation_map.yml, cat3_remediation_map.yml)
- Used by: Remediation layer role dispatching

**Monitoring & Observability Layer:**
- Purpose: Collect metrics, alert on violations, generate audit reports
- Location: `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/setup/`
- Contains: Prometheus setup, AlertManager config, Grafana dashboards, Pushgateway
- Depends on: OpenShift monitoring stack, Kubernetes API
- Used by: Infrastructure setup, compliance dashboards, alert routing

**Infrastructure Setup Layer:**
- Purpose: Bootstrap compliance infrastructure on OpenShift
- Location: `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/setup/tasks/`
- Contains: Namespace creation, ConfigMaps, storage provisioning, RBAC, EDA activation
- Depends on: OpenShift API, Kubernetes core collections
- Used by: Setup playbook, initial deployment

**Reporting Layer:**
- Purpose: Aggregate scan results and generate compliance audit reports
- Location: `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/report/`
- Contains: Result collection, report generation, template rendering
- Depends on: ConfigMaps (scan storage), local filesystem
- Used by: Report playbook, audit workflows

## Data Flow

**Scan-Driven Remediation (Primary Flow):**

1. User triggers Compliance-Scan job template (via AAP)
2. Scan role executes DISA SCC on target Windows VM
3. XCCDF results parsed by `compliance_filters.py` (parse_xccdf filter)
4. Compliance score calculated by calculate_score filter (CAT1/2/3 breakdown)
5. Results stored to OpenShift ConfigMaps (for audit trail)
6. Metrics pushed to Prometheus Pushgateway (for monitoring)
7. Prometheus scrapes Pushgateway every 30 seconds
8. AlertManager evaluates Prometheus rules (thresholds per CAT level)
9. If CAT1 failed > threshold: AlertManager fires alert
10. AlertManager webhook triggers EDA with alert payload
11. EDA rulebook catches compliance alert and routes to Compliance-Remediate job
12. Remediate role loads failed control IDs from alert
13. Dispatch to OS-specific remediation role (win2019_stig or win2022_stig)
14. Remediation map looked up for each failed control
15. Control-specific tasks execute (registry, policy, user rights, firewall)
16. Remediation metrics pushed back to Pushgateway
17. Compliance-Verify job runs scan again to confirm remediation success

**Event-Driven Auto-Remediation (EDA Flow):**

1. AlertManager webhook receives compliance alert payload from Prometheus
2. Payload contains: category (CAT1/2/3), failed control IDs, VM name, namespace
3. EDA rulebook matches alert in `extensions/eda/rulebooks/compliance_remediation.yml`
4. Rule condition evaluates: payload.status == "firing" AND category matches
5. Action: Run Compliance-Remediate job with extra_vars:
   - category: CAT1|CAT2|CAT3
   - trigger_source: "eda"
   - failed_control_ids: extracted from alert
   - auto_remediate_cat1/2/3: toggle (false by default for CAT1)
6. Remediate role checks auto_remediate toggle before applying fixes
7. If disabled: logs warning and skips execution
8. If enabled: applies map-driven remediation for specified controls
9. After completion: remediation metrics pushed to Pushgateway
10. Grafana dashboard updated with remediation status in real-time

**Infrastructure Setup Flow:**

1. User runs Setup playbook with tenant configuration
2. Setup role creates compliance namespace on OpenShift
3. Storage provisioned for scan results (PVC or ConfigMaps)
4. Prometheus + AlertManager deployed in monitoring stack
5. Grafana operator provisioned for dashboards
6. EDA controller configured with API connection
7. AAP controller configured with credentials/inventory
8. Job templates created for scan/remediate/report/setup
9. EDA activation created with compliance_remediation.yml rulebook
10. Monitoring rules deployed to Prometheus ConfigMap
11. Grafana dashboards deployed for compliance visualization

## Key Abstractions

**Remediation Map:**
- Purpose: Decouple control definitions from implementation logic
- Examples: `roles/win2022_stig/defaults/cat2_remediation_map.yml`, `cat3_remediation_map.yml`
- Pattern: V-ID → remediation method (registry, policy, user_rights, firewall, etc.)
- Used by: Remediate role to dynamically dispatch to appropriate control tasks

**Compliance Score:**
- Purpose: Quantify compliance state across severity categories
- Examples: Overall 87%, CAT1 95%, CAT2 82%, CAT3 78%
- Pattern: Calculated by `calculate_score` filter from parsed XCCDF results
- Used by: AlertManager rules, Grafana dashboards, compliance reports

**Control Category:**
- Purpose: Severity-based grouping of compliance controls
- Examples: CAT1 (high/critical), CAT2 (medium), CAT3 (low)
- Pattern: Derived from STIG severity mappings in scan results
- Used by: AlertManager routing, EDA rule conditions, remediation dispatch

**Trigger Source:**
- Purpose: Distinguish remediation origin (scan-driven vs EDA-triggered)
- Examples: trigger_source: "scan" | trigger_source: "eda" | trigger_source: "manual"
- Pattern: Set as playbook variable, used in decision logic and logging
- Used by: Remediate role to route to correct task handler, track remediation origin

**Scan Result Storage:**
- Purpose: Persist scan output for audit trail and report generation
- Examples: OpenShift ConfigMaps with scan_id as key
- Pattern: XCCDF XML stored in ConfigMap data, indexed by timestamp
- Used by: Report role for historical comparison, compliance audits

## Entry Points

**Compliance-Scan Job Template:**
- Location: `playbooks/scan.yml`
- Triggers: Manual schedule, workflow trigger, periodic cron
- Responsibilities: Execute scan on Windows VM, parse results, push metrics

**Compliance-Remediate Job Template:**
- Location: `playbooks/remediate.yml`
- Triggers: Scan-driven (via set_stats pass-through), EDA webhook, manual
- Responsibilities: Apply remediation, track changes, push metrics

**Compliance-Report Job Template:**
- Location: `playbooks/report.yml`
- Triggers: Manual schedule, post-remediation verification
- Responsibilities: Aggregate scan results, generate audit report

**Compliance-Setup Job Template:**
- Location: `playbooks/setup.yml`
- Triggers: Initial infrastructure deployment
- Responsibilities: Create namespace, deploy monitoring, configure EDA

**EDA Rulebook Activation:**
- Location: `extensions/eda/rulebooks/compliance_remediation.yml`
- Triggers: AlertManager webhook from Prometheus rule firing
- Responsibilities: Listen for alerts, route to remediate job, pass control IDs

## Error Handling

**Strategy:** Graceful degradation with explicit failure on critical paths

**Patterns:**

- **Preflight Validation:** Pre-flight checks in scan role verify Windows target, SCC installation, permissions
- **Dry-Run Mode:** All remediation tasks support `dry_run: true` flag to preview changes without applying
- **Skippable Controls:** Administrator-protected controls auto-skipped (e.g., Administrator rename blocks WinRM)
- **Manual Controls:** Controls without automation mapped to manual remediation category (tracked separately)
- **Restore Points:** System restore point created before remediation (can rollback if needed)
- **Metric Push Failures:** Ignored with `ignore_errors: true` (monitoring degradation acceptable)
- **Unknown OS Versions:** Explicit fail with clear message (2019/2022 only supported)
- **Missing Remediation Maps:** Controls not in map logged as "skipped" (not applied, not failed)

## Cross-Cutting Concerns

**Logging:**
- Ansible debug tasks display summaries at scan/remediate completion
- Remediation changes logged per control (registry, policy, user_rights counts)
- JSON report generated for Windows compliance with timestamp and metadata

**Validation:**
- Pre-play assertions verify Windows target and OS family
- Tenant configuration validated before infrastructure setup
- Remediation categories (CAT1/2/3) validated before task dispatch

**Authentication:**
- Windows: WinRM with Kerberos or basic auth (configured in inventory)
- OpenShift: Bearer token from environment variable or credential
- AAP: API token for job execution and artifact retrieval
- EDA: API auth delegated to AAP controller connection

**Multi-Tenancy:**
- Namespace isolation via tenant_namespace variable
- ConfigMaps scoped to tenant namespace for result storage
- AlertManager routes alerts by namespace label
- Grafana dashboards filtered by namespace

**Control Flow Toggles:**
- auto_remediate_cat1/2/3: Enable/disable category-specific auto-remediation in EDA
- use_external_stig_role: Feature flag to route Windows 2022 to external CoP role
- dry_run: Preview changes without applying
- store_results: Skip ConfigMap storage (for testing)
- push_metrics: Skip Pushgateway push (for isolated testing)
