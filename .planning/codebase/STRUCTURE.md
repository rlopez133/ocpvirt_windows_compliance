# Codebase Structure

**Analysis Date:** 2026-03-13

## Directory Layout

```
ocpvirt_windows_compliance/
├── collections/                    # Ansible collection package
│   └── ansible_collections/
│       └── ansible_tmm/
│           └── ocpvirt_windows_compliance/
│               ├── galaxy.yml      # Collection metadata and dependencies
│               ├── README.md       # Collection documentation
│               ├── SECURITY.md     # Security guidelines
│               ├── TESTING_GUIDE.md  # Testing instructions
│               ├── playbooks/      # Entry point playbooks
│               ├── roles/          # Reusable task modules
│               ├── plugins/        # Custom filters and modules
│               ├── profiles/       # Compliance profile definitions
│               ├── files/          # Static assets
│               ├── inventory/      # Inventory group variables
│               ├── meta/           # Role metadata
│               └── docs/           # Generated documentation
├── extensions/                     # External integrations
│   └── eda/
│       └── rulebooks/             # EDA automation rulebooks
├── playbooks/                      # Shared playbooks (legacy)
├── specs/                          # Feature specifications
│   ├── 001-windows-compliance/
│   ├── 002-eda-alertmanager-setup/
│   ├── 003-scan-driven-remediation/
│   ├── 004-eda-auto-remediation/
│   ├── 005-easy-stig-remediations/
│   ├── 006-remediation-output/
│   ├── 007-remediation-map/
│   ├── 008-fix-cat2-cat3-remediation/
│   └── 009-wrap-redhat-stig-role/
├── local_files/                    # Local artifacts (reports, screenshots)
├── ansible.cfg                     # Ansible configuration
├── requirements.yml                # Galaxy collection dependencies
├── README.md                       # Project overview
├── CLAUDE.md                       # Development guidelines
├── .env                            # Environment variables (gitignored)
└── .planning/
    └── codebase/                   # Documentation written by mappers
        ├── ARCHITECTURE.md
        ├── STRUCTURE.md
        ├── CONVENTIONS.md
        ├── TESTING.md
        ├── STACK.md
        ├── INTEGRATIONS.md
        └── CONCERNS.md
```

## Directory Purposes

**collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/:**
- Purpose: Root of published Ansible collection package
- Contains: Playbooks, roles, plugins, profiles, documentation
- Key files: `galaxy.yml` (version/deps), `README.md` (user docs)
- Significance: This is the artifact users install via ansible-galaxy

**playbooks/:**
- Purpose: Main entry point playbooks for compliance workflows
- Contains: scan.yml, remediate.yml, setup.yml, report.yml, bootstrap_aap.yml, etc.
- Key files:
  - `scan.yml`: Initiates compliance scanning on Windows VMs
  - `remediate.yml`: Routes to OS-specific remediation roles
  - `setup.yml`: Infrastructure provisioning on OpenShift
  - `report.yml`: Generates compliance audit reports
  - `bootstrap_aap.yml`: Initial AAP configuration
- Pattern: Each playbook imports 1-2 main roles, handles pre/post tasks

**roles/:**
- Purpose: Encapsulate reusable compliance tasks
- Contains 10 roles organized by function:

  - `scan/`: Executes DISA SCC scans, parses XCCDF, calculates scores
  - `remediate/`: Routes remediation by OS version and category
  - `win2019_stig/`: Windows Server 2019-specific remediation (registry, policy, etc.)
  - `win2022_stig/`: Windows Server 2022-specific remediation (map-driven)
  - `win_stig_wrapper/`: Adapter for external Red Hat CoP STIG role (feature flag)
  - `report/`: Collects scan results, generates audit reports
  - `setup/`: Deploys infrastructure (Prometheus, Grafana, AlertManager, EDA)
  - `golden_image/`: Creates pre-hardened Windows VM templates
  - `scc_install/`: Installs DISA SCC tool on Windows targets
  - `provision_vm/`: Provisions Windows VMs on OpenShift

