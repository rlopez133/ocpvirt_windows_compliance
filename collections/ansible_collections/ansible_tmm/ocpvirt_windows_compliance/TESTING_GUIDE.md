# Testing Guide: Windows VM Compliance Collection on AAP

This guide walks you through testing the `ansible_tmm.ocpvirt_windows_compliance` collection using **Ansible Automation Platform (AAP)**.

---

## Prerequisites

### Infrastructure Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| OpenShift Container Platform | 4.12+ | With OpenShift Virtualization operator |
| Ansible Automation Platform | 2.4+ | Controller + Event Driven Ansible |
| Windows VMs | Server 2019/2022 | Running on OCP Virtualization with WinRM enabled |
| Prometheus | - | OpenShift built-in or external (optional for EDA) |

### Required Access

- [ ] AAP Controller admin access
- [ ] OpenShift cluster access (for inventory sync)
- [ ] Windows VM administrator credentials
- [ ] Network connectivity from AAP Execution Environment to Windows VMs (port 5985/5986)

### Required Files

- [ ] DISA SCC installer ZIP (download from [DISA](https://public.cyber.mil/stigs/scap/))
- [ ] Collection tarball or Git repository URL

---

## Step 1: Build the Collection

On your development machine:

```bash
cd /path/to/ocpvirt_windows_compliance

# Build the collection tarball
ansible-galaxy collection build

# Output: ansible_tmm-ocpvirt_windows_compliance-1.0.0.tar.gz
```

You'll upload this to AAP or use a Git repository.

---

## Step 2: Create Credentials in AAP

### 2.1 Windows Machine Credential

1. Navigate to **Resources** → **Credentials**
2. Click **Add**
3. Fill in the form:

| Field | Value |
|-------|-------|
| **Name** | `Windows Compliance Credential` |
| **Organization** | Your organization |
| **Credential Type** | `Machine` |
| **Username** | `Administrator` |
| **Password** | Your Windows admin password |

4. Click **Save**

### 2.2 OpenShift API Credential

1. Navigate to **Resources** → **Credentials**
2. Click **Add**
3. Fill in the form:

| Field | Value |
|-------|-------|
| **Name** | `OpenShift API Credential` |
| **Organization** | Your organization |
| **Credential Type** | `OpenShift or Kubernetes API Bearer Token` |
| **OpenShift or Kubernetes API Endpoint** | `https://api.<your-cluster>:6443` |
| **API authentication bearer token** | Your service account token* |
| **Verify SSL** | Checked (provide CA cert if needed) |

4. Click **Save**

*To get a service account token:
```bash
oc create sa compliance-automation -n compliance-test
oc adm policy add-cluster-role-to-user cluster-reader -z compliance-automation -n compliance-test
oc sa get-token compliance-automation -n compliance-test
```

### 2.3 AAP Controller Credential (for EDA)

1. Navigate to **Resources** → **Credentials**
2. Click **Add**
3. Fill in the form:

| Field | Value |
|-------|-------|
| **Name** | `AAP Controller Credential` |
| **Organization** | Your organization |
| **Credential Type** | `Red Hat Ansible Automation Platform` |
| **Red Hat Ansible Automation Platform** | `https://aap-controller.example.com` |
| **Username** | Your AAP username |
| **Password** | Your AAP password |

4. Click **Save**

---

## Step 3: Create Project in AAP

### Option A: From Git Repository

1. Navigate to **Resources** → **Projects**
2. Click **Add**
3. Fill in the form:

| Field | Value |
|-------|-------|
| **Name** | `Windows Compliance Collection` |
| **Organization** | Your organization |
| **Execution Environment** | Default or custom EE with Windows collections |
| **Source Control Type** | `Git` |
| **Source Control URL** | `https://github.com/your-org/ocpvirt_windows_compliance.git` |
| **Source Control Branch/Tag/Commit** | `main` |

4. Click **Save**
5. Wait for the project to sync (check the status icon)

### Option B: Upload Collection Manually

1. In AAP, go to **Administration** → **Execution Environments**
2. Create a custom EE that includes your collection, OR
3. Upload the collection to a private Automation Hub and reference it in your project's `collections/requirements.yml`

---

## Step 4: Create Inventory in AAP

### 4.1 Create the Inventory

1. Navigate to **Resources** → **Inventories**
2. Click **Add** → **Add inventory**
3. Fill in the form:

| Field | Value |
|-------|-------|
| **Name** | `OCP Windows VMs` |
| **Organization** | Your organization |

4. Click **Save**

### 4.2 Add Inventory Variables

1. In the inventory you just created, click **Variables**
2. Add the following YAML:

```yaml
---
# WinRM connection settings for all Windows hosts
ansible_connection: winrm
ansible_winrm_transport: basic
ansible_winrm_server_cert_validation: ignore
ansible_port: 5986

# Collection defaults
tenant_namespace: compliance-test
scc_installer_url: "https://your-server/scc-5.12.1_Windows_bundle.zip"
```

3. Click **Save**

### 4.3 Add Hosts Manually

1. Click the **Hosts** tab
2. Click **Add**
3. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `win-test-01` |
| **Variables** | See below |

```yaml
---
ansible_host: 10.133.2.41  # Your VM's IP address
```

4. Click **Save**
5. Repeat for additional Windows VMs

### Alternative: Dynamic Inventory from OpenShift

1. In your inventory, click the **Sources** tab
2. Click **Add**
3. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `OpenShift Virtualization VMs` |
| **Source** | `OpenShift Virtualization` |
| **Credential** | `OpenShift API Credential` |
| **Update Options** | Check "Update on launch" |

4. Click **Save**
5. Click **Sync** to pull VMs from OpenShift

---

## Step 5: Setup Environment (Prometheus, Grafana, EDA)

**This is the most important step!** The setup playbook deploys all monitoring infrastructure:
- Prometheus alerting rules
- Grafana dashboards
- Alertmanager configuration
- EDA rulebook activation
- Storage PVC for reports

### 5.1 Create "Localhost" Inventory

The setup playbook runs against `localhost` to deploy resources to OpenShift.

1. Navigate to **Resources** → **Inventories**
2. Click **Add** → **Add inventory**
3. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `Localhost` |
| **Organization** | Your organization |

4. Click **Save**
5. Click the **Hosts** tab → **Add**
6. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `localhost` |
| **Variables** | See below |

```yaml
---
ansible_connection: local
ansible_python_interpreter: "{{ ansible_playbook_python }}"
```

7. Click **Save**

### 5.2 Create Setup Environment Job Template

1. Navigate to **Resources** → **Templates**
2. Click **Add** → **Add job template**
3. Fill in the form:

| Field | Value |
|-------|-------|
| **Name** | `Compliance - Setup Environment` |
| **Job Type** | `Run` |
| **Inventory** | `Localhost` |
| **Project** | `Windows Compliance Collection` |
| **Playbook** | `playbooks/setup.yml` |
| **Credentials** | `OpenShift API Credential` |
| **Variables** | See below |

```yaml
---
# Tenant Configuration
tenant_config:
  name: "production"
  namespace: "compliance-test"
  storage:
    backend: "pvc"
    pvc_name: "compliance-reports"
    pvc_size: "50Gi"
  alerting:
    thresholds:
      critical: 100
      warning: 95
      info: 80

# AAP Configuration
aap_config:
  controller_url: "https://aap-controller.example.com"
  organization: "Default"
  project_name: "Windows Compliance Collection"
  inventory_name: "OCP Windows VMs"

# EDA Configuration
eda_config:
  enabled: true
  controller_url: "https://eda-controller.example.com"
  webhook_port: 5001
  auto_remediate_cat1: false  # CAT I requires manual approval
  auto_remediate_cat2: true
  auto_remediate_cat3: true

# Enable all monitoring components
ocpvirt_compliance_enable_user_workload_monitoring: true
ocpvirt_compliance_alertmanager_dedicated: true
ocpvirt_compliance_grafana_dashboards: true
```

4. Click **Save**

### 5.3 Run the Setup Job Template

1. Navigate to **Resources** → **Templates**
2. Find `Compliance - Setup Environment`
3. Click the **rocket icon** (Launch)
4. Click **Launch**
5. Wait for the job to complete

**Expected Result:**
- PrometheusRules created in namespace
- Grafana ConfigMap with dashboard deployed
- Alertmanager configuration applied
- EDA rulebook activation configured
- PVC created for storing compliance reports

### 5.4 Verify Setup in OpenShift Console

1. **Prometheus Rules:**
   - OpenShift Console → **Observe** → **Alerting** → **Alerting rules**
   - Search for "compliance"
   - You should see rules like `ComplianceCAT1Violation`, `ComplianceCAT2Violation`, etc.

2. **Grafana Dashboard:**
   - OpenShift Console → **Observe** → **Dashboards**
   - Look for "Windows Compliance" dashboard

3. **Storage PVC:**
   ```bash
   oc get pvc -n compliance-test
   # Should show: compliance-reports   Bound   ...
   ```

---

## Step 6: Create Job Templates

### 6.1 Install SCC Job Template

> **Note:** Steps 6.1-6.4 create job templates for Windows VMs. These use the `OCP Windows VMs` inventory (not Localhost).

1. Navigate to **Resources** → **Templates**
2. Click **Add** → **Add job template**
3. Fill in the form:

| Field | Value |
|-------|-------|
| **Name** | `Compliance - Install SCC` |
| **Job Type** | `Run` |
| **Inventory** | `OCP Windows VMs` |
| **Project** | `Windows Compliance Collection` |
| **Playbook** | `playbooks/install_scc.yml` |
| **Credentials** | `Windows Compliance Credential` |
| **Variables** | See below |

```yaml
---
tenant_namespace: compliance-test
scc_installer_url: "https://your-server/scc-5.12.1_Windows_bundle.zip"
```

4. Under **Options**, check:
   - ✅ Enable Privilege Escalation

5. Click **Save**

### 6.2 Compliance Scan Job Template

1. Navigate to **Resources** → **Templates**
2. Click **Add** → **Add job template**
3. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `Compliance - Scan` |
| **Job Type** | `Run` |
| **Inventory** | `OCP Windows VMs` |
| **Project** | `Windows Compliance Collection` |
| **Playbook** | `playbooks/scan.yml` |
| **Credentials** | `Windows Compliance Credential` |
| **Variables** | See below |

```yaml
---
tenant_namespace: compliance-test
compliance_profile: stig
```

4. Click **Save**

### 6.3 Remediation Job Template

1. Navigate to **Resources** → **Templates**
2. Click **Add** → **Add job template**
3. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `Compliance - Remediate` |
| **Job Type** | `Run` |
| **Inventory** | `OCP Windows VMs` |
| **Project** | `Windows Compliance Collection` |
| **Playbook** | `playbooks/remediate.yml` |
| **Credentials** | `Windows Compliance Credential` |
| **Variables** | See below |

```yaml
---
tenant_namespace: compliance-test
remediate_cat1: true
remediate_cat2: true
remediate_cat3: false
```

4. Under **Options**, check:
   - ✅ Enable Privilege Escalation

5. Click **Save**

### 6.4 Generate Report Job Template

1. Navigate to **Resources** → **Templates**
2. Click **Add** → **Add job template**
3. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `Compliance - Generate Report` |
| **Job Type** | `Run` |
| **Inventory** | `OCP Windows VMs` |
| **Project** | `Windows Compliance Collection` |
| **Playbook** | `playbooks/report.yml` |
| **Credentials** | `Windows Compliance Credential` |
| **Variables** | See below |

```yaml
---
tenant_namespace: compliance-test
report_format: html
report_template: detailed
```

4. Click **Save**

---

## Step 7: Test Connectivity

### 7.1 Run Ad-Hoc Command

1. Navigate to **Resources** → **Inventories**
2. Click on `OCP Windows VMs`
3. Click the **Hosts** tab
4. Select your Windows host(s)
5. Click **Run Command**
6. Fill in:

| Field | Value |
|-------|-------|
| **Module** | `ansible.windows.win_ping` |
| **Machine Credential** | `Windows Compliance Credential` |

7. Click **Launch**

**Expected Result:**
```
win-test-01 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### 7.2 Troubleshooting Connection Issues

If the ping fails, verify from the AAP Execution Environment:

1. Navigate to **Administration** → **Execution Environments**
2. Note which EE your job template uses
3. SSH into the AAP controller node and test manually:

```bash
# Check if the EE has required Python packages
podman run --rm <ee-image> pip list | grep pywinrm

# Test WinRM connectivity
podman run --rm <ee-image> python3 -c "
import winrm
s = winrm.Session('http://<vm-ip>:5985/wsman',
    auth=('Administrator', 'password'),
    transport='basic')
print(s.run_cmd('hostname').std_out)
"
```

---

## Step 8: Run the Job Templates

### 8.1 Install SCC

1. Navigate to **Resources** → **Templates**
2. Find `Compliance - Install SCC`
3. Click the **rocket icon** (Launch)
4. Review the variables (modify if needed)
5. Click **Launch**
6. Monitor the job output

**Expected Result:**
- Job completes successfully (green)
- SCC installed at `C:\Program Files\SCC` on Windows VM

### 8.2 Run Compliance Scan

1. Navigate to **Resources** → **Templates**
2. Find `Compliance - Scan`
3. Click **Launch**
4. Monitor the job output

**Expected Result:**
- Scan completes
- XCCDF results generated on Windows VM
- Compliance score displayed in output

### 8.3 Apply Remediation

1. Navigate to **Resources** → **Templates**
2. Find `Compliance - Remediate`
3. Click **Launch**
4. **Optional:** Limit to specific hosts in the launch dialog

**Expected Result:**
- STIG controls applied
- Some settings may require reboot

### 8.4 Generate Report

1. Navigate to **Resources** → **Templates**
2. Find `Compliance - Generate Report`
3. Click **Launch**

**Expected Result:**
- HTML report generated
- Check job artifacts for download

---

## Step 9: Create Workflow (Optional)

Combine all steps into a single workflow:

### 9.1 Create Workflow Template

1. Navigate to **Resources** → **Templates**
2. Click **Add** → **Add workflow template**
3. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `Compliance - Full Lifecycle` |
| **Organization** | Your organization |
| **Inventory** | `OCP Windows VMs` |

4. Click **Save**

### 9.2 Design the Workflow

1. Click **Visualizer**
2. Click **Start**
3. Add nodes in this order:

```
[Start] → [Install SCC] → [Scan] → [Remediate] → [Scan Again] → [Generate Report]
```

For each node:
- Click **Add Node**
- Select the job template
- Configure convergence: "Any" or "All" based on your needs

4. Click **Save**

### 9.3 Run the Workflow

1. Navigate to **Resources** → **Templates**
2. Find `Compliance - Full Lifecycle`
3. Click **Launch**
4. Watch all jobs execute in sequence

---

## Step 10: Configure Event Driven Ansible (Optional)

### 10.1 Create Rulebook Activation in EDA Controller

1. Navigate to **EDA Controller** (separate URL from AAP Controller)
2. Go to **Rulebook Activations**
3. Click **Create rulebook activation**
4. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `Compliance Auto-Remediation` |
| **Project** | `Windows Compliance Collection` |
| **Rulebook** | `extensions/eda/rulebooks/compliance_remediation.yml` |
| **Decision Environment** | Your EDA decision environment |
| **Restart policy** | `On failure` |
| **Credential** | `AAP Controller Credential` |

5. Click **Create rulebook activation**
6. Enable the activation (toggle switch)

### 10.2 Configure Alertmanager Webhook

Add to your Alertmanager configuration:

```yaml
receivers:
  - name: 'eda-compliance'
    webhook_configs:
      - url: 'http://eda-controller:5000/endpoint'
        send_resolved: true

route:
  routes:
    - match:
        alertname: ComplianceViolation
      receiver: 'eda-compliance'
```

### 10.3 Test EDA Integration

1. Simulate an alert:

```bash
curl -X POST http://eda-controller:5000/endpoint \
  -H "Content-Type: application/json" \
  -d '{
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "ComplianceCAT2Violation",
        "severity": "cat2",
        "vm_name": "win-test-01",
        "namespace": "compliance-test"
      },
      "annotations": {
        "summary": "CAT2 compliance violation detected"
      }
    }]
  }'
