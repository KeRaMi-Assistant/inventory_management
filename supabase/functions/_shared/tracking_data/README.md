# tracking_number_data — vendored snapshot

Source: https://github.com/jkeen/tracking_number_data (MIT)
Snapshot-SHA: cb4af5736368a1821833ef6e792ffd4f7a3e2930
Vendored at: 2026-05-13

## What

Carrier-pattern + validation specs (Regex + checksum algorithms) for tracking
numbers across major carriers. Used by `tracking_validators.ts` (T2b) for
confidence-grading.

## How to update

1. `cd /tmp && git clone --depth 1 https://github.com/jkeen/tracking_number_data`
2. Copy `couriers/*.json` into this directory.
3. Update `Snapshot-SHA` above with `git rev-parse HEAD`.
4. Re-run Deno tests in `tracking_validators_test.ts` — they must pass against
   the new `test_numbers` blocks before merging.
5. Diff carrier changes in PR-description.

## License

See `LICENSE` (MIT, (c) Jeff Keen and contributors).

## Why a vendored snapshot, not a git-submodule?

- Supabase Edge Functions deploy from a single repo — submodules complicate
  the build.
- We want diff-able upstream changes in code review.
- Carrier-data changes infrequently (months); manual refresh is acceptable.

## Notes on upstream layout

- Upstream default branch is `main` (not `master`).
- Upstream uses `couriers/` (not `tracking_numbers/`).
- Filenames use no underscores between words for some carriers
  (e.g. `canadapost.json`, not `canada_post.json`). No dedicated
  `royal_mail.json` exists — Royal Mail is covered by the `s10.json`
  (UPU S10 international parcels spec).
- 12 carrier files vendored: amazon, canadapost, dhl, dpd, fedex, landmark,
  lasership, old_dominion, ontrac, s10, ups, usps.
