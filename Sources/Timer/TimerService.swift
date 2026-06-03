import Foundation

// ═══════════════════════════════════════════════════════════════
//  TimerService — absolute-timestamp‑backed interval timer
// ═══════════════════════════════════════════════════════════════
//
//  [EN] Drives the periodic flash schedule.
//       Key design decisions:
//       • Uses **absolute timestamps** (Date), not a repeating Timer, to
//         survive sleep/wake cycles without cumulative drift.
//       • pause() / recalibrate() are called from AppDelegate in response
//         to NSWorkspace sleep/wake notifications.
//       • setInterval() lets the user change the interval at runtime;
//         the schedule is immediately recomputed from the next boundary.
//
//  [CN] 驱动周期性闪烁的核心定时器。
//       关键设计：
//       • 使用**绝对时间戳**（Date），而非重复 Timer，以在休眠/唤醒周期中
//         避免累积漂移。
//       • pause() / recalibrate() 由 AppDelegate 响应系统休眠/唤醒通知时调用。
//       • setInterval() 支持运行时修改间隔，立即基于下个边界重新计算。
//
//  [JP] 定期的な点滅を駆動するタイマーサービス。
//       設計の要点：
//       • 絶対タイムスタンプ（Date）を使用。繰り返し Timer ではなく、
//         スリープ/ウェイクによる累積ドリフトを防止。
//       • pause()/recalibrate() は AppDelegate がシステムのスリープ/ウェイク
//         通知に応じて呼び出す。
//       • setInterval() で実行中に間隔変更可能。即座に次の境界から再計算。
// ═══════════════════════════════════════════════════════════════

final class TimerService {

