import Testing
import Foundation
import DaveSaveCore
@testable import DaveTheDiverSaveEditor

@MainActor
struct SaveEditorModelTests {

    /// Minimal compact save: gold 1000, bei 50, flame 7, followers 123.
    private static let fixtureJSON =
        #"{"PlayerInfo":{"m_Gold":1000,"m_Bei":50,"m_ChefFlame":7},"SNSInfo":{"m_Follow_Count":123}}"#

    private func loadedModel() -> SaveEditorModel {
        let model = SaveEditorModel()
        model.load(data: SaveCodec.encode(Self.fixtureJSON), sourceURL: nil)
        return model
    }

    @Test func loadsCurrencyValues() {
        let model = loadedModel()
        #expect(model.isLoaded)
        #expect(model.currentFileURL == nil)
        #expect(model.value(.gold) == 1000)
        #expect(model.value(.bei) == 50)
        #expect(model.value(.artisansFlame) == 7)
        #expect(model.value(.followerCount) == 123)
        #expect(model.loadedValue(.gold) == 1000)
        #expect(model.displayText(.gold) == "1000")
        #expect(model.hasChanges == false)
        #expect(model.pendingChanges().isEmpty)
    }

    @Test func unloadedModelReadsNilAndEmpty() {
        let model = SaveEditorModel()
        #expect(model.isLoaded == false)
        #expect(model.value(.gold) == nil)
        #expect(model.loadedValue(.gold) == nil)
        #expect(model.displayText(.gold) == "")
        #expect(model.hasChanges == false)
    }

    @Test func applyTextEditsGoldAndPreviewsChange() {
        let model = loadedModel()
        model.applyText(.gold, "2222")
        #expect(model.value(.gold) == 2222)
        #expect(model.displayText(.gold) == "2222")
        #expect(model.hasChanges)
        #expect(model.pendingChanges() == [
            FieldChange(path: "PlayerInfo.m_Gold", oldValue: "1000", newValue: "2222")
        ])
    }

    @Test func applyTextIgnoresEmptyAndNonNumeric() {
        let model = loadedModel()
        model.applyText(.gold, "")
        model.applyText(.gold, "abc")
        model.applyText(.gold, "12x")
        #expect(model.value(.gold) == 1000)
        #expect(model.hasChanges == false)
    }

    @Test func applyTextClampsThroughSetter() {
        let model = loadedModel()
        model.applyText(.gold, "9999999999")   // 10 nines, over the 999,999,999 clamp
        #expect(model.value(.gold) == 999_999_999)
    }

    @Test func maximizeUsesButtonPresets() {
        let model = loadedModel()
        model.maximize(.gold)
        model.maximize(.bei)
        model.maximize(.artisansFlame)
        model.maximize(.followerCount)
        #expect(model.value(.gold) == 999_999_999)
        #expect(model.value(.bei) == 999_999_999)
        #expect(model.value(.artisansFlame) == 999_999)
        #expect(model.value(.followerCount) == 99_999)
    }

    @Test func resetRestoresLoadedValue() {
        let model = loadedModel()
        model.maximize(.gold)
        #expect(model.value(.gold) == 999_999_999)
        model.reset(.gold)
        #expect(model.value(.gold) == 1000)
        #expect(model.hasChanges == false)
    }

    @Test func badJSONSetsAlertAndDoesNotLoad() {
        let model = SaveEditorModel()
        model.load(data: SaveCodec.encode("this is not json"), sourceURL: nil)
        #expect(model.isLoaded == false)
        #expect(model.alert != nil)
        #expect(model.value(.gold) == nil)
    }
}
