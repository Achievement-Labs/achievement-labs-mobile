# Mobile repository separation

Source: https://github.com/Achievement-Labs/achievement-labs/tree/b053785ec6e931d02650038c19aa91dae3bcf604

This repository begins with an attributed snapshot of Android/iOS from that commit. Original commit history remains at the linked source. No pending feature PR was silently merged. Event payloads are byte-identical copies; hashes and source revision are recorded in `catalog-source/provenance.json`, outside Data.json.

## Pending contributions

- [PR #22](https://github.com/Achievement-Labs/achievement-labs/pull/22): Modern Warfare Remastered mobile mapping. Port into this repository, adjusting the catalogue paths; retain its offline regression tests.
- [PR #14](https://github.com/Achievement-Labs/achievement-labs/pull/14): mixed desktop/mobile search. Split Android/iOS changes here; desktop changes stay upstream. The existing PR remains draft.
- [PR #24](https://github.com/Achievement-Labs/achievement-labs/pull/24): Mac, Windows pairing, and mobile guides/mappings. Mobile changes belong here; Mac/desktop changes remain under review upstream. Its Mac build currently depends on `mobile/tools/prepare_360.py` and `mobile/Shared360` and must be adapted before merging after the separation.

## Release continuity

1. Configure the four existing `LABS_ANDROID_*` signing secrets for this repository, using the same permanent signing identity. GitHub does not expose secret values for automatic copying. Never generate a replacement key for existing installs.
2. Run Android and iOS CI. iOS packaging remains unsigned for user signing.
3. Publish a deliberately versioned migration release to the mobile repository and a corresponding bridge release in the old repository, so existing installed apps can discover the new update destination. This extraction does not publish releases or change version numbers.
4. Keep the old `mobile-event-feed` publisher running in the desktop repository. Both old and new clients read it there. Desktop mobile-sign-in/QR transfer remains available.

The source snapshot is intentionally fixed and reproducible. Future event snapshot refreshes must copy upstream data without rewriting payloads, preserve SupportedTitleIDs last, update the provenance manifest, and rerun the mobile catalogue checks. Keep research outside runtime Data.json.
