# Achievement Labs Mobile

Android and iOS clients for Achievement Labs, extracted from the released upstream source.

- [Android build and usage](android/README.md)
- [iOS build and usage](mobile/README.md)
- [Desktop app and authoritative event data](https://github.com/Achievement-Labs/achievement-labs)
- [Migration and pending contributions](docs/repository-split.md)

Android uses Java/WebView; iOS uses Swift/SwiftUI. The shared offline Xbox 360 editor lives in `mobile/Shared360`. Build workflows are included for both platforms. Application update checks target this repository; event-data checks continue to target the desktop repository.

Build resources are self-contained: `catalog-source/` contains the unchanged upstream event snapshot and edition guards, `catalog/` contains title data, and `assets/` contains the app icon. Run `python mobile/tools/prepare_catalogue.py` before either build. No desktop checkout is needed. The existing pinned `prepare_360.py` download is still required for the approved shared signing resource.

No installer release is published by this extraction. Existing installed versions still check the old repository until a migration release is provided there.

## Credits

Source and contributor history remain in [Achievement-Labs/achievement-labs](https://github.com/Achievement-Labs/achievement-labs). This extraction preserves existing attribution; it does not relicense the contributed source.
