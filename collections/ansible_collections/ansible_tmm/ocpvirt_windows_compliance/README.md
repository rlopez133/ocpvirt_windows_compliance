# Ansible Collection - ansible_tmm.ocpvirt_windows_compliance

**Windows VM Compliance Lifecycle Management for OpenShift Virtualization**

Automate STIG compliance scanning, remediation, and monitoring for Windows VMs running on OpenShift Virtualization with Red Hat Ansible Automation Platform.

## Overview

This collection provides end-to-end compliance lifecycle management for Windows Server VMs in OpenShift Virtualization environments. It integrates DISA SCAP Compliance Checker (SCC) for scanning, map-driven remediation for automated hardening, Prometheus/Grafana for monitoring, and Event-Driven Ansible (EDA) for automatic drift detection and remediation.

### Key Capabilities

| Capability | Description |
|------------|-------------|
| **Compliance Scanning** | DISA SCC integration with XCCDF result parsing and scoring by severity category |
| **Automated Remediation** | Map-driven remediation supporting CAT I, CAT II, and CAT III controls |
| **Real-Time Monitoring** | Prometheus metrics, AlertManager integration, and Grafana dashboards |
| **Event-Driven Automation** | EDA rulebooks that trigger remediation when compliance scores drop |
| **Audit Reporting** | Generate compliance reports with evidence collection for auditors |
| **Golden Images** | Create pre-hardened VM templates for consistent deployments |

## Target Audience

This collection is designed for:

- **Platform Engineers** managing OpenShift Virtualization clusters with Windows workloads
- **Security Teams** responsible for compliance enforcement across Windows infrastructure
- **DevOps/SRE Teams** automating compliance workflows in hybrid environments
- **Government/Defense Contractors** requiring DISA STIG compliance for Windows systems
- **Healthcare/Financial Organizations** needing HIPAA or PCI-DSS compliance automation

## Architecture

```
                                    ┌─────────────────────────────────────────────┐
                                    │           Ansible Automation Platform       │
                                    │  ┌─────────────┐  ┌────────────────────┐   │
                                    │  │ Job         │  │ Event-Driven       │   │
                                    │  │ Templates   │  │ Ansible (EDA)      │   │
                                    │  └──────┬──────┘  └─────────┬──────────┘   │
                                    └─────────┼───────────────────┼──────────────┘
                                              │                   │
                            ┌─────────────────┼───────────────────┼─────────────────┐
                            │                 ▼                   ▼                 │
                            │  ┌──────────────────────────────────────────────────┐│
                            │  │              OpenShift Cluster                   ││
                            │  │  ┌─────────────────────────────────────────────┐ ││
                            │  │  │           Compliance Namespace              │ ││
                            │  │  │  ┌────────────┐ ┌────────────┐ ┌──────────┐ │ ││
                            │  │  │  │Pushgateway │ │AlertManager│ │ Grafana  │ │ ││
                            │  │  │  └─────┬──────┘ └─────┬──────┘ └────┬─────┘ │ ││
                            │  │  │        │              │              │       │ ││
                            │  │  │        └──────────────┼──────────────┘       │ ││
                            │  │  │                       ▼                      │ ││
                            │  │  │              ┌────────────────┐              │ ││
                            │  │  │              │   Prometheus   │              │ ││
                            │  │  │              │     Rules      │              │ ││
                            │  │  │              └────────────────┘              │ ││
                            │  │  └─────────────────────────────────────────────┘ ││
                            │  │                                                  ││
                            │  │  ┌─────────────────────────────────────────────┐ ││
                            │  │  │        OpenShift Virtualization             │ ││
                            │  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐   │ ││
                            │  │  │  │Win 2022  │  │Win 2022  │  │Win 2019  │   │ ││
                            │  │  │  │   VM     │  │   VM     │  │   VM     │   │ ││
                            │  │  │  │(SCC+STIG)│  │(SCC+STIG)│  │(SCC+STIG)│   │ ││
                            │  │  │  └──────────┘  └──────────┘  └──────────┘   │ ││
                            │  │  └─────────────────────────────────────────────┘ ││
                            │  └──────────────────────────────────────────────────┘│
                            └───────────────────────────────────────────────────────┘
```


## Requirements

### Platform Requirements

| Component | Version | Purpose |
|-----------|---------|---------|
| OpenShift Container Platform | 4.14+ | Container orchestration |
| OpenShift Virtualization | Latest | Windows VM hosting (KubeVirt) |
| Ansible Automation Platform | 2.5+ | Automation controller |
| Event-Driven Ansible | 2.5+ | Alert-driven automation |

### Windows VM Requirements

- Windows Server 2019 or Windows Server 2022
- WinRM enabled (HTTP/5985 or HTTPS/5986)
- PowerShell 5.1+
- Administrator access for remediation

### Collection Dependencies

```yaml
dependencies:
  ansible.windows: ">=2.1.0"
  community.windows: ">=2.0.0"
  kubernetes.core: ">=3.0.0"
  ansible.eda: ">=1.0.0"
  ansible.platform: ">=2.0.0"
```

## Workflow

### Scan-Driven Remediation

```
┌──────────────┐    ┌───────────────┐    ┌────────────────┐    ┌──────────────┐
│   Run Scan   │───▶│ Parse Results │───▶│ Push Metrics   │───▶│ Fire Alerts  │
│   Job        │    │ (XCCDF)       │    │ (Pushgateway)  │    │ (Prometheus) │
└──────────────┘    └───────────────┘    └────────────────┘    └──────┬───────┘
                                                                       │
                                                                       ▼
┌──────────────┐    ┌───────────────┐    ┌────────────────┐    ┌──────────────┐
│   Verify     │◀───│ Apply Fixes   │◀───│ EDA Receives   │◀───│ AlertManager │
│   Compliance │    │ (Remediate)   │    │ Webhook        │    │ Webhook      │
└──────────────┘    └───────────────┘    └────────────────┘    └──────────────┘
```

### Remediation Categories

The collection uses map-driven remediation that categorizes controls:

| Category | Severity | Auto-Remediation | Description |
|----------|----------|------------------|-------------|
| **CAT I** | High/Critical | Configurable | Security vulnerabilities that could result in system compromise |
| **CAT II** | Medium | Configurable | Settings that could lead to security degradation |
| **CAT III** | Low | Configurable | Best practices and minor hardening |

## License

Apache-2.0

## Author

Roger Lopez
