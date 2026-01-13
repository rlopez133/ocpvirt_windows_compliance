#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Filter plugins for Windows VM compliance management.

This module provides Jinja2 filters for parsing XCCDF scan results
and calculating compliance scores.
"""

from __future__ import absolute_import, division, print_function

__metaclass__ = type

import xml.etree.ElementTree as ET
from typing import Any, Dict, List, Optional

DOCUMENTATION = r"""
---
name: compliance_filters
author: Roger Lopez
version_added: "1.0.0"
short_description: Filters for parsing compliance scan results
description:
  - Provides filters for parsing XCCDF result files from DISA SCC.
  - Calculates compliance scores by category (CAT1, CAT2, CAT3).
  - Supports SCAP 1.2 and 1.3 XCCDF result formats.
"""


class FilterModule:
    """Ansible filter plugin class."""

    def filters(self) -> Dict[str, Any]:
        """Return filter functions."""
        return {
            "parse_xccdf": self.parse_xccdf,
            "calculate_score": self.calculate_score,
            "filter_findings": self.filter_findings,
            "categorize_findings": self.categorize_findings,
        }

    def parse_xccdf(self, content: str) -> Dict[str, Any]:
        """Parse XCCDF result XML content.

        Args:
            content: XCCDF result XML as string

        Returns:
            Dictionary containing parsed results with controls and status
        """
        namespaces = {
            "xccdf": "http://checklists.nist.gov/xccdf/1.2",
            "xccdf11": "http://checklists.nist.gov/xccdf/1.1",
        }

        try:
            root = ET.fromstring(content)
        except ET.ParseError as e:
            return {"error": f"Failed to parse XML: {str(e)}", "controls": []}

        # Detect namespace version
        ns = "xccdf"
        if root.tag.startswith("{http://checklists.nist.gov/xccdf/1.1}"):
            ns = "xccdf11"

        controls = []
        test_results = root.findall(f".//{{{namespaces[ns]}}}rule-result")

        for result in test_results:
            rule_id = result.get("idref", "")
            result_elem = result.find(f"{{{namespaces[ns]}}}result")
            status = result_elem.text if result_elem is not None else "unknown"

            # Extract severity from rule metadata
            severity = self._extract_severity(result, namespaces[ns])

            controls.append({
                "control_id": rule_id,
                "status": status,
                "severity": severity,
                "category": self._severity_to_category(severity),
            })

        return {
            "controls": controls,
            "total": len(controls),
            "parsed": True,
        }

    def calculate_score(
        self,
        parsed_results: Dict[str, Any],
        thresholds: Optional[Dict[str, int]] = None,
    ) -> Dict[str, Any]:
        """Calculate compliance score from parsed XCCDF results.

        Args:
            parsed_results: Output from parse_xccdf filter
            thresholds: Optional dict with critical/warning/info thresholds

        Returns:
            Dictionary with overall and per-category scores
        """
        if thresholds is None:
            thresholds = {"critical": 100, "warning": 95, "info": 80}

        controls = parsed_results.get("controls", [])
        if not controls:
            return {
                "total": 0,
                "passed": 0,
                "failed": 0,
                "not_applicable": 0,
                "not_checked": 0,
                "score": 0.0,
                "status": "error",
                "category_scores": {},
            }

        # Count by status
        passed = sum(1 for c in controls if c["status"] == "pass")
        failed = sum(1 for c in controls if c["status"] == "fail")
        not_applicable = sum(1 for c in controls if c["status"] == "notapplicable")
        not_checked = sum(1 for c in controls if c["status"] in ("notchecked", "notselected"))

        # Calculate applicable controls (exclude N/A and not checked)
        applicable = passed + failed
        score = (passed / applicable * 100) if applicable > 0 else 0.0

        # Calculate per-category scores
        category_scores = {}
        for cat in ["CAT1", "CAT2", "CAT3"]:
            cat_controls = [c for c in controls if c.get("category") == cat]
            cat_passed = sum(1 for c in cat_controls if c["status"] == "pass")
            cat_failed = sum(1 for c in cat_controls if c["status"] == "fail")
            cat_applicable = cat_passed + cat_failed

            category_scores[cat.lower()] = {
                "score": (cat_passed / cat_applicable * 100) if cat_applicable > 0 else 100.0,
                "passed": cat_passed,
                "failed": cat_failed,
                "total": len(cat_controls),
            }

        # Determine status based on CAT1 and thresholds
        cat1_score = category_scores.get("cat1", {}).get("score", 100)
        if cat1_score < 100:
            status = "critical"
        elif score < thresholds.get("warning", 95):
            status = "warning"
        elif score < thresholds.get("info", 80):
            status = "info"
        else:
            status = "compliant"

        return {
            "total": len(controls),
            "passed": passed,
            "failed": failed,
            "not_applicable": not_applicable,
            "not_checked": not_checked,
            "score": round(score, 2),
            "status": status,
            "category_scores": category_scores,
        }

    def filter_findings(
        self,
        parsed_results: Dict[str, Any],
        status: str = "fail",
        max_results: int = 50,
    ) -> List[Dict[str, Any]]:
        """Filter findings by status.

        Args:
            parsed_results: Output from parse_xccdf filter
            status: Status to filter by (default: fail)
            max_results: Maximum number of results to return

        Returns:
            List of findings matching the status filter
        """
        controls = parsed_results.get("controls", [])
        filtered = [c for c in controls if c["status"] == status]
        return filtered[:max_results]

    def categorize_findings(
        self,
        parsed_results: Dict[str, Any],
    ) -> Dict[str, List[Dict[str, Any]]]:
        """Group findings by category.

        Args:
            parsed_results: Output from parse_xccdf filter

        Returns:
            Dictionary with CAT1, CAT2, CAT3 findings lists
        """
        controls = parsed_results.get("controls", [])
        return {
            "cat1": [c for c in controls if c.get("category") == "CAT1"],
            "cat2": [c for c in controls if c.get("category") == "CAT2"],
            "cat3": [c for c in controls if c.get("category") == "CAT3"],
        }

    def _extract_severity(self, result_elem: ET.Element, ns: str) -> str:
        """Extract severity from rule result metadata."""
        # Try to get severity from ident or metadata
        severity_map = {
            "high": "high",
            "medium": "medium",
            "low": "low",
            "critical": "high",
            "i": "high",
            "ii": "medium",
            "iii": "low",
        }

        # Check for severity attribute
        severity = result_elem.get("severity", "").lower()
        if severity in severity_map:
            return severity_map[severity]

        # Default based on rule ID pattern (STIG convention)
        rule_id = result_elem.get("idref", "")
        if "_CAT1_" in rule_id or "-CC-" in rule_id:
            return "high"
        elif "_CAT2_" in rule_id:
            return "medium"
        elif "_CAT3_" in rule_id:
            return "low"

        return "medium"  # Default to medium

    def _severity_to_category(self, severity: str) -> str:
        """Convert severity to STIG category."""
        severity_map = {
            "high": "CAT1",
            "medium": "CAT2",
            "low": "CAT3",
        }
        return severity_map.get(severity, "CAT2")
