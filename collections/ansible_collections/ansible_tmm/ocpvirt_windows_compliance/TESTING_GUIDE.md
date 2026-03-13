# Testing Guide: Windows VM Compliance Collection on AAP

This guide walks you through testing the `ansible_tmm.ocpvirt_windows_compliance` collection using **Ansible Automation Platform (AAP)**.

---

## Prerequisites

### Infrastructure Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| OpenShift Container Platform | 4.12+ | With OpenShift Virtualization operator |
| Ansible Automation Platform | 2.5+ | Controller + Event Driven Ansible (unified gateway) |
| Windows VMs | Server 2019/2022 | Running on OCP Virtualization with WinRM enabled |
| Prometheus | - | OpenShift built-in user workload monitoring |

### Required Access

- [ ] AAP Gateway admin access (AAP 2.5+ uses unified gateway)
- [ ] OpenShift cluster access (for inventory sync)
- [ ] Windows VM administrator credentials
- [ ] Network connectivity from AAP Execution Environment to Windows VMs (port 5985/5986)

### Required Files

- [ ] DISA SCC installer ZIP (download from [DISA](https://public.cyber.mil/stigs/scap/))
- [ ] Windows Server STIG content ZIPs (from DISA)
- [ ] Collection Git repository URL

---

## Step 1: Create Credentials in AAP

### 1.1 Windows Machine Credential

1. Navigate to **Automation Execution** → **Infrastructure** → **Credentials**
2. Click **Create credential**
3. Fill in the form:

| Field | Value |
|-------|-------|
| **Name** | `Win VM` |
| **Organization** | Default |
| **Credential Type** | `Machine` |
| **Username** | `Administrator` |
| **Password** | Your Windows admin password |

4. Click **Create credential**

### 1.2 OpenShift API Credential

1. Navigate to **Automation Execution** → **Infrastructure** → **Credentials**
2. Click **Create credential**
3. Fill in the form:

| Field | Value |
|-------|-------|
| **Name** | `OpenShift Credential` |
| **Organization** | Default |
| **Credential Type** | `OpenShift or Kubernetes API Bearer Token` |
| **OpenShift or Kubernetes API Endpoint** | `https://api.<your-cluster>:6443` |
| **API authentication bearer token** | Your service account token* |
| **Verify SSL** | Checked (provide CA cert if needed) |

4. Click **Create credential**

*To get a service account token:
```bash
oc create sa compliance-automation -n compliance
oc adm policy add-cluster-role-to-user cluster-reader -z compliance-automation -n compliance
oc create token compliance-automation -n compliance --duration=8760h
```

### 1.3 AAP Controller Credential (for Setup Role)

This credential allows the setup role to create job templates in AAP.

1. Navigate to **Automation Execution** → **Infrastructure** → **Credentials**
2. Click **Create credential**
3. Fill in the form:

| Field | Value |
|-------|-------|
| **Name** | `AAP Controller Credential` |
| **Organization** | Default |
| **Credential Type** | `Red Hat Ansible Automation Platform` |
| **Red Hat Ansible Automation Platform** | `https://<your-aap-gateway-url>` |
| **Username** | Your AAP username |
| **Password** | Your AAP password |
| **Verify SSL** | Checked |

4. Click **Create credential**

### 1.4 Automation Hub Credentials (for Collection Downloads)

Create credentials to access certified and validated collections from Automation Hub.

1. Navigate to **Automation Execution** → **Infrastructure** → **Credentials**
2. Click **Create credential**
3. Fill in the form for **Certified** content:

| Field | Value |
|-------|-------|
| **Name** | `AHub Credential Certified` |
| **Organization** | Default |
| **Credential Type** | `Ansible Galaxy/Automation Hub API Token` |
| **Galaxy Server URL** | `https://console.redhat.com/api/automation-hub/content/published/` |
| **API Token** | Your Red Hat Automation Hub token* |

4. Click **Create credential**
5. Repeat for **Validated** content:

| Field | Value |
|-------|-------|
| **Name** | `AHub Credential Validated` |
| **Organization** | Default |
| **Credential Type** | `Ansible Galaxy/Automation Hub API Token` |
| **Galaxy Server URL** | `https://console.redhat.com/api/automation-hub/content/validated/` |
| **API Token** | Your Red Hat Automation Hub token* |

6. Click **Create credential**

*Get your token from [console.redhat.com](https://console.redhat.com/ansible/automation-hub/token)

### 1.5 Add Automation Hub Credentials to Default Organization

**Important:** The AAP UI does not support adding galaxy credentials to organizations. You must use the API.

1. First, get your AAP API token or use basic auth
2. Find the credential IDs:

```bash
curl -sk -H "Authorization: Bearer <your-token>" \
  "https://<aap-gateway>/api/controller/v2/credentials/?name__icontains=AHub" \
  | jq '.results[] | {id, name}'
```

3. Add each credential to the Default organization (ID 1):

```bash
# Add AHub Credential Certified
curl -sk -X POST \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  "https://<aap-gateway>/api/controller/v2/organizations/1/galaxy_credentials/" \
  -d '{"id": <certified-credential-id>}'

# Add AHub Credential Validated
curl -sk -X POST \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  "https://<aap-gateway>/api/controller/v2/organizations/1/galaxy_credentials/" \
  -d '{"id": <validated-credential-id>}'
```

4. Verify the credentials were added:

```bash
curl -sk -H "Authorization: Bearer <your-token>" \
  "https://<aap-gateway>/api/controller/v2/organizations/1/galaxy_credentials/" \
  | jq '.results[] | {id, name}'
```

---

## Step 2: Create Project in AAP

1. Navigate to **Automation Execution** → **Projects**
2. Click **Create project**
3. Fill in the form:

| Field | Value |
|-------|-------|
| **Name** | `Windows Compliance Collection` |
| **Organization** | Default |
| **Execution Environment** | Default execution environment |
| **Source Control Type** | `Git` |
| **Source Control URL** | `https://github.com/rlopez133/ocpvirt_windows_compliance.git` |
| **Source Control Branch/Tag/Commit** | `010-e2e-testing-fixes` (or `main` for stable) |

4. Click **Create project**
5. Wait for the project to sync (check the status icon turns green)

---

## Step 3: Create Inventories in AAP

### 3.1 Create Windows VMs Inventory

1. Navigate to **Automation Execution** → **Infrastructure** → **Inventories**
2. Click **Create inventory**
3. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `Windows VMs` |
| **Organization** | Default |
| **Variables** | See below |

```yaml
---
# WinRM connection settings for all Windows hosts
ansible_connection: winrm
ansible_winrm_transport: basic
ansible_winrm_server_cert_validation: ignore
ansible_port: 5985
```

4. Click **Create inventory**

### 3.2 Add Windows Hosts

1. Click the **Hosts** tab
2. Click **Create host**
3. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `win-vm-01` |
| **Variables** | See below |

```yaml
---
ansible_host: 10.x.x.x  # Your VM's IP address
```

4. Click **Create host**
5. Repeat for additional Windows VMs

---

## Step 4: Create the Compliance-Setup Job Template

This is the **only job template you need to create manually**. It will create all other job templates automatically.

1. Navigate to **Automation Execution** → **Templates**
2. Click **Create template** → **Create job template**
3. Fill in the form:

| Field | Value |
|-------|-------|
| **Name** | `Compliance-Setup` |
| **Job Type** | `Run` |
| **Inventory** | `Demo Inventory` |
| **Project** | `Windows Compliance Collection` |
| **Playbook** | `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/playbooks/setup.yml` |
| **Credentials** | `OpenShift Credential`, `AAP Controller Credential` |
| **Variables** | See below |

```yaml
---
# Tenant Configuration
tenant_config:
  name: "default"
  namespace: "compliance"
  storage:
    backend: "pvc"
    pvc_name: "compliance-reports"
    pvc_size: "50Gi"

# AAP Job Template Configuration
aap_create_job_templates: true
aap_job_template_organization: "Default"
aap_job_template_project: "Windows Compliance Collection"
aap_credential_openshift: "OpenShift Credential"
aap_credential_windows: "Win VM"
aap_inventory_windows: "Windows VMs"
aap_inventory_localhost: "Demo Inventory"

# Playbook path (relative to project root)
aap_playbook_path_prefix: "collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/playbooks"

# EDA Configuration (optional - set eda_enabled: false to skip)
eda_enabled: true
eda_project_url: "https://github.com/rlopez133/ocpvirt_windows_compliance.git"
eda_organization: "Default"

# Monitoring
ocpvirt_compliance_enable_user_workload_monitoring: true
ocpvirt_compliance_grafana_dashboards: true
```

4. Click **Create job template**

### 4.1 Run the Compliance-Setup Job Template

1. Navigate to **Automation Execution** → **Templates**
2. Find `Compliance-Setup`
3. Click the **rocket icon** (Launch)
4. Click **Next** → **Launch**
5. Wait for the job to complete

**What gets created:**

| Resource | Description |
|----------|-------------|
| **Job Templates** | Install-SCC, Compliance-Scan, Compliance-Remediate, Compliance-Report, Provision-Compliant-VM, Create-Golden-Image |
| **PrometheusRules** | Alerting rules for compliance violations |
| **Pushgateway** | Deployment for metrics collection |
| **Grafana Operator** | Installed from OperatorHub if not present |
| **Grafana Dashboard** | Windows Compliance dashboard with Prometheus datasource |
| **EDA Components** | Project, Event Stream, Rulebook Activation, Credentials (if eda_enabled) |
| **Storage PVC** | For compliance reports |

---

## Step 5: Verify Setup in OpenShift

### 5.1 Check Prometheus Rules

```bash
oc get prometheusrules -n compliance
# Should show: compliance-alerts
```

### 5.2 Check Pushgateway

```bash
oc get deployment -n compliance | grep pushgateway
# Should show: pushgateway   1/1
```

### 5.3 Check Storage PVC

```bash
oc get pvc -n compliance
# Should show: compliance-reports   Bound   ...
```

### 5.4 Check EDA Components (if enabled)

In AAP Gateway, navigate to **Automation Decisions**:
- **Projects** → Should have "Windows Compliance" project
- **Rulebook Activations** → Should have "compliance-alerts-activation"
- **Event Streams** → Should have "compliance-alerts" with webhook URL

---

## Step 6: Test Connectivity to Windows VMs

### 6.1 Run Ad-Hoc Ping

1. Navigate to **Automation Execution** → **Infrastructure** → **Inventories**
2. Click on `Windows VMs`
3. Click the **Hosts** tab
4. Select your Windows host(s)
5. Click **Run command**
6. Fill in:

| Field | Value |
|-------|-------|
| **Module** | `ansible.windows.win_ping` |
| **Machine Credential** | `Win VM` |

7. Click **Launch**

**Expected Result:**
```
win-vm-01 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### 6.2 Troubleshooting Connection Issues

If the ping fails:

1. **Check WinRM is enabled on Windows VM:**
   ```powershell
   # On Windows VM
   winrm quickconfig
   winrm set winrm/config/service/auth '@{Basic="true"}'
   winrm set winrm/config/service '@{AllowUnencrypted="true"}'
   ```

2. **Check firewall allows WinRM:**
   ```powershell
   New-NetFirewallRule -Name "WinRM-HTTP" -DisplayName "WinRM HTTP" -Protocol TCP -LocalPort 5985 -Action Allow
   ```

3. **Verify network connectivity from AAP:**
   - Ensure AAP execution environment can reach Windows VM IP on port 5985/5986

---

## Step 7: Run Install-SCC

The Install-SCC job template has a **survey** that prompts for download URLs.

### 7.1 Prepare SCC Files

You need to host the following files on a web server accessible from your Windows VMs:
- SCC installer bundle (e.g., `scc-5.13_Windows_bundle.zip`)
- Windows Server 2022 STIG content (optional)
- Windows Server 2019 STIG content (optional)

Options:
- S3 bucket with presigned URLs
- Internal web server
- Any HTTPS endpoint accessible from VMs

### 7.2 Launch Install-SCC

1. Navigate to **Automation Execution** → **Templates**
2. Find `Install-SCC`
3. Click the **rocket icon** (Launch)
4. Fill in the survey:

| Field | Value |
|-------|-------|
| **SCC Installer URL** | `https://your-server/scc-5.13_Windows_bundle.zip` |
| **Windows Server 2022 STIG URL** | (optional) `https://your-server/U_MS_Windows_Server_2022_V2R2_STIG.zip` |
| **Windows Server 2019 STIG URL** | (optional) `https://your-server/U_MS_Windows_Server_2019_V3R3_STIG.zip` |

5. Click **Next** → **Launch**

**Expected Result:**
- Job completes successfully (green)
- SCC installed at `C:\Program Files\SCC` on Windows VM
- STIG content extracted to `C:\SCC\Resources\Content`

---

## Step 8: Run Compliance-Scan

1. Navigate to **Automation Execution** → **Templates**
2. Find `Compliance-Scan`
3. Click the **rocket icon** (Launch)
4. Click **Next** → **Launch**

**Expected Result:**
- Scan completes
- XCCDF results generated on Windows VM at `C:\SCC\Results\`
- Compliance score displayed in output:
  ```
  Scan Complete
  =============
  Target: win-vm-01
  Score: 45%
  Status: non_compliant
  Passed: 112
  Failed: 138
  CAT I Failed: 5
  Failed CAT I V-IDs: V-205711, V-205713, V-205919, ...
  ```

---

## Step 9: Run Compliance-Remediate

1. Navigate to **Automation Execution** → **Templates**
2. Find `Compliance-Remediate`
3. Click the **rocket icon** (Launch)
4. Optionally set **Limit** to target specific hosts
5. Click **Next** → **Launch**

**What happens:**
- For Windows 2022: Uses `infra.windows_ops` collection via `win_stig_wrapper` role
- For Windows 2019: Uses built-in `win2019_stig` role
- Applies registry settings, security policies, audit policies, user rights

**Expected Result:**
```
================================================================================
                            REMEDIATION RESULTS
================================================================================

Target:     win-vm-01
OS:         Windows Server 2022
Mode:       scan_driven
Category:   CAT1

Dry Run:    False
Started:    2026-02-11T10:30:00
Completed:  2026-02-11T10:35:00

--------------------------------------------------------------------------------
                            COMPLIANCE SUMMARY (External Role)
--------------------------------------------------------------------------------

Baseline:         Windows Server 2022 STIG
Total Controls:   250
Controls Passed:  245
Controls Failed:  5
Compliance Score: 98%
Status:           COMPLIANT
```

### 9.1 Re-run Compliance-Scan

After remediation, run another scan to verify improvements:

1. Run `Compliance-Scan` again
2. Compare scores - should see improvement

---

## Step 10: Create Workflow (Optional)

Combine scan and remediate into a single workflow:

### 10.1 Create Workflow Template

1. Navigate to **Automation Execution** → **Templates**
2. Click **Create template** → **Create workflow job template**
3. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `Compliance - Scan and Remediate` |
| **Organization** | Default |
| **Inventory** | `Windows VMs` |

4. Click **Create workflow job template**

### 10.2 Design the Workflow

1. Click **Visualizer** tab
2. Click **+** (Add step)
3. Add nodes:

```
[Start] → [Compliance-Scan] → [Compliance-Remediate] → [Compliance-Scan]
                                                              ↓
                                                        (Final Score)
```

4. Click **Save**

---

## Step 11: Event-Driven Ansible (Automatic)

If you enabled EDA in the setup (`eda_enabled: true`), the following was configured automatically:

### What's Configured

| Component | Description |
|-----------|-------------|
| **EDA Project** | Points to your Git repository |
| **Event Stream** | `compliance-alerts` with webhook URL and bearer token |
| **Token Credential** | Auto-generated bearer token for webhook auth |
| **RH AAP Credential** | Allows rulebook to trigger job templates |
| **Decision Environment** | Container image for running rulebooks |
| **Rulebook Activation** | `compliance-alerts-activation` listening for alerts |

### How It Works

1. **Scan pushes metrics** to Pushgateway
2. **Prometheus scrapes** metrics and evaluates rules
3. **Alertmanager fires** alert to EDA event stream webhook
4. **EDA rulebook** receives alert and triggers `Compliance-Remediate` job
5. **Remediation runs** automatically

### Verify EDA Setup

1. Navigate to **Automation Decisions** → **Rulebook Activations**
2. Find `compliance-alerts-activation`
3. Status should be `running`

### Test EDA Manually

Send a test webhook to the event stream:

```bash
# Get the webhook URL from EDA Event Streams
WEBHOOK_URL="https://<aap-gateway>/api/eda/v1/external_webhook/<uuid>/"
TOKEN="<your-generated-token>"

curl -X POST "$WEBHOOK_URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "ComplianceCAT1Violation",
        "severity": "cat1",
        "vm_name": "win-vm-01",
        "namespace": "compliance"
      },
      "annotations": {
        "summary": "CAT1 compliance violation detected",
        "failed_controls": "V-205711,V-205713"
      }
    }]
  }'
