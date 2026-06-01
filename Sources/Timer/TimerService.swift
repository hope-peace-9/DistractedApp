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
                                      qos: .background)

    /// [EN] Absolute timestamp of the *next* scheduled flash.
    /// [CN] *下次*触发闪烁的绝对时间戳。
    /// [JP] *次回*点滅の絶対タイムスタンプ。
    private var nextFlashTimestamp: Date?

    /// [EN] Current interval in seconds.
    /// [CN] 当前间隔（秒）。
    /// [JP] 現在の間隔（秒）。
    private var interval: TimeInterval

    /// [EN] Callback invoked on the main thread when it's time to flash.
    /// [CN] 闪烁触发时在主线程执行的回调。
    /// [JP] 点滅時にメインスレッドで実行されるコールバック。
    private var onFlash: (() -> Void)?

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

        // [EN] Log effective interval at startup for debugging.
        // [CN] 启动时记录实际间隔，方便调试。
        // [JP] 起動時に有効な間隔を記録（デバッグ用）。
        print("[Distracted] TimerService initialised — interval: \(Int(interval))s")

        scheduleNext()
    }

    deinit {
        timer?.cancel()
    }

    // MARK: - Scheduling (private)

    /// [EN] Schedule the next flash based on the stored absolute timestamp,
    ///      or compute the next interval boundary from now if no future target exists.
    /// [CN] 基于绝对时间戳调度下次闪烁；如无有效未来目标则从现在起计算。
    /// [JP] 保存された絶対タイムスタンプに基づき次回点滅を予約。
    ///      未来の目標がない場合は現在時刻から再計算。
    private func scheduleNext() {
        let now = Date()

        if let next = nextFlashTimestamp, next > now {
            armTimer(for: next)
        } else {
            let next = nextIntervalBoundary(after: now)
            nextFlashTimestamp = next
            armTimer(for: next)
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

    /// [EN] Create a one-shot DispatchSourceTimer that fires at the given Date.
    /// [CN] 创建一个在指定日期触发的一次性 DispatchSourceTimer。
    /// [JP] 指定された Date に発火する単発 DispatchSourceTimer を作成。
    private func armTimer(for date: Date) {
        timer?.cancel()

        let delay = max(date.timeIntervalSinceNow, 0.1)
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + delay, leeway: .milliseconds(100))
        t.setEventHandler { [weak self] in
            guard let self = self else { return }

            // [EN] Fire the callback on the main thread (UI updates must happen there).
            // [CN] 在主线程触发回调（UI 更新必须在此进行）。
            // [JP] メインスレッドでコールバックを実行（UI更新はここで行うこと）。
            DispatchQueue.main.async {
                self.onFlash?()
            }

            // [EN] Advance to the next boundary for the following tick.
            // [CN] 推进到下一个边界，准备下一轮触发。
            // [JP] 次回ティックのために次の境界に進める。
            self.nextFlashTimestamp = date.addingTimeInterval(self.interval)
            self.scheduleNext()
        }
        t.resume()
        timer = t
    }

    // MARK: - Public API

    /// [EN] Cancel pending timer. Called on sleep — preserves the missed target.
    /// [CN] 取消待执行的定时器。在系统休眠时调用——保留被跳过的目标时间戳。
    /// [JP] 保留中のタイマーをキャンセル。スリープ時に呼び出す——未達の目標は保持。
    func pause() {
        timer?.cancel()
        timer = nil
        print("[Distracted] Timer paused")
    }

    /// [EN] Recalibrate after wake: discard missed targets and schedule from now.
    /// [CN] 唤醒后重新校准：丢弃已经错过的目标时间戳，从现在开始重新调度。
    /// [JP] ウェイク後に再調整：未達の目標を破棄し現在時刻から再スケジュール。
    func recalibrate() {
        nextFlashTimestamp = nil
        scheduleNext()
        let nextStr = nextFlashTimestamp?.formatted(date: .omitted, time: .standard) ?? "?"
        print("[Distracted] Timer recalibrated — next flash at \(nextStr)")
    }

    /// [EN] Change the interval at runtime. Resets the schedule immediately.
    /// [CN] 运行时修改间隔。立即重置调度。
    /// [JP] 実行中に間隔を変更。即座にスケジュールをリセット。
    func setInterval(_ newInterval: TimeInterval) {
        interval = newInterval
        nextFlashTimestamp = nil
        scheduleNext()
        print("[Distracted] Interval updated to \(Int(newInterval))s — schedule reset")
    }
}
