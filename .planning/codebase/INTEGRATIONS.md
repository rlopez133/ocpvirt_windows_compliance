# External Integrations

**Analysis Date:** 2026-03-13

## APIs & External Services

**Red Hat Ansible Automation Platform (AAP):**
- AAP Gateway API - Job template management, automation execution
  - SDK/Client: `ansible.controller` collection (>=4.6.0)
  - Auth: `AAP_HOSTNAME`, `AAP_TOKEN` or `AAP_USERNAME`/`AAP_PASSWORD` env vars
  - Endpoint variable: `aap_hostname` (from environment or passed via playbook)
  - Connection: TLS/HTTPS with cert validation (configurable via `aap_validate_certs`)

- Event-Driven Ansible (EDA) API - Rulebook and event stream management
  - SDK/Client: `ansible.eda` collection
  - Auth: Same as AAP Gateway (shares auth through controller_host parameter)
  - Endpoint: `aap_hostname` (AAP Gateway routes to EDA in 2.5+)
  - Operations: Create/manage EDA projects, credentials, event streams, rulebook activations

**DISA Cyber Exchange / STIG Content:**
- STIG Benchmark Downloads - Windows Server STIG compliance frameworks
  - What it's used for: Compliance scanning benchmarks for SCC tool
  - URLs configured in `scc_install` role defaults:
    - `scc_stig_url_win2022` - Windows Server 2022 STIG
    - `scc_stig_url_win2019` - Windows Server 2019 STIG
    - `scc_stig_url_win2016` - Windows Server 2016 STIG
  - Note: DISA does not provide direct download links; content must be self-hosted
  - Source location: https://public.cyber.mil/stigs/scap/

**Prometheus Pushgateway:**
- Metrics ingestion endpoint
  - SDK/Client: `ansible.builtin.uri` module (HTTP REST)
  - What it's used for: Compliance scan metrics push (scores, control pass/fail counts)
  - HTTP Operations: POST metrics, DELETE old metrics
  - URL configured: `metrics_config.pushgateway_url` (default: `http://pushgateway.{{ tenant_config.namespace }}.svc:9091`)
  - Metrics format: OpenMetrics/Prometheus text format
  - Metrics pushed:
    - `compliance_score` - Overall compliance percentage
    - `compliance_controls_passed` - Count of passing controls
    - `compliance_controls_failed` - Count of failing controls
    - `compliance_control_status` - Per-control status (CAT1/CAT2/CAT3)
    - `compliance_last_scan_timestamp` - Scan completion time
    - `compliance_scan_duration_seconds` - Scan execution time
    - `compliance_scans_total` - Total scan count with success/failed status

## Data Storage

**Databases:**
- None (stateless scanning)

**File Storage:**
- **Kubernetes PersistentVolumeClaim (Primary):**
  - Type: PVC backend (default)
  - Purpose: Store scan results, XCCDF files, metrics, reports
  - Client: `kubernetes.core.k8s` module
  - Configuration:
    - Name: `tenant_config.storage.pvc_name` (default: "compliance-reports")
    - Namespace: `tenant_config.namespace` (default: "compliance")
    - Size: `tenant_config.storage.pvc_size` (default: "50Gi")
    - Storage class: `tenant_config.storage.pvc_storage_class` (default: cluster default)
    - Access mode: ReadWriteOnce

- **AWS S3 (Alternative):**
  - Purpose: Alternative for compliance data storage
  - Client: S3 API (configured via AAP S3 credential)
  - Configuration:
    - Enable: Set `tenant_config.storage.backend: "s3"`
    - Endpoint: `tenant_config.storage.s3_endpoint`
    - Bucket: `tenant_config.storage.s3_bucket`
    - Region: `tenant_config.storage.s3_region` (default: "us-east-1")
    - Credentials: AAP credential named "s3-reports"

- **Local Filesystem (Fallback):**
  - Path: `{{ results_storage.local_path }}` (default: "/tmp/compliance-results")
  - Purpose: Fallback storage when Pushgateway unavailable; metrics backup

**Caching:**
- None

## Authentication & Identity

**Auth Provider:**
- Red Hat Ansible Automation Platform (Custom via AAP)
  - Implementation: Bearer token authentication for AAP API
  - Token location: Environment variables or AAP credentials
  - AAP authenticates Ansible, Ansible authenticates to other services
  - EDA event stream auth: Bearer token credential stored in Kubernetes Secret

