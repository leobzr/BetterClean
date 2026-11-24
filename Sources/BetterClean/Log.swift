import os

/// Unified-log output. View with:
///   log stream --predicate 'subsystem == "local.betterclean.prototype"'
private let logger = Logger(subsystem: "local.betterclean.prototype", category: "app")

/// Messages contain no personal data, so they're logged as public
/// (otherwise the system log shows them as <private>).
func logEvent(_ message: String) {
    logger.notice("\(message, privacy: .public)")
}
