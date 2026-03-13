# Codebase Concerns

**Analysis Date:** 2026-03-13

## Tech Debt

### Dead/Unused Variables in Role Defaults

**Area:** All role `defaults/main.yml` files

**Issue:** Multiple variables marked with "NOTE: Not currently used" are retained in defaults files, creating noise and maintenance burden.

**Files:**
- `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/scan/defaults/main.yml` — contains `target_vms`, `metrics_retention_days`, `scan_thresholds`
- `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/remediate/defaults/main.yml` — contains `target_vms`, `allow_reboot`, `backup_before_change`, `max_retries`, `retry_delay`, `continue_on_error`

**Impact:** Code clutter reduces maintainability; developers must distinguish active from dead configuration. Unused variables may cause confusion about collection capabilities.

**Fix approach:** Delete all unused variable declarations from defaults files. Git history preserves deleted variables if they are needed in future versions.

---

### Commented-Out Task Block in bootstrap_aap.yml

**Area:** Playbook structure and maintenance

**Issue:** `playbooks/bootstrap_aap.yml` contains a full commented-out `inventory_source_update` task block at the end of the file. Additionally, the final "Display bootstrap summary" debug task references `inventory_sync_result` variable in conditional logic — that variable can only be set by the now-commented task.

**Files:**
- `playbooks/bootstrap_aap.yml` — full commented block at file end, stale reference in summary debug task

**Impact:** Dead code adds maintenance risk; developers must verify whether this code should be retained. Stale variable reference in conditional creates confusing logic.

**Fix approach:** Remove the commented-out `inventory_source_update` task block entirely. Change the conditional in the summary debug task to remove the stale `inventory_sync_result` check; use a static string "Skipped (run manually)" for the inventory sync summary line instead.

---

### Debug Discovery Tasks Left Over from Development

**Area:** SCC result parsing and task execution logging

**Issue:** `roles/scan/tasks/execute.yml` contains four debug tasks that are leftover troubleshooting artifacts from developing the SCC results discovery logic:
- "List contents of SCC Results directory"
- "Display SCC Results directory contents"
- "Display all found XCCDF files"
- "Display matching benchmark files"

These are development-time debugging aids with no operational value and should not fire in normal execution.

**Files:**
- `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/scan/tasks/execute.yml`

**Impact:** Unnecessary debug output clutters job execution logs and may confuse operators about what is normal behavior. Makes scan playbook execution less predictable.

**Fix approach:** Gate all four debug tasks behind a `scan_verbose_output: false` boolean flag (add to `roles/scan/defaults/main.yml`). Only fire debug tasks when `scan_verbose_output: true` is explicitly enabled. Keep the opening "Starting SCC Scan" and closing "Scan Execution Complete" debug tasks active by default.

---

### Remediation Summary Display Logic in Playbook Instead of Role

**Area:** Code organization and responsibility separation

**Issue:** `playbooks/remediate.yml` post_tasks contains two large multi-line debug summary blocks (scan-driven and external role mode) plus a `set_fact` for computing summary totals. This display and compute logic belongs in the `remediate` role, not in the playbook, violating separation of concerns.

**Files:**
- `playbooks/remediate.yml` — post_tasks block contains display logic
- `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/remediate/tasks/main.yml` — should contain this logic

**Impact:** Logic spread across playbook and role increases maintenance burden; changes to remediation output require updating both playbook and role. Playbook becomes harder to read with large embedded debug blocks.

**Fix approach:** Create `roles/remediate/tasks/display_summary.yml` containing:
- The `set_fact` that computes `total_changes`, `total_remediated`, `total_manual`, `total_skipped`
- The "EXTERNAL ROLE REMEDIATION RESULTS" debug block (when `use_external_stig_role`)
- The "SCAN-DRIVEN REMEDIATION SUMMARY / CHANGES APPLIED" debug block (fallback)

Call `display_summary.yml` at the end of `roles/remediate/tasks/main.yml`. Remove the entire post_tasks block from `playbooks/remediate.yml`.

---

### Verbose Assert Fail Messages in bootstrap_aap.yml

**Area:** Bootstrap playbook validation and error messages

