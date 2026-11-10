---
created: 2026-11-10
---

# B-7W2ZOVM433NUASIC Confirm the agents' push token holds neither Deployments: write nor Administration: write

## Why
The release key is guarded only by the owner's approval of the release deployment (D-S23WKXKSMWMABF53). A token that could approve deployments or edit environments would bypass that gate. GitHub's token page currently shows no permissions for the token, which looks like a display bug, so the owner's belief that it lacks both has not been checked against a source that works.

## Notes
Check when GitHub's token page shows permissions again, or by trying a harmless call that needs each permission and expecting 403.
