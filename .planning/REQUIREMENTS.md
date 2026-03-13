# Requirements: ocpvirt_windows_compliance Collection Cleanup

**Defined:** 2026-03-13
**Core Value:** Every change must leave the collection functionally identical — no task execution changes, no variable renames visible to callers, no broken runs.

## v1 Requirements

### Dead Code Removal

- [x] **DEAD-01**: Remove commented-out unused variables from `roles/scan/defaults/main.yml` (`target_vms`, `metrics_retention_days`, `scan_thresholds`)
- [x] **DEAD-02**: Remove commented-out unused variables from `roles/remediate/defaults/main.yml` (`target_vms`, `allow_reboot`, `backup_before_change`, `max_retries`, `retry_delay`, `continue_on_error`)
- [ ] **DEAD-03**: Remove commented-out `inventory_source_update` task block from `playbooks/bootstrap_aap.yml`
- [ ] **DEAD-04**: Change `inventory_sync_result` reference in bootstrap summary to static "Skipped (run manually)" string

### Debug Gating

- [ ] **DBUG-01**: Add `scan_verbose_output: false` default to `roles/scan/defaults/main.yml`
- [ ] **DBUG-02**: Gate four debug discovery tasks in `roles/scan/tasks/execute.yml` behind `scan_verbose_output` flag

### Assertion Cleanup

- [ ] **ASRT-01**: Trim verbose `fail_msg` in first assert task of `bootstrap_aap.yml` to one terse line
- [ ] **ASRT-02**: Trim verbose `fail_msg` in second assert task of `bootstrap_aap.yml` to one terse line

### Summary Extraction

- [ ] **SUMM-01**: Create `roles/remediate/tasks/display_summary.yml` with set_fact and debug blocks from playbook post_tasks
- [ ] **SUMM-02**: Include `display_summary.yml` at end of `roles/remediate/tasks/main.yml`
- [ ] **SUMM-03**: Remove entire `post_tasks` block from `playbooks/remediate.yml`

### Task File Splitting

- [ ] **SPLIT-01**: Extract `tasks/determine_mode.yml` from remediate role main.yml
- [ ] **SPLIT-02**: Extract `tasks/detect_os.yml` from remediate role main.yml
- [ ] **SPLIT-03**: Extract `tasks/apply_remediation.yml` from remediate role main.yml
- [ ] **SPLIT-04**: Extract `tasks/push_metrics.yml` from remediate role main.yml
- [ ] **SPLIT-05**: Reduce `tasks/main.yml` to short orchestrator including above files in order

### Path Reference Fix

- [ ] **PATH-01**: Replace all 8 `playbook_dir/../roles/` include_tasks with `include_role` calls
- [ ] **PATH-02**: Fix `include_vars` for win_stig_wrapper defaults to use `role_path` or fold into wrapper role
- [ ] **PATH-03**: Document missing `win2022_stig/tasks/scan_driven_remediation.yml` as known issue

### AAP Survey Evaluation

- [ ] **SURV-01**: Identify all job templates with surveys and their fields
- [ ] **SURV-02**: Map each survey field to its corresponding collection variable
- [ ] **SURV-03**: Flag survey fields referencing removed or changed variables
- [ ] **SURV-04**: Present findings with recommendations for simplification

### Cross-Phase Validation

- [ ] **VALID-01**: Run `/ansible-cop-review` after each phase and resolve all ERRORs
- [ ] **VALID-02**: Run `ansible-lint` after each phase and confirm zero new warnings

## v2 Requirements

None — this is a single cleanup milestone.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Variable renames | Visible to AAP job templates and survey variables |
| PowerShell script changes | Embedded in win_shell tasks, not part of cleanup |
| win2019_stig/win2022_stig task logic | Only remediate role dispatch mechanism changes |
| bootstrap_aap.yml structure changes | Beyond the two listed items |
| scan.yml, report.yml, setup.yml, install_scc.yml changes | Not in scope |
| Creating missing win2022_stig/scan_driven_remediation.yml | Flagged as known issue, separate effort |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DEAD-01 | Phase 1 | Complete |
| DEAD-02 | Phase 1 | Complete |
| DEAD-03 | Phase 2 | Pending |
| DEAD-04 | Phase 2 | Pending |
| DBUG-01 | Phase 3 | Pending |
| DBUG-02 | Phase 3 | Pending |
| ASRT-01 | Phase 4 | Pending |
| ASRT-02 | Phase 4 | Pending |
| SUMM-01 | Phase 5 | Pending |
| SUMM-02 | Phase 5 | Pending |
| SUMM-03 | Phase 5 | Pending |
| SPLIT-01 | Phase 6 | Pending |
| SPLIT-02 | Phase 6 | Pending |
| SPLIT-03 | Phase 6 | Pending |
| SPLIT-04 | Phase 6 | Pending |
| SPLIT-05 | Phase 6 | Pending |
| PATH-01 | Phase 7 | Pending |
| PATH-02 | Phase 7 | Pending |
| PATH-03 | Phase 7 | Pending |
| SURV-01 | Phase 8 | Pending |
| SURV-02 | Phase 8 | Pending |
| SURV-03 | Phase 8 | Pending |
| SURV-04 | Phase 8 | Pending |
| VALID-01 | All | Pending |
| VALID-02 | All | Pending |

**Coverage:**
- v1 requirements: 23 total (excluding cross-phase VALID-01/02)
- Mapped to phases: 23
- Unmapped: 0

---
*Requirements defined: 2026-03-13*
*Last updated: 2026-03-13 after initial definition*
