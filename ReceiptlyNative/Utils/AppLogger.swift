import OSLog

enum AppLogger {
    private static let subsystem = "com.utkoleg.receiptly"

    static let persistence = Logger(subsystem: subsystem, category: "Persistence")
    static let currency = Logger(subsystem: subsystem, category: "Currency")
    static let auth = Logger(subsystem: subsystem, category: "Auth")
}
