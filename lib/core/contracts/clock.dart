/// Returns "now". Inject one into anything time-dependent (practice engine, repositories)
/// so tests can move time across midnight and daylight-saving changes.
typedef Clock = DateTime Function();

/// The real clock: local device time.
DateTime systemClock() => DateTime.now();
