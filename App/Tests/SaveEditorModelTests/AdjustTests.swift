import Testing
import Foundation
import DaveSaveCore
@testable import DaveTheDiverSaveEditor

@MainActor
@Suite struct AdjustTests {
    private func loaded() -> SaveEditorModel {
        let m = SaveEditorModel()
        m.load(data: SaveCodec.encode(#"{"PlayerInfo":{"m_Gold":1000,"m_Bei":50,"m_ChefFlame":7},"SNSInfo":{"m_Follow_Count":7}}"#), sourceURL: nil)
        return m
    }
    @Test func addsAndSubtracts() {
        let m = loaded()
        m.adjust(.gold, by: 100);  #expect(m.value(.gold) == 1100)
        m.adjust(.gold, by: -10);  #expect(m.value(.gold) == 1090)
    }
    @Test func clampsAtZero() {
        let m = loaded()
        m.adjust(.followerCount, by: -100)   // 7 - 100 -> 0, never negative
        #expect(m.value(.followerCount) == 0)
    }
    @Test func respectsUpperClampOfSetter() {
        let m = loaded()
        m.adjust(.gold, by: 999_999_999)     // setter clamps gold at 999,999,999
        #expect(m.value(.gold) == 999_999_999)
    }
    @Test func adjustEnablesWrite() {
        let m = loaded()
        m.adjust(.gold, by: 10)
        #expect(m.hasChanges)
    }
}
