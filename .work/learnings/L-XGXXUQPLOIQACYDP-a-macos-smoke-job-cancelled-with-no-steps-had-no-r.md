---
date: 2026-11-24
read_if:
  - a ci or release run is red or cancelled on macos-arm64
  - deciding whether to rerun a failed job
refs:
  - .github/workflows/ci.yml
---

# L-XGXXUQPLOIQACYDP A macOS smoke job cancelled with no steps had no runner, not a failure

## Observation
A `smoke macos-arm64` job is sometimes cancelled at its 15 minute limit with no step started and no log: GitHub had no macOS ARM runner to give. It happened on three runs on 2026-11-24 (45384678750, 45435023130, 45441094061). The job's check-run annotations say so (`gh api repos/<owner>/<repo>/check-runs/<job-id>/annotations`), and `gh run rerun <id> --failed` passed each time.

## Why it matters
It looks like a red run on macOS and is not one. Nothing in the code is to be changed for it; a job that started steps and then failed is a different thing and is to be diagnosed.
