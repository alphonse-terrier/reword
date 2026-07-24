import XCTest
@testable import Reword

final class AXTextStrategyRoleTests: XCTestCase {
    func testEditableRoles() {
        XCTAssertTrue(AXTextStrategy.isEditableRole("AXTextField"))
        XCTAssertTrue(AXTextStrategy.isEditableRole("AXTextArea"))
        XCTAssertTrue(AXTextStrategy.isEditableRole("AXComboBox"))
        XCTAssertTrue(AXTextStrategy.isEditableRole("AXSearchField"))
    }

    func testNonEditableRoles() {
        XCTAssertFalse(AXTextStrategy.isEditableRole("AXStaticText"))
        XCTAssertFalse(AXTextStrategy.isEditableRole("AXWebArea"))
        XCTAssertFalse(AXTextStrategy.isEditableRole("AXGroup"))
        XCTAssertFalse(AXTextStrategy.isEditableRole("AXScrollArea"))
        XCTAssertFalse(AXTextStrategy.isEditableRole("AXRow"))
    }

    func testNilRoleIsNotEditable() {
        XCTAssertFalse(AXTextStrategy.isEditableRole(nil))
    }

    func testUnknownRoleIsNotEditable() {
        XCTAssertFalse(AXTextStrategy.isEditableRole("AXSomeMadeUpRole"))
    }

    // MARK: - isEditableSignal (corroborated read-only detection)

    func testValueSettableAloneIsEditable() {
        XCTAssertTrue(AXTextStrategy.isEditableSignal(valueSettable: true, role: nil))
    }

    func testChromiumStyleEditableAreaWithoutValueSettable() {
        // Regression case: Slack (Electron/Chromium) and Firefox (Gecko) often report
        // kAXSelectedTextAttribute (and sometimes kAXValue) as not settable even for genuinely
        // editable content — the role should still catch it.
        XCTAssertTrue(AXTextStrategy.isEditableSignal(valueSettable: false, role: "AXTextArea"))
        XCTAssertTrue(AXTextStrategy.isEditableSignal(valueSettable: false, role: "AXTextField"))
    }

    func testNeitherSignalMeansReadOnly() {
        XCTAssertFalse(AXTextStrategy.isEditableSignal(valueSettable: false, role: "AXStaticText"))
        XCTAssertFalse(AXTextStrategy.isEditableSignal(valueSettable: false, role: nil))
    }

    // MARK: - isKnownEditableApp (Microsoft Office allowlist)

    func testKnownOfficeAppsAreTreatedAsEditable() {
        // Regression case: Word's custom text-rendering engine resolves the focused element to
        // a generic AXSplitGroup container with no editable signal at all, no matter how long we
        // wait — these apps are allowlisted rather than defaulting to read-only.
        XCTAssertTrue(AXTextStrategy.isKnownEditableApp(bundleIdentifier: "com.microsoft.Word"))
        XCTAssertTrue(AXTextStrategy.isKnownEditableApp(bundleIdentifier: "com.microsoft.Excel"))
        XCTAssertTrue(AXTextStrategy.isKnownEditableApp(bundleIdentifier: "com.microsoft.Powerpoint"))
    }

    func testUnknownAppsAreNotAssumedEditable() {
        XCTAssertFalse(AXTextStrategy.isKnownEditableApp(bundleIdentifier: "com.apple.Safari"))
        XCTAssertFalse(AXTextStrategy.isKnownEditableApp(bundleIdentifier: nil))
    }
}