```

Check **Automation Execution** → **Jobs** for auto-triggered remediation.

---

## Step 12: Schedule Regular Scans (Optional)

### 12.1 Add Schedule to Scan Template

1. Navigate to **Automation Execution** → **Templates**
2. Click on `Compliance-Scan`
3. Click the **Schedules** tab
4. Click **Create schedule**
5. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `Weekly Compliance Scan` |
| **Start date/time** | Select date and time |
| **Repeat frequency** | `Week` |
| **Every** | `1` week |
| **On days** | Select day(s) |

6. Click **Create schedule**

---

## Verification Checklist

### AAP Controller

- [ ] Credentials created (Windows, OpenShift, AAP Controller)
- [ ] Project synced successfully
- [ ] Inventories created (Demo Inventory + Windows VMs)
- [ ] **Compliance-Setup job completed successfully**
- [ ] Job templates created (Install-SCC, Compliance-Scan, Compliance-Remediate, etc.)
- [ ] Win_ping ad-hoc command succeeds
- [ ] Install-SCC job completes
- [ ] Compliance-Scan job completes and shows score
- [ ] Compliance-Remediate job completes
- [ ] Re-scan shows improved score

### OpenShift

- [ ] PrometheusRules deployed (`oc get prometheusrules -n compliance`)
- [ ] Pushgateway running (`oc get deployment -n compliance`)
- [ ] Storage PVC created (`oc get pvc -n compliance`)

### EDA (if enabled)

- [ ] EDA Project synced
- [ ] Event Stream created with webhook URL
- [ ] Rulebook Activation status is `running`
- [ ] Test webhook triggers remediation job

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "No hosts matched" | Check inventory, verify host patterns |
| WinRM connection timeout | Verify firewall, check port 5985/5986 |
| SSL certificate errors | Set `ansible_winrm_server_cert_validation: ignore` |
| Project sync fails | Check Git URL, branch name, and credentials |
| SCC download fails | Verify URL accessible from Windows VM |
| EDA rulebook activation "failed" | Check decision environment image, project sync |
| "Credential not found" error in setup | Ensure credential names match exactly |
| Grafana Operator install times out | Check openshift-marketplace pods are running |

### View Job Logs

1. Navigate to **Automation Execution** → **Jobs**
2. Click on the failed job
3. Review the **Output** tab
4. Click on specific tasks to see detailed output

### Debug Mode

To enable verbose logging, edit the job template:

1. Click on the job template
2. Set **Verbosity** to `3 (Debug)`
3. Re-run the job

---

## Quick Reference: Job Template Variables

### Compliance-Setup (Run First!)
```yaml
tenant_config:
  name: "default"
  namespace: "compliance"
  storage:
    backend: "pvc"
    pvc_name: "compliance-reports"
    pvc_size: "50Gi"

