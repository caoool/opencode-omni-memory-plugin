---
description: Audit native Markdown memory for scope, duplication, staleness, conflicts, and unsafe content.
---

Load the `markdown-memory` skill and audit the scope requested by `$ARGUMENTS` (`global`, `project`, or `all`; default to the current relevant scopes).

Check scope placement, duplication, provenance, last verification, contradictions, sensitive content, active injection size, stale handoff details, unreconciled session journals, and verified findings that should be promoted. Correct unambiguous issues conservatively and list anything requiring user judgment. Do not commit changes.
