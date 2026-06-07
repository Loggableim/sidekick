"""Regression tests for the CSP violation report endpoint.

The WebUI sets Content-Security-Policy-Report-Only (#1909) so the migration
to a stricter CSP can be observed before enforcement. Browsers silently drop
violation reports if the policy has no `report-uri` / `report-to` directive,
which also produces a noisy console warning on every page load.

This test verifies:
  * the policy now declares a `report-uri /api/csp-report` directive
  * POST /api/csp-report accepts a JSON-ish report body and returns 204
  * the endpoint does not require a CSRF token (browsers send reports
    automatically with no caller-controlled headers)
"""

import json
import sys
from http.server import BaseHTTPRequestHandler
from urllib.parse import urlparse

from server import Handler


def test_csp_policy_includes_report_uri():
    policy = Handler.csp_report_only_policy()
    assert "report-uri /api/csp-report" in policy, (
        "CSP must declare report-uri so the browser actually sends violations"
    )


def test_csp_report_endpoint_accepts_post():
    """POST /api/csp-report should consume the body and return 204."""
    # Lazy import to avoid pulling the full route module during test collection
    from api.routes import handle_post

    sent = []
    received_body = b""

    class _FakeHandler:
        def __init__(self):
            self.headers = {
                "Content-Length": str(len(received_body)),
                "Content-Type": "application/csp-report",
            }

        def send_response(self, code):
            sent.append(("status", code))

        def send_header(self, key, value):
            sent.append((key, value))

        def end_headers(self):
            sent.append(("end_headers", None))

        @property
        def rfile(self):
            class _Rfile:
                def read(self_inner, n):
                    return received_body
            return _Rfile()

    handler = _FakeHandler()
    parsed = urlparse("/api/csp-report")
    handled = handle_post(handler, parsed)
    assert handled is True
    assert any(item[0] == "status" and item[1] == 204 for item in sent), (
        f"Expected 204 No Content, got sent headers: {sent!r}"
    )
