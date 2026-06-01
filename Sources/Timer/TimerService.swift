import Foundation

/// Absolute-timestamp‑backed timer service.
///
/// 排雷指南 requirements met here:
///  • Uses **absolute timestamps** (Date), not relative `Timer` intervals,
///    so sleep/wake never causes drift or missed beats.
///  • `pause()` / `recalibrate()` driven by NSWorkspace sleep/wake
///     notifications from AppDelegate.
///  • Each flash is scheduled via DispatchSourceTimer, delivering the
///    callback on the main thread.
final class TimerService {

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.distracted.timer",
                                      qos: .background)

    /// The *absolute* timestamp of the next scheduled flash.
    private var nextFlashTimestamp: Date?

    /// User-configurable interval (seconds).
    private var interval: TimeInterval

    /// Invoked on the main thread at each flash tick.
    private var onFlash: (() -> Void)?

    // ── Init ──────────────────────────────────────────────────

    init(interval: TimeInterval = Constants.defaultFlashInterval,
         onFlash: (() -> Void)?) {
        self.interval = interval
        self.onFlash = onFlash
        scheduleNext()
    }

    deinit {
        timer?.cancel()
    }

    // ── Scheduling (private) ──────────────────────────────────

    /// Schedule the next flash based on the stored absolute timestamp,
    /// or compute the next interval boundary if no valid future timestamp exists.
    private func scheduleNext() {
        let now = Date()

        if let next = nextFlashTimestamp, next > now {
            // Future timestamp already set (e.g. recurring from a prior flash) → use it.
            armTimer(for: next)
        } else {
            // First launch, or recovering from sleep → align to next interval boundary.
            let next = nextIntervalBoundary(after: now)
            nextFlashTimestamp = next
            armTimer(for: next)
        }
    }

    /// Align `now` to the next whole interval boundary in epoch seconds.
    /// e.g. interval=300s, now=09:03:22 → next=09:05:00
    private func nextIntervalBoundary(after date: Date) -> Date {
        let epoch = date.timeIntervalSince1970
        let intervals = ceil(epoch / interval)
        return Date(timeIntervalSince1970: intervals * interval)
    }

    /// Create a new DispatchSourceTimer that fires at `date`.
    private func armTimer(for date: Date) {
        timer?.cancel()

        let delay = max(date.timeIntervalSinceNow, 0.1)  // min 100 ms
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + delay, leeway: .milliseconds(100))
        t.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.onFlash?()
            }
            // ── Advance to the *next* interval boundary ──
            self?.nextFlashTimestamp = date.addingTimeInterval(self?.interval ?? 300)
            self?.scheduleNext()
        }
        t.resume()
        timer = t
    }

    // ── Public API ────────────────────────────────────────────

    /// Cancel any pending timer. Called on sleep.
    func pause() {
        timer?.cancel()
        timer = nil
        // Keep nextFlashTimestamp — we want to know what we missed on wake.
    }

    /// Recalibrate after wake: if the scheduled flash was missed,
    /// snap to the next interval boundary from now.
    func recalibrate() {
        // Forget the old target so scheduleNext computes a fresh one from now.
        nextFlashTimestamp = nil
        scheduleNext()
        print("[Distracted] Timer recalibrated — next flash at \(nextFlashTimestamp?.formatted(date: .omitted, time: .standard) ?? "?")")
    }

    /// Change the interval at runtime. Resets the schedule.
    func setInterval(_ newInterval: TimeInterval) {
        interval = newInterval
        nextFlashTimestamp = nil
        scheduleNext()
    }
}
