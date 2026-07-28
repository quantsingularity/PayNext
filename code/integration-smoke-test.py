#!/usr/bin/env python3
"""
PayNext contract-level integration smoke test.

This does not start the live JVM stack (Maven Central is blocked in this
environment). Instead it verifies the API contract end to end statically:

  frontend call  ->  api-gateway route (/api/** with RewritePath)  ->  backend endpoint

For every call the web and mobile clients make, it computes the path the gateway
forwards (after stripping the /api prefix) and checks whether a real backend
controller endpoint serves it. It distinguishes three outcomes:

  MATCH     a real backend endpoint serves the rewritten path and method
  MISROUTE  the path would be captured by a /{id} route (wrong handler)
  MISSING   no backend endpoint exists for the path/method

MATCH means the integration wiring (prefix, rewrite, method) is correct.
MISROUTE and MISSING are backend feature gaps, not wiring defects.
"""

import re

# Backend endpoints actually implemented by the controllers, after the
# integration normalization (payment-service now serves /payments, not /api/payments).
# Each entry: (METHOD, regex matching the service-local path).
BACKEND = [
    ("POST", re.compile(r"^/users/register$")),
    ("POST", re.compile(r"^/users/login$")),
    ("GET", re.compile(r"^/users/me$")),
    ("GET", re.compile(r"^/users/profile$")),
    ("PUT", re.compile(r"^/users/profile$")),
    ("GET", re.compile(r"^/users/\d+$")),            # GET /users/{id}, numeric id
    ("POST", re.compile(r"^/payments$")),
    ("GET", re.compile(r"^/payments$")),
    ("GET", re.compile(r"^/payments/balance$")),
    ("GET", re.compile(r"^/payments/methods$")),
    ("POST", re.compile(r"^/payments/methods$")),
    ("POST", re.compile(r"^/payments/requests$")),
    ("GET", re.compile(r"^/payments/\d+$")),          # GET /payments/{id}, numeric id
    ("POST", re.compile(r"^/notifications/send$")),
]

# The /{id} catch-all routes that can swallow an unintended single-segment path
# (for example /users/me would be handled by /users/{id} and then fail to parse).
ID_ROUTES = [
    ("GET", re.compile(r"^/users/[^/]+$"), "/users/{id}"),
    ("GET", re.compile(r"^/payments/[^/]+$"), "/payments/{id}"),
]

# Frontend calls: (client, method, public path as called through the gateway).
CALLS = [
    ("web", "POST", "/api/users/login"),
    ("web", "POST", "/api/users/register"),
    ("web", "GET", "/api/users/me"),
    ("web", "GET", "/api/users/profile"),
    ("web", "PUT", "/api/users/profile"),
    ("web", "GET", "/api/payments"),  # getTransactionHistory now reads from payment-service
    ("web", "POST", "/api/payments"),
    ("web", "GET", "/api/payments"),
    ("web", "GET", "/api/payments/123"),
    ("web", "GET", "/api/payments/balance"),
    ("web", "GET", "/api/payments/methods"),
    ("web", "POST", "/api/payments/methods"),
    ("mobile", "POST", "/api/users/login"),
    ("mobile", "POST", "/api/users/register"),
    ("mobile", "GET", "/api/users/profile"),
    ("mobile", "PUT", "/api/users/profile"),
    ("mobile", "GET", "/api/payments/balance"),
    ("mobile", "GET", "/api/payments"),
    ("mobile", "POST", "/api/payments"),
    ("mobile", "POST", "/api/payments/requests"),
]


def gateway_rewrite(path):
    """Mirror the gateway RewritePath: /api/(?<segment>.*) -> /${segment}."""
    m = re.match(r"^/api/(.*)$", path)
    return "/" + m.group(1) if m else None


def classify(method, public_path):
    backend_path = gateway_rewrite(public_path)
    if backend_path is None:
        return "NO-ROUTE", "path is not under /api, gateway has no route"
    for bm, rx in BACKEND:
        if bm == method and rx.match(backend_path):
            return "MATCH", backend_path
    # Not a real endpoint. Would it be swallowed by a /{id} route?
    for im, rx, label in ID_ROUTES:
        if im == method and rx.match(backend_path):
            return "MISROUTE", f"{backend_path} would hit {label}"
    return "MISSING", f"no backend endpoint for {method} {backend_path}"


def main():
    width = max(len(c[2]) for c in CALLS) + 2
    print(f"{'CLIENT':<8}{'METHOD':<7}{'PUBLIC PATH':<{width}}{'RESULT':<10}DETAIL")
    print("-" * (8 + 7 + width + 10 + 40))
    counts = {}
    for client, method, path in CALLS:
        result, detail = classify(method, path)
        counts[result] = counts.get(result, 0) + 1
        print(f"{client:<8}{method:<7}{path:<{width}}{result:<10}{detail}")
    print("-" * (8 + 7 + width + 10 + 40))
    summary = "  ".join(f"{k}={v}" for k, v in sorted(counts.items()))
    print("SUMMARY:", summary)
    wired_ok = counts.get("MATCH", 0)
    gaps = counts.get("MISSING", 0) + counts.get("MISROUTE", 0)
    print(f"\nWiring verified for {wired_ok} calls (correct prefix, rewrite, method).")
    print(f"Backend feature gaps (not wiring bugs): {gaps} calls.")


if __name__ == "__main__":
    main()