**roles/*/tasks/:**
- Purpose: Granular task decomposition within roles
- Structure: `main.yml` dispatches to sub-tasks:
  - `scan/tasks/`: preflight.yml, execute.yml, collect.yml, store.yml, metrics.yml
  - `remediate/tasks/`: Include external/internal STIG tasks by OS version
  - `win2022_stig/tasks/`: scan_driven_remediation.yml, scan_driven_cat2_remediation.yml, etc.

**roles/*/defaults/:**
- Purpose: Default variables and remediation maps
- Key files:
  - `win2022_stig/defaults/main.yml`: STIG patch toggles, password policies
  - `win2022_stig/defaults/cat2_remediation_map.yml`: V-ID → remediation method
  - `win2022_stig/defaults/cat3_remediation_map.yml`: CAT III control map

**plugins/filter/:**
- Purpose: Custom Jinja2 filters for compliance automation
- Key files:
  - `compliance_filters.py`: XCCDF parsing, score calculation, categorization
  - Filters:
    - `parse_xccdf`: Parse XCCDF result XML
    - `calculate_score`: Compute overall and per-category scores
    - `filter_findings`: Extract failed/passed/N/A controls
    - `categorize_findings`: Group findings by CAT1/2/3

**profiles/:**
- Purpose: Compliance profile definitions (STIG, CIS, HIPAA, PCI-DSS)
- Files: stig.yml (minimal/full), cis.yml, hipaa.yml, pci-dss.yml
- Usage: Define which controls are scanned/remediated for specific compliance frameworks

**extensions/eda/rulebooks/:**
- Purpose: Event-Driven Ansible automation logic
- Key files:
  - `compliance_remediation.yml`: Listen for AlertManager webhooks, trigger remediate job
  - Rules: CAT1/2/3 alert handlers with auto-remediation toggles

**files/:**
- Purpose: Static assets (scripts, dashboards, STIG profiles)
- Subdirectories:
  - `prometheus_rules/`: Prometheus alerting rules (CAT1/2/3 thresholds)
  - `grafana_dashboards/`: JSON dashboard definitions for Grafana
  - `sysprep/`: Windows Sysprep configs for golden image
  - `scripts/`: Utility scripts (metric formatting, report generation)

**inventory/group_vars/all/:**
- Purpose: Default inventory variables
- Key files: main.yml with scan defaults, metrics config, remediation toggles

**specs/:**
- Purpose: Feature specifications and implementation checklists
- Structure: One directory per feature (001-009)
- Contains: Markdown specs, acceptance checklists, contract definitions

## Key File Locations

**Entry Points:**
- `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/playbooks/scan.yml`: Compliance scan entry point
- `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/playbooks/remediate.yml`: Remediation entry point
- `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/playbooks/setup.yml`: Infrastructure setup entry point
- `playbooks/bootstrap_aap.yml`: AAP bootstrap (creates credentials, job templates)
- `extensions/eda/rulebooks/compliance_remediation.yml`: EDA alert handler

**Configuration:**
- `.env`: Environment variables (AAP_URL, AAP_TOKEN, scc_installer_url, etc.)
- `requirements.yml`: Galaxy collection dependencies (ansible.windows, kubernetes.core, etc.)
- `ansible.cfg`: Ansible configuration in playbooks/ and collection root
- `collections/.../galaxy.yml`: Collection version, author, tags, dependencies

**Core Logic:**
- `collections/.../plugins/filter/compliance_filters.py`: XCCDF parsing and scoring
- `collections/.../roles/remediate/tasks/main.yml`: Remediation routing dispatcher
- `collections/.../roles/win2022_stig/defaults/cat2_remediation_map.yml`: Control→method mapping
- `collections/.../roles/setup/tasks/main.yml`: Infrastructure orchestration

**Testing:**
- `TESTING_GUIDE.md`: Instructions for test setup and execution
- `specs/*/checklists/`: Test checklists per feature
- `local_files/`: Test artifacts (job output logs, screenshots)

**Documentation:**
- `README.md`: Project overview, architecture diagram, workflow description
- `SECURITY.md`: Security considerations, sensitive control handling
- `TESTING_GUIDE.md`: Comprehensive testing instructions
- `CLAUDE.md`: Development guidelines and active technologies

## Naming Conventions

**Files:**
- Playbooks: `{action}.yml` (scan.yml, remediate.yml, setup.yml)
- Roles: `{function}_[{os_version}]` (scan, remediate, win2022_stig, setup)
- Tasks: `{action}.yml` (main.yml dispatches to preflight.yml, execute.yml, etc.)
- Variables: `{scope}_{name}` (remediation_map, scan_result, alerts_fired)
- Filters: `{transformation}_[{domain}]` (parse_xccdf, calculate_score, filter_findings)