**Issue:** Two `assert` tasks in `playbooks/bootstrap_aap.yml` have verbose `fail_msg` blocks that embed full CLI usage examples with syntax. This implementation guidance belongs in the playbook header comment (already present), not in the assertion failure message, which should be terse and action-oriented.

**Files:**
- `playbooks/bootstrap_aap.yml` — two assert tasks with overly detailed fail_msg values

**Impact:** Long assert fail messages reduce readability of job output; operators cannot quickly identify what validation failed without scrolling past usage examples.

**Fix approach:** Trim each `fail_msg` to one terse line stating what is missing (e.g., "Missing required environment variable: $AAP_URL"). Refer users to playbook comments or documentation for usage examples.

---

### Monolithic remediate/tasks/main.yml

**Area:** Task file organization and complexity

**Issue:** `roles/remediate/tasks/main.yml` is 280+ lines with four distinct logical concerns divided only by `# ====...====` banner comments:
1. Remediation mode detection and EDA toggle check
2. Windows version detection via win_shell, restore point creation, remediation start logging
3. OS/version/category routing and include_tasks calls
4. Metrics payload computation and Pushgateway URI call

This monolithic structure makes the file hard to navigate, test, and maintain.

**Files:**
- `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/remediate/tasks/main.yml`

**Impact:** Long task file increases cognitive load; developers must scan ~280 lines to understand full flow. Changes to one concern risk breaking others.

**Fix approach:** Split into focused task files:
- `tasks/determine_mode.yml` — remediation mode detection and EDA toggle check
- `tasks/detect_os.yml` — Windows version detection, restore point creation, remediation start logging
- `tasks/apply_remediation.yml` — OS/version/category routing and all include_tasks calls
- `tasks/push_metrics.yml` — metrics payload set_fact and Pushgateway URI call
- `tasks/main.yml` — becomes a short orchestrator that includes the above in order

---

### Fragile playbook_dir Path References in remediate/tasks/main.yml

**Area:** Path resolution and cross-role task inclusion

**Issue:** `roles/remediate/tasks/main.yml` uses `{{ playbook_dir }}/../roles/...` in 8 separate `include_tasks` and `include_vars` calls to reference tasks and defaults in sibling roles. This approach breaks silently if the role is called from a playbook outside the expected directory structure.

**Files:**
- `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/remediate/tasks/main.yml` — contains 8 hardcoded playbook_dir references

**Example references:**
```
{{ playbook_dir }}/../roles/win2019_stig/tasks/scan_driven_remediation.yml
{{ playbook_dir }}/../roles/win2019_stig/tasks/scan_driven_cat2_remediation.yml
{{ playbook_dir }}/../roles/win2019_stig/tasks/scan_driven_cat3_remediation.yml
{{ playbook_dir }}/../roles/win_stig_wrapper/defaults/main.yml
{{ playbook_dir }}/../roles/win_stig_wrapper/tasks/main.yml
{{ playbook_dir }}/../roles/win2022_stig/tasks/scan_driven_remediation.yml
{{ playbook_dir }}/../roles/win2022_stig/tasks/scan_driven_cat2_remediation.yml
{{ playbook_dir }}/../roles/win2022_stig/tasks/scan_driven_cat3_remediation.yml
```

**Impact:** Silent failures if remediate role is called from playbooks in non-standard directory locations. Playbook portability is severely limited; role becomes tightly coupled to filesystem layout.

**Fix approach:** Replace all `include_tasks: file: "{{ playbook_dir }}/../roles/..."` calls with `ansible.builtin.include_role` calls using the role name (e.g., `include_role: name: win2019_stig` with `tasks_from: scan_driven_remediation.yml`). This resolves correctly regardless of playbook location. For the `include_vars` call to win_stig_wrapper defaults, either reference via `role_path` or fold the variable inclusion into the wrapper role's own task flow.

---

## Known Bugs

### Missing win2022_stig Task File for Non-External Remediation

**Bug description:** `win2022_stig/tasks/scan_driven_remediation.yml` does not exist in the repository.

**Symptoms:** When `use_external_stig_role: false` on a Windows Server 2022 host, the remediate role attempts to include a non-existent task file, causing playbook execution to fail.

**Files:**
- `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/remediate/tasks/main.yml` — references the missing file
- Missing file: `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/win2022_stig/tasks/scan_driven_remediation.yml`

