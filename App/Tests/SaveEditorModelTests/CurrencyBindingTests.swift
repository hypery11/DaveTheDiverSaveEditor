import Testing
import Foundation
import DaveSaveCore
@testable import DaveTheDiverSaveEditor

@MainActor
struct CurrencyBindingTests {

    /// A loaded model built from synthetic, in-memory save bytes — the same
    /// seam `CurrencyRow`'s derived Binding reads/writes through.
    private func loadedModel() -> SaveEditorModel {
        let json = #"{"PlayerInfo":{"m_Gold":100,"m_Bei":200,"m_ChefFlame":300},"SNSInfo":{"m_Follow_Count":400}}"#
        let model = SaveEditorModel(referenceDB: nil, fileManager: .default, home: nil)
        model.load(data: SaveCodec.encode(json), sourceURL: nil)
        return model
    }

    @Test func displayTextIsEmptyBeforeLoad() {
        let model = SaveEditorModel(referenceDB: nil, fileManager: .default, home: nil)
        #expect(model.isLoaded == false)
        #expect(model.displayText(.gold) == "")
    }

    @Test func displayTextReflectsLoadedValues() {
        let model = loadedModel()
        #expect(model.isLoaded == true)
        #expect(model.displayText(.gold) == "100")
        #expect(model.displayText(.bei) == "200")
        #expect(model.displayText(.artisansFlame) == "300")
        #expect(model.displayText(.followerCount) == "400")
    }

    @Test func applyTextParsesNumericInput() {
        let model = loadedModel()
        model.applyText(.gold, "5000")
        #expect(model.value(.gold) == 5000)
        #expect(model.displayText(.gold) == "5000")
    }

    @Test func applyTextIgnoresEmptyAndNonNumericInput() {
        let model = loadedModel()
        model.applyText(.gold, "")     // no-op
        model.applyText(.gold, "abc")  // no-op
        #expect(model.value(.gold) == 100)
    }

    @Test func maximizeUsesCurrencyMaxButtonValue() {
        let model = loadedModel()
        model.maximize(.artisansFlame)
        #expect(model.value(.artisansFlame) == Currency.artisansFlame.maxButtonValue) // 999_999
        model.maximize(.followerCount)
        #expect(model.value(.followerCount) == Currency.followerCount.maxButtonValue)  // 99_999
    }

    @Test func resetRestoresLoadedValue() {
        let model = loadedModel()
        model.applyText(.gold, "5000")
        model.reset(.gold)
        #expect(model.value(.gold) == 100)
    }
}
