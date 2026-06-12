import Foundation

// ═══════════════════════════════════════════════════════════════
//  TimerService — absolute-timestamp‑backed interval timer
// ═══════════════════════════════════════════════════════════════
//
//  [EN] Drives reminder scheduling with absolute Date targets and one-shot DispatchSourceTimers.
//  [CN] 使用绝对时间戳和一次性 DispatchSourceTimer 调度提醒，避免休眠、唤醒或 UI 交互造成累计漂移。
//  [JP] 絶対時刻と単発 DispatchSourceTimer でリマインダーを管理し、スリープ復帰や UI 操作によるズレを抑える。
// ═══════════════════════════════════════════════════════════════

final class TimerService {

    // MARK: - 属性

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

    // MARK: - 初始化

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

    // MARK: - 私有调度

    /// [EN] Schedule the next flash.
    ///      If targetDate is set and still in the future, use it directly.
    ///      Otherwise compute a full interval from now.
    /// [CN] 调度下一次闪烁。
    ///      如果 targetDate 已设定且仍在未来，直接使用。
    ///      否则从当前时间开始计算一个完整间隔。
    /// [JP] 次回点滅を予約。
    ///      targetDate が設定済みで未来の時刻ならそのまま使用。
    ///      そうでなければ現在時刻から完全なインターバルを計算。
    private func scheduleNextLocked() {
        guard !isPaused else { return }

        let now = Date()

        if let target = targetDate, target > now {
            // [EN] Valid future target exists → arm for it.
            // [CN] 存在有效的未来目标 → 直接瞄准。
            // [JP] 有効な未来の目標あり → そのまま設定。
            armTimerLocked(for: target)
        } else {
            // [EN] No target or target is in the past → start a full interval from now.
            // [CN] 无目标或目标已过期 → 从当前时刻开始完整计算一个间隔。
            // [JP] 目標がない、または過去の時刻 → 現在時刻から完全な間隔を開始する。
            let next = nextTargetFromNow()
            targetDate = next
            armTimerLocked(for: next)
        }
    }

    // 从当前时间向后计算一个完整周期，用于用户重启或确认设置后的新节奏。
    private func nextTargetFromNow() -> Date {
        Date().addingTimeInterval(interval)
    }

    // 优先沿用上一次目标时间推进，避免回调执行时间影响提醒节奏。
    private func nextTargetAfterFire(previousTarget: Date?) -> Date {
        let now = Date()
        guard let previousTarget else {
            return now.addingTimeInterval(interval)
        }

        let next = previousTarget.addingTimeInterval(interval)
        return next > now ? next : now.addingTimeInterval(interval)
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

            let firedTarget = self.targetDate

            // [EN] Fire the callback on the main thread (UI updates must happen there).
            // [CN] 在主线程触发回调（UI 更新必须在此进行）。
            // [JP] メインスレッドでコールバックを実行（UI更新はここで行うこと）。
            DispatchQueue.main.async {
                self.onFlash?()
            }

            // [EN] Advance by one full interval from the previous target so cadence stays
            //      anchored to the user's reset moment.
            // [CN] 从上一次目标时间推进一个完整间隔，让节奏锚定在用户重置的那一刻。
            // [JP] 前回の目標時刻から完全な間隔を進め、ユーザーのリセット時点にリズムを固定する。
            self.targetDate = self.nextTargetAfterFire(previousTarget: firedTarget)
            self.scheduleNextLocked()
        }
        t.resume()
        timer = t
    }

    // 仅在串行队列内取消底层计时器，避免跨线程重复 cancel。
    private func cancelTimerLocked() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    // MARK: - 对外接口

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

    /// [EN] Start a fresh full interval from the exact user action moment.
    ///      Used after confirming settings or turning reminders back on.
    /// [CN] 从用户动作发生的那一刻开始一个全新的完整间隔。
    ///      用于确认设置或重新开启提醒后。
    /// [JP] ユーザー操作の瞬間から新しい完全なインターバルを開始する。
    ///      設定確定やリマインダー再有効化後に使用する。
    func restart(interval newInterval: TimeInterval? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if let newInterval {
                self.interval = max(newInterval, TimeInterval(Constants.intervalMinMinutes * 60))
            }
            self.isPaused = false
            let next = self.nextTargetFromNow()
            self.targetDate = next
            self.armTimerLocked(for: next)
            print("[Distracted] Timer restarted — next flash at \(next.formatted(date: .omitted, time: .standard))")
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

    /// [EN] Change the interval at runtime and start a fresh full interval from now.
    /// [CN] 运行时修改间隔，并从当前时刻开始一个完整的新周期。
    /// [JP] 実行中に間隔を変更し、現在時刻から完全な新周期を開始する。
    func setInterval(_ newInterval: TimeInterval) {
        restart(interval: newInterval)
    }
}
