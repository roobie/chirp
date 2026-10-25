---
created: 2026-10-25
---

# B-FIMDJ2SCVREG6KFT Offer spork/json an ordered-object option so chirp's decoder copy can go

## Why
chirp carries a copy of spork's JSON decoder (D-ZXXSPKUCZ4IOIQPN), which must be brought in step on every spork pin move. If spork/json let a caller supply how objects are built, or kept order itself, the copy could be deleted.

## Notes
A small hook (a callback or a constructor argument) is more likely to be accepted than a whole ordered type in spork.
