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
}
