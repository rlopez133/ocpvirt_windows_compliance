# Testing Patterns

**Analysis Date:** 2026-03-13

## Test Framework

**Runner:**
- Ansible testing: Ad-hoc commands in AAP UI, job template execution, playbook runs
- Python testing: Not configured (no pytest/unittest setup found)
- Manual/Integration testing approach: Tests performed via AAP job templates in real infrastructure
- Config: `ansible.cfg` in root and in playbooks directory for output control

**Run Commands:**
```bash
# Run ansible-lint on project
ansible-lint

# Run specific playbook
ansible-playbook playbooks/setup.yml

# Run with verbosity
ansible-playbook -vvv playbooks/setup.yml

# Run ruff check on Python code (per CLAUDE.md)
ruff check .

# Run ansible-cop-review (phase validation)
ansible-cop-review [changed-files]
```

## Test File Organization

**Location:**
- Primary tests: `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/TESTING_GUIDE.md`
- Test approach: Integrated into AAP job template workflow
- No unit test files found - testing is operational/integration focused
- Test guide covers end-to-end validation in real Kubernetes/AAP environment

**Naming:**
- Job templates created by setup role: `Install-SCC`, `Compliance-Scan`, `Compliance-Remediate`, `Compliance-Report`, `Provision-Compliant-VM`, `Create-Golden-Image`
- No test-specific file naming convention (tests executed as operational playbooks)

## Test Structure

**Testing Approach (from TESTING_GUIDE.md):**

Test execution follows sequential workflow:

```
1. Prerequisites Validation
   - Infrastructure requirements check (OCP 4.12+, AAP 2.5+, Windows VMs)
   - Required access verification (AAP access, OCP cluster, Windows credentials)
   - Required files check (DISA SCC installer, STIG content)

2. Setup Phase
   - Create credentials in AAP (Windows Machine, OpenShift API, AAP Controller, Automation Hub)
   - Create project in AAP (Git repo sync)
   - Create inventories (Windows VMs, Demo Inventory)
   - Create Compliance-Setup job template (this creates all other templates)
   - Run Compliance-Setup (auto-creates infrastructure)

3. Verification Phase
   - Verify PrometheusRules deployed
   - Verify Pushgateway running
   - Verify Storage PVC created
   - Verify EDA components if enabled (Event Stream, Rulebook Activation)

4. Connectivity Testing
   - Run ad-hoc win_ping command to verify WinRM connectivity
   - Troubleshoot connection issues if ping fails

5. Integration Test - Install SCC
   - Run Install-SCC job template with survey inputs
   - Verify SCC installed at C:\Program Files\SCC
   - Verify STIG content extracted to C:\SCC\Resources\Content

6. Integration Test - Scan
   - Run Compliance-Scan job template
   - Verify XCCDF results generated
   - Display compliance score in output

7. Integration Test - Remediate
   - Run Compliance-Remediate job template
   - Verify remediation applied (registry, policies, audit, user rights)
   - Display remediation results with score improvement

8. Validation - Re-scan
   - Run Compliance-Scan again
   - Compare scores to verify improvements

9. Optional: EDA Testing
   - Send test webhook to event stream
   - Verify rulebook automation triggers remediation job

10. Optional: Workflow Testing
    - Create workflow combining scan → remediate → scan
```

## Test Types

**Integration Tests:**
- Scope: End-to-end compliance workflow in real infrastructure
- Approach: Sequential job template execution with verification steps
- Validation: Output parsing for compliance scores, control counts, CAT level failures
- Setup verification: PrometheusRules, Pushgateway, PVC creation confirmation

**Ad-Hoc Commands:**
- `ansible.windows.win_ping` - Verify WinRM connectivity
- Shell commands to check SCC installation location
- PowerShell Get-ChildItem to verify file locations and timestamps
- JSON parsing of complex outputs

**Manual Inspection Tests:**
- View job logs in AAP UI after execution
- Check PrometheusRules: `oc get prometheusrules -n compliance`
- Check Pushgateway: `oc get deployment -n compliance | grep pushgateway`
- Check storage PVC: `oc get pvc -n compliance`
- Check EDA components: AAP Automation Decisions → Rulebook Activations

**Unit-Level Validation:**
- Python filter plugin validation: Called from Jinja2 templates in Ansible playbooks
- XCCDF XML parsing: Tested indirectly through scan result processing
- Score calculation: Validated by comparing expected vs actual compliance percentages

## Test Verification Checklist

**AAP Controller Tests (from TESTING_GUIDE.md):**

