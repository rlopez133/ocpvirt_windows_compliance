# Roadmap: ocpvirt_windows_compliance Collection Cleanup

## Overview

Eight sequential cleanup phases, ordered from zero-risk deletions through medium-risk structural changes to a high-risk path reference fix, ending with an evaluation-only survey audit. Each phase is independently validated with `/ansible-cop-review` and `ansible-lint` before committing. The collection must remain functionally identical after every phase.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Dead Variable Removal** - Remove commented-out unused variables from scan and remediate defaults files
- [ ] **Phase 2: Bootstrap Cleanup** - Remove commented-out task block and fix stale reference in bootstrap_aap.yml
- [ ] **Phase 3: Debug Task Gating** - Gate verbose debug discovery tasks behind a configurable flag
- [ ] **Phase 4: Assert Message Trim** - Trim verbose assert fail_msg blocks to terse one-liners
- [ ] **Phase 5: Summary Extraction** - Move remediation summary display from playbook post_tasks into the remediate role
- [ ] **Phase 6: Task File Splitting** - Break remediate role main.yml into focused, includable task files
- [ ] **Phase 7: Path Reference Fix** - Replace fragile playbook_dir path references with include_role calls
- [ ] **Phase 8: AAP Survey Evaluation** - Audit AAP survey fields against post-cleanup variable usage

## Phase Details

### Phase 1: Dead Variable Removal
**Goal**: Defaults files contain only variables that are actually used by the collection
**Depends on**: Nothing (first phase)
**Risk**: Zero -- pure deletion of commented-out lines
**Requirements**: DEAD-01, DEAD-02
**Success Criteria** (what must be TRUE):
  1. `roles/scan/defaults/main.yml` contains no commented-out variable definitions
  2. `roles/remediate/defaults/main.yml` contains no commented-out variable definitions
  3. `ansible-lint` passes with zero new warnings
**Plans**: 1 plan

Plans:
- [ ] 01-01-PLAN.md -- Remove commented-out variables from scan and remediate defaults files

### Phase 2: Bootstrap Cleanup
**Goal**: bootstrap_aap.yml contains no dead code and its summary references only valid state
**Depends on**: Phase 1
**Risk**: Zero -- removal of commented block and replacement of one variable reference with a static string
**Requirements**: DEAD-03, DEAD-04
**Success Criteria** (what must be TRUE):
  1. The commented-out `inventory_source_update` task block no longer exists in `playbooks/bootstrap_aap.yml`
  2. The bootstrap summary displays "Skipped (run manually)" instead of referencing `inventory_sync_result`
  3. `ansible-lint` passes with zero new warnings
**Plans**: TBD

Plans:
- [ ] 02-01: TBD

### Phase 3: Debug Task Gating
**Goal**: Debug discovery output in scan role is suppressed by default and only shown when explicitly enabled
**Depends on**: Phase 2
**Risk**: Zero -- adds a default-false flag and `when` conditions to debug tasks only
**Requirements**: DBUG-01, DBUG-02
**Success Criteria** (what must be TRUE):
  1. `roles/scan/defaults/main.yml` defines `scan_verbose_output: false`
  2. The four debug discovery tasks in `roles/scan/tasks/execute.yml` each have a `when: scan_verbose_output` condition
  3. Running a scan with defaults produces no debug discovery output
  4. Setting `scan_verbose_output: true` restores the debug output
**Plans**: TBD

Plans:
- [ ] 03-01: TBD

### Phase 4: Assert Message Trim
**Goal**: Assert failure messages in bootstrap_aap.yml are concise and scannable
**Depends on**: Phase 3
**Risk**: Zero -- cosmetic change to error message text only
**Requirements**: ASRT-01, ASRT-02
**Success Criteria** (what must be TRUE):
  1. The first assert task's `fail_msg` in `bootstrap_aap.yml` is a single terse line
  2. The second assert task's `fail_msg` in `bootstrap_aap.yml` is a single terse line
  3. Assert logic (conditions checked) is unchanged
