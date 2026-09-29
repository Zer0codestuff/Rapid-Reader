import XCTest
@testable import RapidReaderCore

final class LocalizationTests: XCTestCase {
    func testCoreMessagesHaveItalianTranslations() throws {
        let path = try XCTUnwrap(Bundle.module.path(forResource: "it", ofType: "lproj"))
        let italian = try XCTUnwrap(Bundle(path: path))
        XCTAssertEqual(italian.localizedString(forKey: "Part %lld", value: nil, table: nil), "Parte %lld")
        XCTAssertEqual(italian.localizedString(forKey: "Could not read %@.", value: nil, table: nil), "Impossibile leggere %@.")
        XCTAssertEqual(ReadingFormat.plainText.displayName, String(localized: "Text", bundle: .module))
    }
}
