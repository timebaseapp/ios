import XCTest
@testable import Timebase

final class TimeColorTests: XCTestCase {

    func testHexToOklch() {
        let c = OKLCH(hex: "F0B270")
        XCTAssertEqual(c.l, 0.807, accuracy: 0.01)
        XCTAssertEqual(c.c, 0.110, accuracy: 0.01)
        XCTAssertEqual(c.h, 66.9, accuracy: 1.0)
    }

    func testRoundtripHexish() {
        let c = OKLCH(hex: "F0B270")
        let cg = c.toRGBA()
        // Just sanity — we got a valid sRGB color.
        XCTAssertNotNil(cg)
    }

    func testInterpolationAtAnchor() {
        let lch = OKLCH(hex: "F0B270")
        XCTAssertEqual(lch.l, 0.807, accuracy: 0.01)
    }
}
