import XCTest
import Carbon
@testable import Voice2Text

final class HotkeyComboTests: XCTestCase {

    // MARK: - Default

    func testDefaultCombo() {
        let combo = HotkeyCombo.default
        XCTAssertEqual(combo.keyCode, UInt32(kVK_ANSI_Semicolon))
        XCTAssertEqual(combo.carbonModifiers, UInt32(cmdKey))
        XCTAssertEqual(combo.displayString, "⌘;")
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip() throws {
        let original = HotkeyCombo(keyCode: UInt32(kVK_ANSI_K), carbonModifiers: UInt32(cmdKey | shiftKey), displayString: "⇧⌘K")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotkeyCombo.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testCodableJSON() throws {
        let combo = HotkeyCombo.default
        let data = try JSONEncoder().encode(combo)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json?["keyCode"])
        XCTAssertNotNil(json?["carbonModifiers"])
        XCTAssertNotNil(json?["displayString"])
    }

    // MARK: - carbonModifiers(from:)

    func testCarbonModifiersCommand() {
        let result = HotkeyCombo.carbonModifiers(from: .command)
        XCTAssertEqual(result, UInt32(cmdKey))
    }

    func testCarbonModifiersShiftCommand() {
        let result = HotkeyCombo.carbonModifiers(from: [.shift, .command])
        XCTAssertEqual(result, UInt32(cmdKey) | UInt32(shiftKey))
    }

    func testCarbonModifiersAll() {
        let result = HotkeyCombo.carbonModifiers(from: [.command, .option, .control, .shift])
        XCTAssertEqual(result, UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey) | UInt32(shiftKey))
    }

    func testCarbonModifiersEmpty() {
        let result = HotkeyCombo.carbonModifiers(from: [])
        XCTAssertEqual(result, 0)
    }

    // MARK: - displayString(keyCode:modifiers:)

    func testDisplayStringCmdSemicolon() {
        let result = HotkeyCombo.displayString(keyCode: UInt16(kVK_ANSI_Semicolon), modifiers: .command)
        XCTAssertEqual(result, "⌘;")
    }

    func testDisplayStringShiftCmdK() {
        let result = HotkeyCombo.displayString(keyCode: UInt16(kVK_ANSI_K), modifiers: [.shift, .command])
        XCTAssertEqual(result, "⇧⌘K")
    }

    func testDisplayStringAllModifiers() {
        let result = HotkeyCombo.displayString(keyCode: UInt16(kVK_ANSI_A), modifiers: [.control, .option, .shift, .command])
        XCTAssertEqual(result, "⌃⌥⇧⌘A")
    }

    func testDisplayStringFunctionKey() {
        let result = HotkeyCombo.displayString(keyCode: UInt16(kVK_F5), modifiers: .command)
        XCTAssertEqual(result, "⌘F5")
    }

    // MARK: - keyName(for:)

    func testKeyNameLetters() {
        XCTAssertEqual(HotkeyCombo.keyName(for: UInt16(kVK_ANSI_A)), "A")
        XCTAssertEqual(HotkeyCombo.keyName(for: UInt16(kVK_ANSI_Z)), "Z")
    }

    func testKeyNameNumbers() {
        XCTAssertEqual(HotkeyCombo.keyName(for: UInt16(kVK_ANSI_0)), "0")
        XCTAssertEqual(HotkeyCombo.keyName(for: UInt16(kVK_ANSI_9)), "9")
    }

    func testKeyNameSpecial() {
        XCTAssertEqual(HotkeyCombo.keyName(for: UInt16(kVK_Space)), "Space")
        XCTAssertEqual(HotkeyCombo.keyName(for: UInt16(kVK_Return)), "↩")
        XCTAssertEqual(HotkeyCombo.keyName(for: UInt16(kVK_Tab)), "⇥")
    }

    func testKeyNameUnknown() {
        let result = HotkeyCombo.keyName(for: 999)
        XCTAssertTrue(result.hasPrefix("Key"))
    }

    // MARK: - Equatable

    func testEquatable() {
        let a = HotkeyCombo(keyCode: 10, carbonModifiers: 256, displayString: "⌘A")
        let b = HotkeyCombo(keyCode: 10, carbonModifiers: 256, displayString: "⌘A")
        let c = HotkeyCombo(keyCode: 11, carbonModifiers: 256, displayString: "⌘B")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
