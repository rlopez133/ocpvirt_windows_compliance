# ocpvirt_windows_compliance Collection Cleanup

## What This Is

A cleanup and refactoring pass on the `ansible_tmm.ocpvirt_windows_compliance` Ansible collection. The collection automates DISA STIG compliance scanning, remediation, and reporting for Windows VMs running on OpenShift Virtualization. It works correctly — this is not a rewrite. The goal is to remove noise, reduce duplication, and harden the structure so it is maintainable and regression-safe going forward.

## Core Value

Every change must leave the collection functionally identical to before — no task execution changes, no variable renames visible to callers, no broken runs. Clean code only, verified by lint and validation before and after each phase.

## Requirements

### Validated

- ✓ DISA STIG compliance scanning for Windows VMs on OpenShift Virtualization — existing
- ✓ STIG remediation (scan-driven and external role modes) for Windows 2019 and 2022 — existing
- ✓ Compliance reporting with XCCDF result parsing — existing
- ✓ AAP bootstrap automation for job templates, credentials, and inventories — existing
- ✓ SCC tool installation and STIG content deployment — existing

### Active

- [ ] Remove dead/commented-out variables from all defaults files
- [ ] Remove commented-out task block in bootstrap_aap.yml
- [ ] Fix stale inventory_sync_result reference in bootstrap_aap.yml summary
- [ ] Gate debug discovery tasks in scan/tasks/execute.yml behind verbosity flag
- [ ] Trim verbose assert fail_msg blocks in bootstrap_aap.yml
- [ ] Extract remediation summary display into the remediate role
- [ ] Break up roles/remediate/tasks/main.yml into focused task files
- [ ] Fix playbook_dir path references in remediate/tasks/main.yml (use include_role)
- [ ] Evaluate AAP survey fields against post-cleanup variable usage

### Out of Scope

- Variable renames — anything visible to AAP job templates or survey variables keeps its current name
- Changes to PowerShell scripts embedded in win_shell/win_powershell tasks
- Changes to win2019_stig or win2022_stig role task logic — only the remediate role's dispatch mechanism
- Changes to bootstrap_aap.yml structure beyond the listed items
- Changes to playbooks/scan.yml, playbooks/report.yml, playbooks/setup.yml, or playbooks/install_scc.yml
- Creating the missing win2022_stig/tasks/scan_driven_remediation.yml — flagged as known issue only

## Context

- Collection lives at `collections/ansible_collections/ansible_tmm/ocpvirt_windows_compliance/`
- Base branch for all work: `refactor_cleanup` (do not touch `main` or `010-e2e-testing-fixes`)
- Each phase gets its own git branch off `refactor_cleanup`
- Codebase map exists at `.planning/codebase/`
- AAP job execution requires human involvement — no autonomous job launches
- `/ansible-cop-review` must be run after each phase before committing
- `ansible-lint` must pass with zero new warnings after every phase
- Latent bug: `win2022_stig/tasks/scan_driven_remediation.yml` is referenced by the remediate role but does not exist — flag only, do not fix in this pass

## Constraints

- **Regression safety**: Every phase validated before merging — syntax check for zero-risk phases, AAP validation for execution phases
- **Tech stack**: Ansible collection, YAML, Jinja2, PowerShell in win_shell — no Python, no new dependencies
- **Branch discipline**: Each phase gets its own branch off `refactor_cleanup`, no remote pushes by Claude
- **Validation**: `/ansible-cop-review` + `ansible-lint` must pass after every phase

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| One phase per change (8 phases total) | Finer control over each cleanup item | — Pending |
| AAP survey evaluation as formal phase | Ensures it gets tracked and completed | — Pending |
| Flag win2022 missing file, don't fix | Separate effort, not part of this cleanup | — Pending |
| Each phase gets /ansible-cop-review | Ensures CoP compliance throughout | — Pending |

---
*Last updated: 2026-03-13 after initialization*