**Plans**: TBD

Plans:
- [ ] 04-01: TBD

### Phase 5: Summary Extraction
**Goal**: Remediation summary display logic lives in the remediate role, not in playbook post_tasks
**Depends on**: Phase 4
**Risk**: Medium -- moves task execution from playbook to role scope; variable availability must be verified
**Requirements**: SUMM-01, SUMM-02, SUMM-03
**Success Criteria** (what must be TRUE):
  1. `roles/remediate/tasks/display_summary.yml` exists and contains the set_fact and debug blocks previously in post_tasks
  2. `roles/remediate/tasks/main.yml` includes `display_summary.yml` as its final include
  3. `playbooks/remediate.yml` has no `post_tasks` block
  4. Remediation run produces identical summary output as before the change
**Plans**: TBD

Plans:
- [ ] 05-01: TBD

### Phase 6: Task File Splitting
**Goal**: Remediate role main.yml is a short orchestrator that includes focused, single-purpose task files
**Depends on**: Phase 5
**Risk**: Medium -- restructures task execution order within the role; must preserve exact task sequence
**Requirements**: SPLIT-01, SPLIT-02, SPLIT-03, SPLIT-04, SPLIT-05
**Success Criteria** (what must be TRUE):
  1. Four new task files exist: `determine_mode.yml`, `detect_os.yml`, `apply_remediation.yml`, `push_metrics.yml`
  2. `roles/remediate/tasks/main.yml` is a short file that includes the above files (plus `display_summary.yml` from Phase 5) in the correct order
  3. No task logic was changed -- only moved between files
  4. The task execution sequence is identical to pre-split behavior
**Plans**: TBD

Plans:
- [ ] 06-01: TBD

### Phase 7: Path Reference Fix
**Goal**: Remediate role uses proper Ansible role inclusion instead of fragile playbook_dir-relative paths
**Depends on**: Phase 6
**Risk**: High -- changes how roles are included at runtime; AAP validation required
**Requirements**: PATH-01, PATH-02, PATH-03
**Success Criteria** (what must be TRUE):
  1. Zero `playbook_dir/../roles/` references remain in remediate role task files
  2. All 8 former `include_tasks` with playbook_dir paths are replaced with `include_role` calls
  3. `include_vars` for win_stig_wrapper defaults uses `role_path` or is folded into the wrapper role
  4. Missing `win2022_stig/tasks/scan_driven_remediation.yml` is documented as a known issue (not created)
  5. AAP job execution produces identical results (validated by human)
**Plans**: TBD

Plans:
- [ ] 07-01: TBD

### Phase 8: AAP Survey Evaluation
**Goal**: Clear picture of which AAP survey fields are still relevant after cleanup, with actionable recommendations
**Depends on**: Phase 7
**Risk**: Evaluation only -- no code changes
**Requirements**: SURV-01, SURV-02, SURV-03, SURV-04
**Success Criteria** (what must be TRUE):
  1. All job templates with surveys are identified and listed
  2. Every survey field is mapped to its corresponding collection variable
  3. Any survey fields referencing removed or changed variables are flagged
  4. A findings document with simplification recommendations exists
**Plans**: TBD

Plans:
- [ ] 08-01: TBD

### Cross-Phase: Validation
**Note**: VALID-01 and VALID-02 apply to every phase, not as a separate phase.
- `/ansible-cop-review` runs after each phase; all ERRORs resolved before proceeding
- `ansible-lint` runs after each phase; zero new warnings confirmed

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Dead Variable Removal | 0/1 | Not started | - |
| 2. Bootstrap Cleanup | 0/? | Not started | - |
| 3. Debug Task Gating | 0/? | Not started | - |
| 4. Assert Message Trim | 0/? | Not started | - |
| 5. Summary Extraction | 0/? | Not started | - |
| 6. Task File Splitting | 0/? | Not started | - |
| 7. Path Reference Fix | 0/? | Not started | - |
| 8. AAP Survey Evaluation | 0/? | Not started | - |
