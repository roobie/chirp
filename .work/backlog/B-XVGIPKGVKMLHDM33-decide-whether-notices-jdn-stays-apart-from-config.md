---
created: 2026-11-11
needs: owner
---

# B-XVGIPKGVKMLHDM33 Decide whether notices.jdn stays apart from config.jdn now that config.jdn no longer moves the binary

## Why
D-KPP2PSBZKFSROC44 and the comment atop tools/build/notices.jdn keep the notice sources out of config.jdn because config.jdn's content moved the binary. Task config-jdn-hash-input (U-ILCUNCJK3HY56H64) showed that path was gensym reuse under collector timing, closed by holding the collector off (L-2H7SFLEMCU2MPRZN): unread config.jdn data no longer changes the image. The stated reason is now false either way.

## Notes
- Driver's recommendation: keep notices.jdn separate, and supersede D-KPP2PSBZKFSROC44 with the reason that holds today: the image process should read only what the image uses, so license edits never reach it. Then reword the notices.jdn comment.
- The alternative is folding the list back into config.jdn.