**Directories:**
- Collections: `ansible_collections/{namespace}/{collection_name}`
- Roles: `roles/{role_name}/`
- Playbooks: `playbooks/{workflow_name}.yml`
- Profiles: `profiles/{framework_name}/` (stig/, cis/, hipaa/)
- Tasks: `{role}/tasks/{action}.yml` (not in subdirectories)
- Defaults: `{role}/defaults/main.yml` (one file per role)

**Variables (Ansible):**
- Remediation toggles: `auto_remediate_cat{1,2,3}` (boolean)
- Configuration: `{domain}_config` (aap_config, eda_config, metrics_config)
- Results: `{action}_result` (scan_result, remediation_result)
- Feature flags: `use_{feature}` (use_external_stig_role)

## Where to Add New Code

**New Compliance Control (Map-Driven):**
1. Add control V-ID entry to `roles/win2022_stig/defaults/cat{1,2,3}_remediation_map.yml`
2. Add remediation method (registry, policy, user_rights, firewall)
3. If new remediation type needed: Add task to `roles/win2022_stig/tasks/` subdir
4. Test via `scan.yml` → `remediate.yml` workflow

**New Monitoring Alert Rule:**
1. Add rule to `files/prometheus_rules/` (e.g., `cat1_violation_rules.yml`)
2. Reference in `roles/setup/tasks/prometheus_rules.yml` for deployment
3. AlertManager webhook routing in `extensions/eda/rulebooks/compliance_remediation.yml`
4. Test: Trigger false control fail, verify alert fires and EDA routes correctly

**New Golden Image Configuration:**
1. Add template to `roles/golden_image/templates/`
2. Add Sysprep config to `files/sysprep/`
3. Create playbook `playbooks/create_golden_image.yml` (already exists, modify as needed)
4. Test: Run on test cluster, verify VM boots and compliance scan passes

**New Remediation Backend (External Role):**
1. Create wrapper role in `roles/` (e.g., `roles/win_stig_wrapper/`)
2. Add tasks to dispatch to external role with variable mapping
3. Set feature flag condition in `roles/remediate/tasks/main.yml`:
   ```yaml
   when: use_external_stig_role | default(false) | bool
   ```
4. Test with `use_external_stig_role: true` in remediate.yml extra_vars

**New Utility Filter:**
1. Add function to `plugins/filter/compliance_filters.py`
2. Register in `FilterModule.filters()` dict
3. Use in playbooks via `|custom_filter` syntax
4. Example: `{{ scan_result | parse_xccdf }}`

**New Infrastructure Component (Prometheus, AlertManager, etc.):**
1. Add setup task to `roles/setup/tasks/` (e.g., `roles/setup/tasks/alertmanager.yml`)
2. Add ConfigMap/deployment file to `files/` if needed
3. Call from `roles/setup/tasks/main.yml` dispatcher
4. Test via `setup.yml` playbook against test cluster

## Special Directories

**specs/:**
- Purpose: Feature specification and tracking
- Generated: No (hand-written markdown specs)
- Committed: Yes (version control of features)
- Pattern: One directory per feature (001-009)
- Usage: Reference for feature completeness, acceptance criteria

**local_files/:**
- Purpose: Local test artifacts and documentation
- Generated: Yes (from job execution)
- Committed: Yes (but documented as local artifacts)
- Pattern: Screenshots, logs, reports for reference
- Significance: Not part of collection distribution

**.planning/codebase/:**
- Purpose: Mapper-generated analysis documents
- Generated: Yes (by GSD mappers)
- Committed: Yes (consumed by planner/executor)
- Files: ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, STACK.md, INTEGRATIONS.md, CONCERNS.md

**files/grafana_dashboards/:**
- Purpose: Grafana dashboard JSON exports
- Generated: No (manually created in Grafana, exported to JSON)
- Committed: Yes (enables reproducible infrastructure)
- Pattern: One JSON file per dashboard (compliance_overview.json, vm_details.json, etc.)

**roles/*/meta/:**
- Purpose: Role metadata and dependencies
- Generated: No (hand-written)
- Committed: Yes
- Pattern: `main.yml` with role description, author, dependencies
