import Testing
@testable import SetSplitterCore

@Suite("Timestamp")
struct TimestampTests {

    @Test("mm:ss — leading field is minutes, never hours", arguments: [
        ("0:00", 0.0),
        ("4:44", 284.0),
        ("02:36", 156.0),
        ("10:06", 606.0),
        ("75:00", 4500.0),      // minutes may exceed 59 in two-segment form
    ])
    func parsesMinutesSeconds(_ text: String, _ expected: Double) {
        #expect(Timestamp(text: text)?.seconds == expected)
    }

    @Test("h:mm:ss", arguments: [
        ("1:02:03", 3723.0),
        ("0:04:44", 284.0),
        ("2:00:00", 7200.0),
        ("12:34:56", 45296.0),
    ])
    func parsesHoursMinutesSeconds(_ text: String, _ expected: Double) {
        #expect(Timestamp(text: text)?.seconds == expected)
    }

    @Test("rejects malformed input", arguments: [
        "156s", "2:00PM", "4-44", "1:2:3:4", "", ":", "4:", ":44", "1:99", "1:60:00", "abc:def",
    ])
    func rejectsGarbage(_ text: String) {
        #expect(Timestamp(text: text) == nil)
    }

    @Test("seconds field must be < 60")
    func rejectsSixtySeconds() {
        #expect(Timestamp(text: "3:60") == nil)
        #expect(Timestamp(text: "1:00:60") == nil)
    }

    @Test("Comparable orders by seconds")
    func ordering() {
        #expect(Timestamp(seconds: 10) < Timestamp(seconds: 20))
        #expect(Timestamp(seconds: 20) > Timestamp(seconds: 10))
        #expect(Timestamp(seconds: 10) == Timestamp(seconds: 10))
    }

    @Test("displayString drops the hour field below 1h", arguments: [
        (0.0, "0:00"),
        (284.0, "4:44"),
        (3723.0, "1:02:03"),
        (45296.0, "12:34:56"),
    ])
    func display(_ seconds: Double, _ expected: String) {
        #expect(Timestamp(seconds: seconds).displayString == expected)
    }
}
