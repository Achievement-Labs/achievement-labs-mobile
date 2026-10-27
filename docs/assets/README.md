# README visuals

`banner.svg` shares the organization and desktop pages' dark and mint palette.

The PNGs are unmodified emulator/simulator screenshots from the existing offline checks:

| Asset | Source | GitHub Actions run |
| --- | --- | --- |
| `android-session.png` | `Android-queue.png`, Android Screens artifact | [40511229450](https://github.com/Achievement-Labs/achievement-labs-mobile/actions/runs/40511229450) |
| `ios-library.png` | `iPhone-library.png`, iOS Simulator Checks artifact | [40511677969](https://github.com/Achievement-Labs/achievement-labs-mobile/actions/runs/40511677969) |
| `ios-profile-editor.png` | `iPhone-xbox360.png`, iOS Simulator Checks artifact | [40511677969](https://github.com/Achievement-Labs/achievement-labs-mobile/actions/runs/40511677969) |

The checks in `android/smoke.py` and `mobile/tools/simulator_smoke.py` use synthetic profiles and preview modes. Retrieve fresh screenshots from their workflow artifacts when the interface changes. Retain the sample-data caption and inspect every replacement for credentials, pairing codes, or private account information before committing. Screenshots do not establish live achievement credit or console synchronization.