**Trigger:** Run remediation with `use_external_stig_role: false` on a Windows Server 2022 target.

**Workaround:** Use `use_external_stig_role: true` on Windows Server 2022 hosts, which delegates to the external `infra.windows_ops` role instead of the local remediation path.

---

## Security Considerations

### External Dependency on Unmaintained Git Repository

**Risk:** The collection depends on `infra.windows_ops` role from a GitHub fork (`https://github.com/rlopez133/infra.windows_ops.git` at `main` branch) that may not be actively maintained or security-reviewed.

**Files:**
- `requirements.yml` — declares `infra.windows_ops` from personal GitHub fork

**Current mitigation:** The fork contains critical STIG control mappings. However, tracking a fork at `main` branch introduces risk of undiscovered vulnerabilities or mapping errors in upstream STIG implementation.

**Recommendations:**
- Evaluate whether to pin to a stable tag instead of `main` branch
- Consider vendoring critical remediation logic into this collection instead of depending on external fork
- Implement security scanning of the upstream `infra.windows_ops` fork (SAST, dependency scanning)

---

### Control Mapping Errors in windows_manage_stig Role

**Risk:** The external `infra.windows_ops.windows_manage_stig` role has systematic V-ID to registry path mapping errors, causing remediation to appear successful while DISA SCC scans continue to fail.

**Files:** Issue documented in:
- `local_files/GITHUB_ISSUE_DRAFT.md` — Issues 1-3 with detailed evidence
- `local_files/VID_MAPPING_ISSUE_REPORT.md` — Spot-check of 6 CAT I controls, all incorrectly mapped
- `local_files/VID_MAPPING_ISSUE_2.md` — Additional CAT I and CAT II mapping errors

**Current impact:**
- V-254353 maps to Windows Error Reporting instead of AutoRun behavior
- V-254354, V-254374, V-254378, V-254381 similarly incorrect
- CAT I controls V-254467, V-254475 mapped as User Rights instead of Registry Settings
- 5 CAT I registry controls completely missing from role: V-254441, V-254446, V-254466, V-254469, V-254474

**Recommendations:**
- Audit ALL V-ID mappings in `infra.windows_ops` against official DISA XCCDF (`U_MS_Windows_Server_2022_STIG_V2R7_Manual-xccdf.xml`)
- Add validation tests that compare role output against DISA SCC scan results
- Consider implementing a compliance mapping verification job that runs scans before and after remediation to catch such errors in future updates

---

### Audit Policy Remediation Breaks Paired Controls

**Risk:** When remediating individual audit policy controls in the external `infra.windows_ops` role, the role inadvertently disables the paired audit type (success/failure), causing previously passing controls to fail. This creates a "whack-a-mole" compliance situation.

**Files:** Issue documented in:
- `local_files/GITHUB_ISSUE_DRAFT.md` — Issue 1 with root cause analysis

**Example failure scenario:**
- V-254315 (Other Object Access Events - Success) — PASS
- V-254316 (Other Object Access Events - Failure) — FAIL
- Remediate only V-254316 (failure auditing enabled)
- V-254315 now FAILS (success auditing was disabled by the remediation)

**Root cause:** Control data specifies individual success/failure flags without querying current state or preserving paired settings.

**Recommendations:**
- Query current audit policy state before remediation: `auditpol /get /subcategory:"$SubcategoryName"`
- Only modify the specific flag being remediated; preserve the other
- OR: Always remediate paired controls together and ensure control data includes both success and failure requirements

---

## Performance Bottlenecks

### XCCDF Parsing in Filter Plugin Without Caching

**Slow operation:** The `parse_xccdf` filter in `compliance_filters.py` re-parses XML on every invocation without memoization or result caching.

**Files:**
- `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/plugins/filter/compliance_filters.py` — lines 41-87

**Cause:** XCCDF result files from large Windows STIG scans can contain thousands of rule results. Parsing is O(n) in rules, and if the filter is called multiple times per scan (in different tasks), parsing overhead accumulates.

**Improvement path:**
- Implement result caching at the playbook level using `set_fact` to store parsed results once
- Document that filter should be called once per scan and results stored in a variable
- Consider adding a simple in-memory cache decorator to the filter for repeat invocations within a single playbook run

