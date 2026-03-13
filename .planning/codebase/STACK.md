# Technology Stack

**Analysis Date:** 2026-03-13

## Languages

**Primary:**
- Ansible (YAML) - Core automation, playbooks, roles, and task definitions
- PowerShell 5.1+ - Windows-native task execution for STIG controls
- Python 3.9+ - Custom filter plugins for XCCDF parsing and score calculation

**Secondary:**
- Bash/Shell - Configuration scripts in EDA rulebooks
- JSON - ConfigMap data, scan results, metrics payloads

## Runtime

**Environment:**
- Red Hat Ansible Automation Platform (AAP) 2.5+ - Orchestration engine
- Event-Driven Ansible (EDA) - Rule-based automation triggers
- OpenShift/Kubernetes - Container orchestration for monitoring and EDA
- Windows Server 2016, 2019, 2022 - Target VMs for compliance scanning

**Package Manager:**
- Ansible Collection Manager (built-in) - Version: Not specified
- Lockfile: `requirements.yml` present
- Python pip - For custom Python dependencies in filter plugins

## Frameworks

**Core:**
- Ansible Collections (via `requirements.yml`):
  - `kubernetes.core` - Kubernetes API interaction
  - `community.windows` - Windows-specific modules
  - `ansible.windows` - Official Windows support
  - `ansible.controller` (>=4.6.0) - Ansible Controller/Tower integration
  - `ansible.platform` - Platform connectivity
  - `infra.aap_configuration` - AAP configuration as code
  - `infra.windows_ops` - Custom Windows operations (GitHub: rlopez133/infra.windows_ops, main branch)
  - `ansible.eda` - Event-Driven Ansible framework
  - `ansible.hub` - Ansible Hub integration

**Scanning/Compliance:**
- DISA SCAP Compliance Checker (SCC) - Windows compliance scanner
  - Version: 5.13 (configurable)
  - Integrated via `scc_install` role
  - Benchmarks: Windows Server 2022/2019/2016 STIG

**Testing/Linting:**
- ansible-lint - YAML/playbook validation
- pytest - Python test framework (configured in project)
- ruff - Python code checker

**Build/Dev:**
- ansible.cfg - Ansible configuration for callback plugins and task output
  - Callbacks: `yaml`, `timer`, `profile_tasks`
  - Settings: Cleaner output, task timing, reduced noise

## Key Dependencies

**Critical:**
- `kubernetes.core` - Manages Kubernetes/OpenShift resources (ConfigMaps, Secrets, PVCs, AlertmanagerConfig, Grafana resources)
- `ansible.windows` - Enables PowerShell execution on Windows VMs
- `ansible.eda` - Event-driven automation configuration via REST API
- `ansible.controller` (>=4.6.0) - AAP job template and automation management

**Infrastructure:**
- `infra.windows_ops` (custom git source) - Reusable Windows operations library
- `community.windows` - Additional Windows module support

## Configuration

**Environment:**
- Variables loaded from environment via `lookup('ansible.builtin.env', ...)`:
  - `AAP_HOSTNAME` - AAP Gateway URL for API connections
  - `AAP_USERNAME` - AAP authentication username
  - `AAP_PASSWORD` - AAP authentication password
  - `AAP_TOKEN` - AAP authentication token (alternative to username/password)
  - `scc_installer_url` - Hosted DISA SCC installer download URL
  - `scc_stig_url_win2022` - Windows 2022 STIG content URL
  - `scc_stig_url_win2019` - Windows 2019 STIG content URL
  - `scc_stig_url_win2016` - Windows 2016 STIG content URL (optional)

- Stored in `.env` file (gitignored) at repo root

**Build:**
- `ansible.cfg` - Location: `/Users/rlopez/git_projects/ocpvirt_windows_compliance/ansible.cfg`
  - stdout_callback: yaml (cleaner output)
  - callback_whitelist: timer, profile_tasks
  - Task output limit: 100 chars
  - Retry files disabled
  - Skipped hosts hidden, OK hosts shown

## Platform Requirements

**Development:**
- Python 3.9+ (for custom filter plugins)
- Ansible 2.13+ (collection requirement)
- Git (for referencing external collections from GitHub)

**Production:**
- **Deployment Target:** OpenShift Virtualization (OCP 4.10+)
- **VM Target:** Windows Server 2016, 2019, 2022
- **AAP:** Red Hat Ansible Automation Platform 2.5+ with AAP Gateway
- **Storage:** Persistent Volumes (OpenShift) or S3 (configurable)
- **Monitoring:** Prometheus + Grafana + AlertManager (OCP monitoring stack)

---

*Stack analysis: 2026-03-13*