aap_create_job_templates: true
aap_job_template_organization: "Default"
aap_job_template_project: "Windows Compliance Collection"
aap_credential_openshift: "OpenShift Credential"
aap_credential_windows: "Win VM"
aap_inventory_windows: "Windows VMs"
aap_inventory_localhost: "Demo Inventory"

eda_enabled: true
eda_project_url: "https://github.com/rlopez133/ocpvirt_windows_compliance.git"
```

### Install-SCC (Survey Prompted)
```yaml
# These are prompted via survey:
scc_installer_url: "https://server/scc-5.13_Windows_bundle.zip"
scc_stig_url_win2022: "https://server/U_MS_Windows_Server_2022_STIG.zip"  # optional
scc_stig_url_win2019: "https://server/U_MS_Windows_Server_2019_STIG.zip"  # optional
```

### Compliance-Scan
```yaml
# No required variables - uses defaults
store_results: true
push_metrics: true
```

### Compliance-Remediate
```yaml
dry_run: false
use_external_stig_role: true
# Controls come from scan results (failed_cat1_controls) or EDA trigger
```

### Compliance-Report
```yaml
tenant_namespace: "compliance"
report_format: "html"      # html | json | csv
report_template: "standard"  # standard | executive | detailed
```

---

*Guide for ansible_tmm.ocpvirt_windows_compliance collection on Ansible Automation Platform 2.5+*