---

## Fragile Areas

### XCCDF Namespace Detection and Version Handling

**Component:** XCCDF parsing logic

**Files:**
- `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/plugins/filter/compliance_filters.py` — lines 50-63

**Why fragile:** The parser detects XCCDF 1.1 vs 1.2 namespaces by checking if the root tag starts with a specific namespace URL. This detection is brittle:
1. If namespace declaration changes format, detection may fail silently
2. Only two namespace versions are handled; newer XCCDF 1.3 would be treated as 1.2 and may cause mapping failures
3. No validation that namespace was actually detected; parser continues with default namespace if detection fails

**Safe modification:**
- Add explicit checks for detected namespace and raise clear error if neither 1.1 nor 1.2 is found
- Add `ns_version` to parse result dictionary to allow downstream tasks to verify which namespace was used
- Add unit tests that verify parsing against sample XCCDF files from multiple SCAP versions

**Test coverage:** No unit tests exist for the filter plugin itself. Parser behavior is only verified through integration tests (live SCC scans).

---

### Severity-to-Category Mapping Logic

**Component:** XCCDF severity classification

**Files:**
- `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/plugins/filter/compliance_filters.py` — lines 205-241

**Why fragile:** The `_extract_severity` method uses a multi-step fallback approach:
1. Check for severity attribute on result element
2. Fall back to pattern matching on rule ID (e.g., `_CAT1_`, `-CC-`)
3. Default to "medium" if neither approach succeeds

This is fragile because:
1. If severity attribute is present but has unexpected value, it falls through silently
2. Rule ID pattern matching assumes consistent naming across STIG versions; a renamed control breaks classification
3. Default to "medium" masks mis-categorized controls; compliance reports show controls as medium-risk when they may be critical

**Safe modification:**
- Log warnings when severity cannot be determined or attribute has unexpected value
- Add validation that at least one categorization method succeeded before returning
- Consider raising exception (rather than defaulting) when severity cannot be determined from any source

---

### Metrics Push to Pushgateway Without Retry Logic

**Component:** Compliance metrics export

**Files:**
- `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/remediate/tasks/main.yml` — metrics push section
- `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/scan/tasks/metrics.yml`

**Why fragile:** Pushing metrics to Pushgateway uses a single URI call without retry or timeout handling. If Pushgateway is temporarily unavailable, the push silently fails and metrics are lost.

**Safe modification:**
- Add `retries` and `delay` to URI tasks pushing to Pushgateway
- Add `timeout` to prevent hanging indefinitely on network issues
- Log failures at WARN level so operators know metrics were not exported

---

## Scaling Limits

### No Limit on Concurrent Remediation Tasks

**Resource/System:** Windows remediation execution

**Current capacity:** Collection does not explicitly limit concurrent tasks per target.

**Limit:** If remediation tasks are highly parallelized (many handlers or async tasks), Windows VMs may experience resource exhaustion (CPU, WinRM connections) and timeouts.

**Scaling path:**
- Add `max_retries` and `retry_delay` configuration to remediate role defaults (currently marked as unused variables to be deleted)
- OR: Implement task batching (e.g., apply remediation in groups of 10 controls with sequential execution) to prevent overwhelming target VMs

---

## Dependencies at Risk

### Upstream windows_manage_stig Role Data Accuracy

**Package:** `infra.windows_ops` (external dependency)

**Risk:** The entire collection's compliance remediation accuracy depends on the correctness of STIG control-to-registry mappings in the external role. The spot-check in `local_files/VID_MAPPING_ISSUE_REPORT.md` found 6/6 CAT I controls were incorrectly mapped, suggesting systematic data quality issues.

**Impact:** If upstream role has mapping errors, this collection produces false compliance reports and non-compliant systems appear compliant.