**Kubernetes Service Account Authentication:**
- Service account used for Kubernetes API operations
  - Created for Grafana dashboarding with `cluster-monitoring-view` role
  - Bearer token stored in `eda_token_secret_name` Kubernetes Secret (default: "eda-webhook-token")

## Monitoring & Observability

**Error Tracking:**
- None (custom error handling in playbooks)

**Logs:**
- Ansible task output (via `ansible.cfg` YAML callback)
- Local file fallback: `/tmp/compliance-results/{{ scan_id }}/metrics.prom` when Pushgateway unavailable
- Kubernetes event logs (via OpenShift logging)

**Metrics Collection:**
- Prometheus (OpenShift monitoring stack)
  - Location: `openshift-monitoring` namespace
  - Querier: `thanos-querier.openshift-monitoring.svc:9091` (TLS with bearer token)
  - Pushgateway integration: Batch metrics from scan jobs pushed to Pushgateway, scraped by Prometheus

## CI/CD & Deployment

**Hosting:**
- Red Hat Ansible Automation Platform (Self-hosted or SaaS)
- OpenShift Virtualization (target environment)

**CI Pipeline:**
- None detected (project is an Ansible collection, not a containerized application)
- Manual testing via pytest, ruff, ansible-lint
- Commands in CLAUDE.md: `ansible-lint`, `pytest`, `ruff check .`

**Collection Registry:**
- Ansible Galaxy / Ansible Hub (where collection is published)
- Source control: GitHub (for external collections like `infra.windows_ops`)

## Webhooks & Callbacks

**Incoming:**
- **AlertManager → EDA Event Stream Webhook:**
  - URL: `{{ eda_webhook_url }}` (generated during EDA setup)
  - Auth: Bearer token via HTTP Authorization header
  - Payload: AlertManager alert notifications (JSON)
  - Grouping strategy:
    - CAT1 (Critical): Grouped by alertname, namespace, category; 10s wait, 1h repeat
    - CAT2/CAT3: Grouped by alertname, namespace, category; 30s wait, 1h-4h repeat
  - Processing: EDA rulebook processes alerts and triggers remediation job templates

**Outgoing:**
- **EDA → AAP Job Template Execution:**
  - Triggered by webhook notifications from AlertManager
  - Executes remediation playbooks based on compliance violation category
  - Auto-remediation configurable:
    - `eda_auto_remediate_cat1` - Critical (off by default)
    - `eda_auto_remediate_cat2` - High
    - `eda_auto_remediate_cat3` - Medium

- **Scan Job → Pushgateway:**
  - Metrics push via HTTP POST
  - Endpoint: `{{ metrics_config.pushgateway_url }}`
  - Lifecycle: POST (create), DELETE old metrics before new push

- **Kubernetes API Operations:**
  - ConfigMap/Secret creation for results and configuration
  - PVC provisioning for storage
  - AlertmanagerConfig deployment for webhook routing
  - GrafanaDatasource and GrafanaDashboard resources for dashboards

## Environment Configuration

**Required env vars:**
- `AAP_HOSTNAME` - AAP Gateway URL (e.g., "automation-hub.example.com")
- `AAP_TOKEN` or (`AAP_USERNAME` + `AAP_PASSWORD`) - AAP credentials
- `scc_installer_url` - Download URL for SCC tool
- `scc_stig_url_win2022` - Download URL for Windows 2022 STIG content
- `scc_stig_url_win2019` - Download URL for Windows 2019 STIG content (optional)
- `scc_stig_url_win2016` - Download URL for Windows 2016 STIG content (optional)

**Secrets location:**
- `.env` file at repository root (gitignored, never committed)
- Pre-loaded in shell before running commands
- Referenced via `lookup('ansible.builtin.env', '...')` in playbooks
- Kubernetes Secrets for EDA token and S3 credentials:
  - `eda_token_secret_name` (default: "eda-webhook-token")
  - S3 credentials via AAP credential system

**Configuration files (not secrets):**
- `ansible.cfg` - Ansible runtime configuration
- `requirements.yml` - Collection dependencies
- Role defaults in `roles/*/defaults/main.yml` - Configurable via job template variables

---

*Integration audit: 2026-03-13*
