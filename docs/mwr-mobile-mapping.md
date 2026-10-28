# Modern Warfare Remastered mobile mapping

Ports the mobile routing guard and offline regressions from Achievement-Labs/achievement-labs PR #22, revision 955e708c9ef3827203ed808105ea74584e375924, into the standalone mobile repository. The reviewed mapping signatures remain in mobile/tools/edition_mappings.json, outside runtime Data.json.

The generator accepts the complete legacy or corrected achievement ID set and checks ordered event signatures, service identity, properties and measurements. All 50 Xbox achievements become available only when every mapping passes. Changed or missing IDs, changed payload semantics and duplicate requests disable the whole title. Author-disabled titles and other edition guards remain blocked.

The source catalog, event templates, versions and official update endpoints are unchanged. Both platform workflows run the five offline routing regressions before generating their catalog. Android and iOS core tests verify packaged mapping IDs and rendered payload identity. Tests use synthetic data and never submit Xbox telemetry.