```

2. Check EDA Controller → **Rule Audit** for triggered rules
3. Check AAP Controller → **Jobs** for auto-triggered remediation

---

## Step 11: Schedule Regular Scans

### 11.1 Add Schedule to Scan Template

1. Navigate to **Resources** → **Templates**
2. Click on `Compliance - Scan`
3. Click the **Schedules** tab
4. Click **Add**
5. Fill in:

| Field | Value |
|-------|-------|
| **Name** | `Weekly Compliance Scan` |
| **Start date/time** | Select date and time |
| **Repeat frequency** | `Week` |
| **Every** | `1` week |
| **On days** | Select day(s) |

6. Click **Save**

---

## Verification Checklist

### AAP Controller

- [ ] Credentials created (Windows, OpenShift, AAP)
- [ ] Project synced successfully
- [ ] Inventories created (Localhost + OCP Windows VMs)
- [ ] **Setup Environment job completed successfully**
- [ ] Win_ping ad-hoc command succeeds
- [ ] Install SCC job completes
- [ ] Scan job completes
- [ ] Remediate job completes (check mode first!)
- [ ] Report job generates HTML artifact
- [ ] Workflow executes all steps

### OpenShift (After Setup)

- [ ] PrometheusRules deployed (`oc get prometheusrules -n compliance-test`)
- [ ] Grafana dashboard ConfigMap created
- [ ] Alertmanager configured
- [ ] Storage PVC created (`oc get pvc -n compliance-test`)

### EDA Controller (Optional)

- [ ] Rulebook activation running
- [ ] Webhook receiving alerts
- [ ] Rules triggering correctly
- [ ] AAP jobs launching from EDA

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "No hosts matched" | Check inventory sync, verify host patterns |
| WinRM connection timeout | Verify firewall rules, check port 5985/5986 |
| SSL certificate errors | Set `ansible_winrm_server_cert_validation: ignore` |
| "Module not found" | Ensure Execution Environment has `pywinrm` installed |
| Project sync fails | Check Git URL and credentials |
| SCC download fails | Verify URL accessible from Windows VM |

### View Job Logs

1. Navigate to **Views** → **Jobs**
2. Click on the failed job
3. Review the **Output** tab
4. Click on specific tasks to see detailed output

### Debug Mode

To enable verbose logging, edit the job template:

1. Click on the job template
2. In the **Variables** section, add:

```yaml
ansible_verbosity: 3
```

3. Re-run the job

---

## Quick Reference: Job Template Variables

### Setup Environment (Run First!)
```yaml
tenant_config:
  name: "production"
  namespace: "compliance-test"
  storage:
    backend: "pvc"
    pvc_name: "compliance-reports"
    pvc_size: "50Gi"
aap_config:
  controller_url: "https://aap-controller.example.com"
eda_config:
  enabled: true
  controller_url: "https://eda-controller.example.com"
ocpvirt_compliance_grafana_dashboards: true
```

### Install SCC
```yaml
scc_installer_url: "https://server/scc-5.12.1_Windows_bundle.zip"
tenant_namespace: "compliance-test"
```

### Scan
```yaml
compliance_profile: "stig"           # stig, cis, or custom
scan_timeout: 3600                   # seconds
tenant_namespace: "compliance-test"
```

### Remediate
```yaml
remediate_cat1: true
remediate_cat2: true
remediate_cat3: false
skip_reboot: false
tenant_namespace: "compliance-test"
```

### Report
```yaml
report_format: "html"                # html, json, csv
report_template: "detailed"          # standard, detailed, executive
tenant_namespace: "compliance-test"
```

---

*Guide for ansible_tmm.ocpvirt_windows_compliance collection on Ansible Automation Platform*
