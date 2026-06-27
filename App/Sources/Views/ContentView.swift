import SwiftUI

/// Root editor screen. Thin: owns no save/file logic, only composes sections
/// and forwards the file-open hook that Task 5 wires to NSOpenPanel.
struct ContentView: View {
    @Bindable var model: SaveEditorModel
    var onLoadFile: () -> Void = {}

    var body: some View {
        Form {
            CurrencySection(model: model)
            IngredientsSection(model: model)
            FileInfoSection(model: model, onLoadFile: onLoadFile)
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 540)
        .task { model.detectLatestSave() }
    }
}
