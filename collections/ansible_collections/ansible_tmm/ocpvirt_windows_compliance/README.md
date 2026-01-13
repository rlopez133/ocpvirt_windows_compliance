# Ansible Collection - ansible_tmm.ocpvirt_windows_compliance

Windows VM Compliance Lifecycle Management for OpenShift Virtualization.

## Description

This collection automates compliance lifecycle management for Windows VMs running on OpenShift Virtualization. It provides:

- **Scanning**: DISA SCAP Compliance Checker (SCC) integration for compliance assessment
- **Remediation**: Automated hardening for Windows Server 2019/2022 using DISA STIG controls
- **Monitoring**: Prometheus metrics, Grafana dashboards, and OpenShift alerts
- **Automation**: Event Driven Ansible (EDA) for automatic drift remediation
- **Reporting**: Audit-ready compliance reports with evidence collection

## Supported Compliance Frameworks

| Framework | Profile | Description |
|-----------|---------|-------------|
| DISA STIG | stig, stig-minimal | DoD Security Technical Implementation Guides |
| CIS | cis | Center for Internet Security Benchmarks |
| HIPAA | hipaa | Health Insurance Portability and Accountability Act |
| PCI-DSS | pci-dss | Payment Card Industry Data Security Standard |

## Requirements

### Platform

- OpenShift Container Platform 4.14+
- OpenShift Virtualization (latest)
- Ansible Automation Platform 2.5+
- Event Driven Ansible Controller

### Windows VMs

- Windows Server 2019 or 2022
- WinRM enabled (AAP manages connectivity)
- PowerShell 5.1+

### Ansible Dependencies

```yaml
collections:
  - ansible.windows >= 2.1.0
  - community.windows >= 2.0.0
  - kubernetes.core >= 3.0.0
  - ansible.eda >= 1.0.0
  - ansible.platform >= 2.0.0
```

## Installation

### From Ansible Galaxy

```bash
ansible-galaxy collection install ansible_tmm.ocpvirt_windows_compliance
```

### From Source

```bash
git clone https://github.com/ansible-tmm/ocpvirt_windows_compliance.git
cd ocpvirt_windows_compliance
ansible-galaxy collection build
ansible-galaxy collection install ansible_tmm-ocpvirt_windows_compliance-*.tar.gz
```

## Quick Start

### 1. Configure AAP Credentials (Manual Step)

Create the following credentials in AAP before proceeding:

| Credential | Type | Purpose |
|------------|------|---------|
| windows-winrm | Machine (Windows) | WinRM access to Windows VMs |
| openshift-api | OpenShift API | OpenShift API access |
| s3-reports | AWS | S3 storage for reports (optional) |

### 2. Run Setup

```yaml
# Configure AAP resources
ansible-playbook ansible_tmm.ocpvirt_windows_compliance.playbooks.aap.configure_aap \
  -e controller_host=aap.example.com \
  -e aap_organization=Default
```

### 3. Install SCC on Windows VMs

Use the **Install-SCC** job template in AAP to install DISA SCC on target VMs.

### 4. Run Compliance Scan

Use the **Compliance-Scan** job template in AAP with your desired profile.

### 5. View Results

- **Dashboard**: OpenShift Console → Observe → Dashboards → Windows Compliance
- **Alerts**: OpenShift Console → Observe → Alerting

## Roles

| Role | Description |
|------|-------------|
| setup | Environment setup (monitoring, EDA, dashboards) |
| scc_install | Download and install DISA SCC on Windows VMs |
| scan | Run compliance scans using DISA SCC |
| remediate | Dispatch remediation to OS-specific roles |
| win2022_stig | Windows Server 2022 STIG remediation |
| win2019_stig | Windows Server 2019 STIG remediation |
| report | Generate compliance reports |
| golden_image | Create pre-hardened golden images |

## Playbooks

| Playbook | Description |
|----------|-------------|
| setup.yml | Configure OpenShift monitoring and EDA |
| install_scc.yml | Install DISA SCC on Windows VMs |
| scan.yml | Run compliance scan |
| remediate.yml | Apply remediation |
| report.yml | Generate audit reports |
| provision_vm.yml | Provision VM from golden image |
| create_golden_image.yml | Create hardened golden image |

## Custom Modules

| Module | Description |
|--------|-------------|
| compliance_score | Calculate compliance score from scan results |
| scc_scan | Execute DISA SCC scan on Windows target |
| compliance_report | Generate formatted compliance reports |
| golden_image_capture | Capture VM as golden image DataVolume |

## Filter Plugins

| Filter | Description |
|--------|-------------|
| parse_xccdf | Parse XCCDF result XML |
| calculate_score | Calculate compliance score from findings |

## Multi-Tenancy

The collection supports multi-tenant deployments with namespace isolation:

- All resources scoped to tenant namespace
- Separate PrometheusRules per tenant
- Tenant-specific dashboards and alerts
- Storage isolation (PVC or S3 per tenant)

## License

Apache-2.0

## Author

Roger Lopez
