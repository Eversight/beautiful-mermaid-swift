import XCTest
@testable import LayoutKernel

/// Verify our Random class matches java.util.Random exactly.
/// nextInt() and nextDouble() reference values from Java 17: new Random(1).
final class JavaRandomTest: XCTestCase {

    func testNextIntSequence() {
        // Java: Random r = new Random(1); r.nextInt() called 10 times
        let expected: [Int] = [
            -1155869325,
            431529176,
            1761283695,
            1749940626,
            892128508,
            155629808,
            1429008869,
            -1465154083,
            -138487339,
            -1242363800
        ]
        let r = Random(seed: 1)
        for (i, exp) in expected.enumerated() {
            let got = r.nextInt()
            XCTAssertEqual(got, exp, "nextInt() call #\(i+1)")
        }
    }

    func testNextDoubleSequence() {
        // Java: Random r = new Random(1); r.nextDouble() called 5 times
        let expected: [Double] = [
            0.7308781907032909,
            0.41008081149220166,
            0.20771484130971707,
            0.3327170559595112,
            0.9677559094241207
        ]
        let r = Random(seed: 1)
        for (i, exp) in expected.enumerated() {
            let got = r.nextDouble()
            XCTAssertEqual(got, exp, accuracy: 1e-15, "nextDouble() call #\(i+1)")
        }
    }

    func testNextBooleanDerivedFromNextInt() {
        // nextBoolean() = next(1) != 0
        // next(1) returns the top bit of the 48-bit seed after advance.
        // Since nextInt() = next(32) = seed >> 16 (top 32 bits),
        // next(1) = seed >> 47 = (nextInt value) >> 31 (sign bit).
        // So nextBoolean should be: (nextInt < 0) i.e. negative means top bit = 1
        let intValues: [Int] = [
            -1155869325, 431529176, 1761283695, 1749940626, 892128508,
            155629808, 1429008869, -1465154083, -138487339, -1242363800
        ]
        let expectedBooleans = intValues.map { $0 < 0 }
        // [true, false, false, false, false, false, false, true, true, true]

        let r = Random(seed: 1)
        for (i, exp) in expectedBooleans.enumerated() {
            let got = r.nextBoolean()
            XCTAssertEqual(got, exp, "nextBoolean() call #\(i+1)")
        }
    }

    func testNextFloatDerivedFromNextInt() {
        // nextFloat() = next(24) / (1 << 24)
        // next(24) = seed >> 24 = (seed >> 16) >> 8 = nextInt() >>> 8 (unsigned)
        let intValues: [Int32] = [
            -1155869325, 431529176, 1761283695, 1749940626, 892128508
        ]
        let expectedFloats = intValues.map { Float(UInt32(bitPattern: $0) >> 8) / Float(1 << 24) }

        let r = Random(seed: 1)
        for (i, exp) in expectedFloats.enumerated() {
            let got = r.nextFloat()
            XCTAssertEqual(got, exp, accuracy: 1e-9, "nextFloat() call #\(i+1)")
        }
    }

    func testNextIntBounded() {
        // Java: Random r = new Random(1); r.nextInt(10) called 10 times
        let expected = [5, 8, 7, 3, 4, 4, 4, 6, 8, 8]
        let r = Random(seed: 1)
        for (i, exp) in expected.enumerated() {
            let got = r.nextInt(10)
            XCTAssertEqual(got, exp, "nextInt(10) call #\(i+1)")
        }
    }

    func testSeed0() {
        // Java: new Random(0).nextInt() = -1155484576
        let r = Random(seed: 0)
        XCTAssertEqual(r.nextInt(), -1155484576)
    }

    func testSetSeedResets() {
        let r = Random(seed: 42)
        _ = r.nextInt()
        r.setSeed(1)
        XCTAssertEqual(r.nextInt(), -1155869325)
    }
}