```
Credentials:
  [ ] Windows Machine Credential created
  [ ] OpenShift API Credential created
  [ ] AAP Controller Credential created
  [ ] Automation Hub credentials added to organization

Project and Inventory:
  [ ] Project synced successfully
  [ ] Windows VMs inventory created
  [ ] Demo Inventory available

Infrastructure Setup:
  [ ] Compliance-Setup job completed successfully
  [ ] Job templates created (6+ templates)
  [ ] Win_ping ad-hoc command succeeds

SCC Installation:
  [ ] Install-SCC job completes
  [ ] SCC at C:\Program Files\SCC
  [ ] STIG content at C:\SCC\Resources\Content

Compliance Operations:
  [ ] Compliance-Scan job completes and shows score
  [ ] Compliance-Remediate job completes without errors
  [ ] Re-scan shows improved compliance score

Workflow (optional):
  [ ] Workflow template "Compliance - Scan and Remediate" executes
  [ ] Workflow chain completes: Scan → Remediate → Scan
```

**OpenShift Verification:**

```
[ ] PrometheusRules deployed (oc get prometheusrules -n compliance)
[ ] Pushgateway running (oc get deployment -n compliance)
[ ] Storage PVC created (oc get pvc -n compliance)
[ ] Compliance reports stored in PVC
```

**EDA Verification (if eda_enabled: true):**

```
[ ] EDA Project synced
[ ] Event Stream created with webhook URL
[ ] Rulebook Activation status is 'running'
[ ] Test webhook triggers remediation job
```

## Mocking and Test Data

**Framework:** Not applicable - integration testing approach used

**Patterns:**
- No mocking framework in use
- Real Windows VMs required for testing
- Real Kubernetes cluster required for setup role testing
- DISA SCC tool required for scan testing
- Test uses real XCCDF files from DISA SCC scanner

**What to Mock (Not Done Currently):**
- WinRM connections would require mock infrastructure
- Kubernetes API would require mock cluster
- SCC scanner would require mock binary

**What NOT to Mock:**
- XCCDF XML parsing: Real scan results used
- Compliance score calculation: Real data validation critical
- Job template creation in AAP: Real API calls necessary
- Kubernetes resource creation: Real cluster required

## Test Data and Fixtures

**Fixture Approach:**
- No fixtures defined - uses real operational data
- Test credentials stored in AAP credentials system
- Test inventory created in AAP with real Windows VMs
- Test data: Real XCCDF scan results from DISA SCC

**Common Test Results (from TESTING_GUIDE.md):**

Expected Compliance-Scan output:
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

Expected Compliance-Remediate output (Windows Server 2022):
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

Baseline:         Windows Server 2022 STIG
Total Controls:   250
Controls Passed:  245
Controls Failed:  5
Compliance Score: 98%
Status:           COMPLIANT
```

## Coverage

**Requirements:** Not formally enforced (no coverage tool configured)

**Test Coverage Areas:**
- Ansible role execution: Covered via job template runs
- Python filter plugins: Indirectly covered when processing XCCDF results
- Windows remediation tasks: Covered via scan-driven remediation workflow
- Kubernetes resource creation: Covered via setup role execution
- EDA rulebook triggering: Optional manual test via webhook

## Debugging Patterns

**Enable Verbose Logging:**
1. Edit job template in AAP UI
2. Set **Verbosity** to `3 (Debug)` or higher
3. Re-run job and review output

**View Job Output:**
1. Navigate to **Automation Execution** → **Jobs**
2. Click on failed job
3. Review **Output** tab
4. Click on specific tasks for detailed trace

**Local Ansible Execution:**
```bash
# Run with increased verbosity
ansible-playbook -vvv playbooks/setup.yml

# Run specific role
ansible-playbook -vvv playbooks/setup.yml --tags setup_role
```

**Ansible Debugging:**
- Register task output: `register: result`
- Display registered variable: `debug: var=result`
- Check conditional logic: Add debug statements before when clauses
- Async job monitoring: Poll status with configured interval

## Known Testing Limitations

**Current Gaps:**
- No unit tests for Python filter plugins
- No automated functional tests (all tests manual/operational)
- No test environment isolation (tests run against live infrastructure)
- No CI/CD test automation found
- No pytest framework setup
- No test data fixtures for filter validation

**Safe Testing Patterns:**
- Always test in non-production cluster first
- Use separate Windows VM inventory for testing
- Run Compliance-Setup in isolated namespace
- Use `dry_run: true` flag for Compliance-Remediate to test without changes
- Run Install-SCC on test VMs before production deployment
- Compare scan results before/after remediation to validate effectiveness

---

*Testing analysis: 2026-03-13*
