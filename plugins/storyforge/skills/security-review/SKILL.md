---
name: security-review
description: "Security audit of code added or changed on a branch: auth and authorization bypass, IDOR, injection (SQL, command, template, path, SSRF), secrets in code or logs, crypto misuse, XSS escape hatches, unsafe deserialization, webhook signature checks, and feature-flag leaks. Use for 'security review', 'security audit', 'is this safe', 'check for vulnerabilities', or the security phase of build-story."
---

# Security review

Two lenses run in order. Both are reused from the reference packs; see NOTICE.md.

1. **Checklist lens.** Read `references/security.md` (from gstack's security specialist) and check every category against the diff. Trace each input from where it enters to where it's used.
2. **Thermonuclear lens.** Apply the `thermo-nuclear-review` skill (from pstack) to the same diff. It covers breaking functionality, devex breakage, and feature-gate leaks, and its over-reporting rules apply to everything you report.

Plus three checks that matter in agent-written code:
- **New dependencies.** Is each one necessary, maintained, and pinned in the lockfile? Does it have install scripts?
- **New config and env vars.** Are there secret defaults, debug flags left on, or permissive CORS?
- **Logging.** Make sure no tokens, passwords, or personal data reach logs or error responses.

Rules:
- Only report issues in added or modified code.
- Never print a secret's value. Point to `file:line`. Recommend rotation for anything that was committed.
- Don't call live provider APIs to test keys. Don't run exploits against shared or production systems.
- Each finding gets a severity, `file:line`, a one-line exploit path, a fix, and a confidence score.