**Migration plan:**
- Option A: Vendor the remediation logic into this collection so STIG mappings are directly owned and tested
- Option B: Implement automated validation tests that run SCC scans before and after remediation, failing the build if compliance doesn't improve
- Option C: Switch to an alternative maintained STIG remediation source (e.g., Red Hat's official Windows STIG role if available)

---

## Missing Critical Features

### No Pre-Flight Validation of Target VM STIG Baseline

**Problem:** Collection does not validate that the target VM has the expected STIG version or OS level before starting remediation. If a Windows Server 2019 VM is accidentally targeted with Windows Server 2022 remediation, it will fail mid-run.

**Blocks:** Safe multi-version remediation across heterogeneous fleets.

**Suggested solution:** Add preflight checks in remediate role:
- Query Windows version and verify it matches expected OS in playbook parameters
- Query installed STIG version if available
- Verify WinRM connectivity and permissions before attempting remediation

---

### No Rollback or Restore Point Functionality

**Problem:** While restore points are created at remediation start, there is no automated rollback mechanism if remediation fails. Operators must manually restore from snapshot or restore point.

**Blocks:** Self-healing remediation workflows; requires manual intervention on failures.

**Suggested solution:**
- Add optional `restore_on_failure` flag to remediate role
- Capture remediation results and on failure status, invoke `Restore-ComputerSystemSnapshot` to restore pre-remediation state
- Document manual restore procedure and restore point naming scheme

---

### No Remediation Dry-Run Mode

**Problem:** Operators cannot preview what remediation will change without executing it live on the target. This increases risk of unexpected changes.

**Blocks:** Safe remediation testing and change management approval workflows.

**Suggested solution:**
- Add `remediate_check_mode: false` variable to remediate role
- In check mode, parse scan results and generate a report of what WOULD be changed without actually modifying the target
- Integrate with AAP workflow approval gates so operators can review the dry-run before applying

---

### Limited Audit Logging of Remediation Changes

**Problem:** Remediation tasks execute but do not produce a detailed audit log of what was changed on each target. Operators must rely on job output logs, which may be truncated or hard to parse.

**Blocks:** Compliance audit trails and forensic analysis of configuration changes.

**Suggested solution:**
- Add task to capture pre-remediation and post-remediation registry states (via PowerShell `Compare-Object`)
- Store detailed change logs in ConfigMaps or external logging system
- Generate audit report showing before/after values for each modified setting

---

## Test Coverage Gaps

### No Unit Tests for Compliance Filter Plugin

**Untested area:** XCCDF parsing and severity/category mapping logic

**Files:**
- `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/plugins/filter/compliance_filters.py`

**Risk:** Filter logic (parse_xccdf, calculate_score, categorize_findings) is only verified through live SCC scans. No isolated unit tests exist for:
- Parsing XCCDF 1.1 vs 1.2 namespaces
- Severity extraction from attributes vs rule ID patterns
- Score calculation with different status distributions (all pass, mixed, all fail)
- Category grouping edge cases

**Priority:** High — Parser errors cause entire compliance workflow to fail silently or produce incorrect reports.

**Suggested tests:**
- Create `tests/unit/` directory with pytest tests
- Generate sample XCCDF files for each namespace version
- Test each filter method with valid and invalid inputs
- Test category mapping against known-good STIG benchmark data

---

### No Integration Tests Against Real SCC Scanner Output

**Untested area:** XCCDF parsing against actual DISA SCC output

**Files:**
- `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/plugins/filter/compliance_filters.py`
- All scan and remediate roles

**Risk:** Collection is only tested against the specific SCC version used in development. Updates to SCC or STIG XCCDF format may break parsing silently.

**Priority:** High — Collection's core value is DISA SCC integration; format changes break that integration without warning.

**Suggested tests:**
- Add test data: store sample XCCDF output from multiple SCC versions
- Add integration test that parses each sample XCCDF and verifies expected control counts, severity distribution, and score calculation
- Run integration tests in CI pipeline to catch SCC format changes early

---

### Limited Test Coverage for Remediation Mode Logic

**Untested area:** Mode detection and role dispatch in remediate role

**Files:**
- `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/roles/remediate/tasks/main.yml`

**Risk:** Complex logic determines which remediation path to execute (external role vs local, Win2019 vs Win2022, scan-driven vs category-based). This routing has multiple code paths that are not fully exercised:
1. Windows 2019 with `use_external_stig_role: false` (exists)
2. Windows 2022 with `use_external_stig_role: false` (missing task file — latent bug)
3. Both with EDA integration enabled/disabled (not tested)

**Priority:** Medium — Routing bugs cause selective failures on specific OS/mode combinations.

---

*Concerns audit: 2026-03-13*
