## What does this change?

<!-- If it fixes an issue, link it. -->

## Checklist

- [ ] `swift test` passes
- [ ] `xcodebuild -scheme DaveTheDiverSaveEditor test` passes
- [ ] If this touches the save format, a test covers it
- [ ] If this adds user-facing text, it goes through `String(localized:)` / a `Text("literal")`
- [ ] If this adds an editable value or a bulk action, it's one `editableScalars` row / one `BulkAction` entry
