---
date: 2026-11-12
read_if:
  - testing a page in headless Chrome
  - removing a browser profile a test created
refs:
  - test/wasm/page.mjs#stopChrome
---

# L-SV42HXBZNKXPMDOM Chrome's helpers write its profile after the main process exits

## Observation
Headless Chrome's main process can exit while its helper processes (network service, zygote, crashpad) are still writing the --user-data-dir profile. Removing the profile on the main pid's exit failed in CI with ENOTEMPTY on `Default/`, after every page check had passed. It never showed in 30 local runs, so it depends on the machine's timing.

## Why it matters
A test that owns a browser profile cannot treat the browser's exit as the profile being quiet. Asking Chrome to close over the DevTools protocol lets it wind its helpers down, and waiting for its whole process group to be empty is what makes the removal safe. Retrying the removal would only hide a writer that is still running.
