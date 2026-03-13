# Coding Conventions

**Analysis Date:** 2026-03-13

## Naming Patterns

**Files:**
- Ansible task files: lowercase with underscores (`main.yml`, `preflight.yml`, `execute.yml`, `collect.yml`, `store.yml`, `metrics.yml`)
- Ansible role names: lowercase with underscores (`setup`, `scan`, `win2022_stig`, `win2019_stig`)
- Python filter plugins: descriptive lowercase with underscores (`compliance_filters.py`)
- Default/vars files: `defaults/main.yml`, `vars/main.yml` in standard Ansible structure
- Playbook files: descriptive names (`setup.yml`, `remediate.yml`, `report.yml`, `scan.yml`)

**Variables:**
- Ansible variables: snake_case (e.g., `scc_install_path`, `scan_timeout`, `tenant_config`, `eda_enabled`)
- Configuration dictionaries use nested structure: `tenant_config.name`, `tenant_config.namespace`, `tenant_config.storage`
- Default variables defined in `roles/*/defaults/main.yml` with clear hierarchical structure
- Boolean flags follow pattern: `{feature}_enabled` (e.g., `eda_enabled`, `pushgateway_enabled`)
- URL variables: `{service}_{resource}_url` (e.g., `eda_project_url`, `scc_installer_url`)
- Thresholds use pattern: `compliance_threshold_{level}` (e.g., `compliance_threshold_critical`, `compliance_threshold_warning`)

**Functions/Tasks:**
- Ansible tasks: imperative naming using module name + action (e.g., "Validate required variables", "Create tenant namespace if it does not exist", "Execute SCC scan")
- Task names are descriptive multi-word phrases, not code-like
- Python function names: snake_case (e.g., `parse_xccdf`, `calculate_score`, `filter_findings`, `categorize_findings`, `_extract_severity`)
- Private/helper functions: prefixed with underscore (e.g., `_extract_severity`, `_severity_to_category`)

**Types:**
- Python return types use Dict, List, Optional, Any from typing module
- Filter plugin class follows Ansible convention: `FilterModule` class with `filters()` method
- XCCDF namespaces use full URIs with version: `http://checklists.nist.gov/xccdf/1.2`, `http://checklists.nist.gov/xccdf/1.1`

## Code Style

**Formatting:**
- Ansible YAML: 2-space indentation (standard Ansible)
- Python: PEP 8 compliant (confirmed in `compliance_filters.py`)
- YAML files start with `---` separator
- Task descriptions: comprehensive multi-line strings with context

**Linting:**
- No specific linting tools configured (no `.eslintrc`, `.pylintrc`, `pyproject.toml` found)
- Project uses `ansible.cfg` in root with output callbacks configured (stdout_callback = yaml, timer, profile_tasks)
- Per CLAUDE.md instructions: `ruff check .` should be run for Python code validation

**Comments and Documentation:**
- File headers: Include file purpose and responsibility (e.g., "Setup Role - Main Task Dispatcher")
- Task order documented: Comments explain execution sequence (e.g., "EDA-first pattern" in setup/main.yml)
- Inline comments precede task blocks explaining why, not what
- Python docstrings: Module-level docstrings with triple quotes, function docstrings with Args/Returns sections

## Ansible Task Structure

**Task Headers:**
- Header includes file name and purpose on first line
- Task order documented in comments for complex roles
- Dependencies noted (e.g., "EDA must be configured FIRST to get the event stream webhook URL")

**Task Patterns:**
```yaml
- name: Descriptive task name with action
  module_name:
    key: value
  when: condition | default(true)
  register: variable_name
  async: timeout_seconds
  poll: poll_interval
```

**Include Tasks Pattern:**
- Complex roles split into subtasks with conditional includes
- Main task dispatcher pattern: `tasks/main.yml` includes other task files
- Format: `ansible.builtin.include_tasks: {filename}.yml` with optional `when` conditions

**Variable Passing:**
- Variables defined in `defaults/main.yml` for all role defaults
- Variables can be overridden at playbook/job template level
- Defaults use pattern: `variable | default(value)` for safe evaluation
- Complex structures use nested dictionaries with meaningful keys

## Error Handling

**Patterns:**
- Ansible assertions for validation: `ansible.builtin.assert` with `that` list and `fail_msg`
- Python try/except for XML parsing: Returns error dict with "error" key on failure
- Empty check pattern: `if not controls:` returns sensible defaults (zero scores, empty lists)
- WinRM module error handling: Uses `ignore_errors: true` for optional checks, `when: condition` for conditionals
- Shell command error handling: Check exit codes and output via `{{ result.rc }}`, `{{ result.stdout }}`, `{{ result.stderr }}`

**Failure Messages:**
- Descriptive fail messages with context (e.g., includes searched paths, installation instructions)
- Debug messages display configuration state before execution
- Summary messages display results at end of role execution

## Logging

**Framework:** `ansible.builtin.debug` module with structured messages

**Patterns:**
- Configuration display before major operations: Multi-line debug with formatted output
- Scan summary at completion: Shows score, status, control counts, category failures
- Directory search results logged to files: `Out-File` for PowerShell output capture
- Task-level output captured in `register` variables for structured access

**Ansible Callback Configuration (ansible.cfg):**
- `stdout_callback = yaml` - YAML-formatted output for readability
- `callback_whitelist = timer, profile_tasks` - Performance profiling
- `display_skipped_hosts = false` - Reduce output noise
- `display_ok_hosts = true` - Show successful tasks
- `retry_files_enabled = false` - No retry files

## Module Organization

**Role Structure:**
```
roles/{role_name}/
├── defaults/main.yml      # Default variables
├── meta/main.yml          # Role metadata and dependencies
├── tasks/main.yml         # Task dispatcher
├── tasks/subtask.yml      # Included subtasks
└── README.md              # Role documentation
```

**Imports vs Includes:**
- Use `ansible.builtin.include_tasks` for conditional task inclusion (e.g., feature toggles)
- Use full module path in task definitions (e.g., `ansible.builtin.assert`, `ansible.windows.win_shell`)

**Exports/Barrel Pattern:**
- Filter plugins registered in `FilterModule.filters()` method returning dict of function names to callables
- All filter functions exposed: No private filters (accessible from Ansible templates)
- Python `__init__.py` files empty (standard Ansible plugin structure)

## Python Conventions

**File Header:**
```python
#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Module docstring describing purpose."""

from __future__ import absolute_import, division, print_function

__metaclass__ = type
```

**Documentation:**
- Module-level DOCUMENTATION dict with YAML format (Ansible standard)
- Function docstrings with Args and Returns sections (Google-style)
- Type hints in function signatures: `Dict[str, Any]`, `List[Dict]`, `Optional[Dict]`

**Data Structures:**
- Return dictionaries with consistent keys across functions
- XML parsing uses namespace maps: `{"xccdf": "...", "xccdf11": "..."}`
- Status values: lowercase strings ("pass", "fail", "notapplicable", "notchecked", "notselected")
- Categories: uppercase "CAT1", "CAT2", "CAT3"
- Severity levels: lowercase "high", "medium", "low"

---

*Convention analysis: 2026-03-13*