    // MARK: - Properties

    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.distracted.timer",
                                      qos: .utility)

    /// [EN] Absolute timestamp this timer instance was armed for (the *next* expected fire).
    ///      Used on wake to decide whether a flash was missed during sleep.
    /// [CN] 当前 Timer 所瞄准的绝对触发时间（即*下次*预期触发时间）。
    ///      唤醒时用于判断休眠期间是否错过了提醒。
    /// [JP] このタイマーインスタンスが設定された絶対発火時刻（*次回*発火予定時刻）。
    ///      ウェイク時にスリープ中の取りこぼしを判定するために使用。
    private var targetDate: Date?

    /// [EN] Current interval in seconds.
    /// [CN] 当前间隔（秒）。
    /// [JP] 現在の間隔（秒）。
    private var interval: TimeInterval

    /// [EN] Callback invoked on the main thread when it's time to flash.
    /// [CN] 闪烁触发时在主线程执行的回调。
    /// [JP] 点滅時にメインスレッドで実行されるコールバック。
    private var onFlash: (() -> Void)?
    private var isPaused = false

    // MARK: - Init

    /// [EN] Create the timer service.
    /// - Parameters:
    ///   - interval: Flash interval in seconds (read from UserDefaults by the caller).
    ///   - onFlash: Closure fired on the main queue at each tick.
    /// [CN] 创建定时器服务。
    /// - Parameters:
    ///   - interval: 闪烁间隔（秒），由调用方从 UserDefaults 读取。
    ///   - onFlash: 每次触发时在主队列执行的闭包。
    /// [JP] タイマーサービスを作成。
    /// - Parameters:
    ///   - interval: 点滅間隔（秒）。呼び出し元が UserDefaults から読み込む。
    ///   - onFlash: 各ティックでメインキューで実行されるクロージャ。
    init(interval: TimeInterval = Constants.defaultFlashInterval,
         onFlash: (() -> Void)?) {
        self.interval = interval
        self.onFlash = onFlash
        print("[Distracted] TimerService initialised — interval: \(Int(interval))s")
        queue.async { [weak self] in
            self?.scheduleNextLocked()
        }
    }

    deinit {
        timer?.cancel()
    }

    // MARK: - Scheduling (private)

    /// [EN] Schedule the next flash.
    ///      If targetDate is set and still in the future, use it directly.
    ///      Otherwise compute the next interval boundary from now.
    /// [CN] 调度下一次闪烁。
    ///      如果 targetDate 已设定且仍在未来，直接使用。
    ///      否则从当前时间计算下一个间隔边界。
    /// [JP] 次回点滅を予約。
    ///      targetDate が設定済みで未来の時刻ならそのまま使用。
    ///      そうでなければ現在時刻から次のインターバル境界を計算。
    private func scheduleNextLocked() {
        guard !isPaused else { return }

        let now = Date()

        if let target = targetDate, target > now {
            // [EN] Valid future target exists → arm for it.
            // [CN] 存在有效的未来目标 → 直接瞄准。
            // [JP] 有効な未来の目標あり → そのまま設定。
            armTimerLocked(for: target)
        } else {
            // [EN] No target or target is in the past → align to next interval boundary.
            // [CN] 无目标或目标已过期 → 对齐到下一个间隔边界。
            // [JP] 目標がない、または過去の時刻 → 次のインターバル境界に合わせる。
            let next = nextIntervalBoundary(after: now)
            targetDate = next
            armTimerLocked(for: next)
        }
    }

    /// [EN] Align `date` to the next whole interval boundary (epoch‑based maths).
    ///      e.g. interval=300s, now=09:03:22 → next=09:05:00
    /// [CN] 将时间对齐到下一个完整间隔边界（基于 epoch 时间戳计算）。
    ///      例如：interval=300s, now=09:03:22 → next=09:05:00
    /// [JP] 時刻を次のインターバル境界に揃える（エポックベースの計算）。
    ///      例：interval=300s, now=09:03:22 → next=09:05:00
    private func nextIntervalBoundary(after date: Date) -> Date {
        let epoch = date.timeIntervalSince1970
        let intervals = ceil(epoch / interval)
        return Date(timeIntervalSince1970: intervals * interval)
    }

    /// [EN] Create a one-shot DispatchSourceTimer that fires at `date`.
    ///      Saves `date` as `targetDate` for wake-recalibration comparison.
    /// [CN] 创建一个在 `date` 触发的一次性 DispatchSourceTimer，
    ///      并将 `date` 保存为 `targetDate`，供唤醒校准时对比使用。
    /// [JP] 指定された `date` に発火する単発 DispatchSourceTimer を作成。
    ///      `date` を `targetDate` として保存し、ウェイク時の再調整に使用。
    private func armTimerLocked(for date: Date) {
        cancelTimerLocked()

        targetDate = date
        let delay = max(date.timeIntervalSinceNow, 0.1)
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + delay, leeway: .seconds(1))
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            guard !self.isPaused else { return }

            // [EN] Fire the callback on the main thread (UI updates must happen there).
            // [CN] 在主线程触发回调（UI 更新必须在此进行）。
            // [JP] メインスレッドでコールバックを実行（UI更新はここで行うこと）。
            DispatchQueue.main.async {
                self.onFlash?()
            }

            // [EN] Advance target for the next tick and schedule it.
            // [CN] 推进到下一个边界，准备下一轮触发。
            // [JP] 次回ティックのために次の境界に進める。
            self.targetDate = nil
            self.scheduleNextLocked()
        }
        t.resume()
        timer = t
    }

    private func cancelTimerLocked() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    // MARK: - Public API

    /// [EN] Cancel pending timer. Preserves `targetDate` so we can detect misses on wake.
    /// [CN] 取消待执行的定时器。保留 `targetDate` 以便唤醒时检测是否错过。
    /// [JP] 保留中のタイマーをキャンセル。スリープ復帰時の取りこぼし検出のため
    ///      `targetDate` は保持する。
    func pause() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.isPaused = true
            self.cancelTimerLocked()
            print("[Distracted] Timer paused (target: \(self.targetDate?.formatted(date: .omitted, time: .standard) ?? "?"))")
        }
    }

    /// [EN] Resume scheduling. By default, recomputes from now to avoid stale UI-preview targets.
    /// [CN] 恢复调度。默认从当前时间重算，避免设置预览期间留下过期目标。
    /// [JP] スケジュールを再開。既定では現在時刻から再計算し、古い目標を避ける。
    func resume(recomputeFromNow: Bool = true) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.isPaused = false
            if recomputeFromNow {
                self.targetDate = nil
            }
            self.scheduleNextLocked()
            print("[Distracted] Timer resumed")
        }
    }

    /// [EN] Recalibrate after wake. Compares current time with `targetDate`:
    ///      - If `Date() >= targetDate`: a flash was missed during sleep → trigger immediately,
    ///        then recalculate the next target from now.
    ///      - If `Date() < targetDate`: flash is still pending → re-arm with remaining time.
    /// [CN] 唤醒后重新校准。将当前时间与 `targetDate` 对比：
    ///      - 如果 `Date() >= targetDate`：休眠期间错过了提醒 → 立即触发一次，
    ///        然后从当前时间重新计算下一个目标。
    ///      - 如果 `Date() < targetDate`：尚未错过 → 按剩余时间重新启动 Timer。
    /// [JP] ウェイク後に再調整。現在時刻と `targetDate` を比較：
    ///      - `Date() >= targetDate`：スリープ中に取りこぼし → 即座に点滅、
    ///        その後現在時刻から次の目標を再計算。
    ///      - `Date() < targetDate`：まだ発火時刻前 → 残り時間でタイマーを再設定。
    func recalibrate() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.isPaused = false
            self.cancelTimerLocked()

            guard let target = self.targetDate else {
            // [EN] No target set — just schedule from now.
            // [CN] 没有目标 → 从现在开始调度。
            // [JP] 目標なし → 現在時刻からスケジュール。
                self.scheduleNextLocked()
                return
            }

            let now = Date()

            if now >= target {
            // [EN] ⚠️ Missed a flash during sleep → trigger immediately.
            // [CN] ⚠️ 休眠期间错过了提醒 → 立即触发。
            // [JP] ⚠️ スリープ中に点滅を取りこぼし → 即座に発火。
                print("[Distracted] Missed flash during sleep (target was \(target.formatted(date: .omitted, time: .standard))) — triggering now")

                DispatchQueue.main.async { [weak self] in
                    self?.onFlash?()
                }

            // [EN] Reset target and recompute from current time.
            // [CN] 重置目标，从当前时间重新计算。
            // [JP] 目標をリセットし、現在時刻から再計算。
                self.targetDate = nil
                self.scheduleNextLocked()
            } else {
            // [EN] Target is still in the future → re-arm with remaining interval.
            // [CN] 目标仍在未来 → 按剩余间隔重新启动 Timer。
            // [JP] まだ未来の目標 → 残り時間でタイマーを再セット。
                let remaining = target.timeIntervalSinceNow
                print("[Distracted] Wake before scheduled flash — remaining: \(Int(remaining))s, target: \(target.formatted(date: .omitted, time: .standard))")

                self.targetDate = target
                self.armTimerLocked(for: target)
            }

            let nextStr = self.targetDate?.formatted(date: .omitted, time: .standard) ?? "?"
            print("[Distracted] Timer recalibrated — next flash at \(nextStr)")
        }
    }

    /// [EN] Change the interval at runtime. Resets the schedule immediately.
    /// [CN] 运行时修改间隔。立即重置调度。
    /// [JP] 実行中に間隔を変更。即座にスケジュールをリセット。
    func setInterval(_ newInterval: TimeInterval) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.interval = max(newInterval, TimeInterval(Constants.intervalMinMinutes * 60))
            self.targetDate = nil
            self.scheduleNextLocked()
            print("[Distracted] Interval updated to \(Int(newInterval))s — schedule reset")
        }
    }
}
