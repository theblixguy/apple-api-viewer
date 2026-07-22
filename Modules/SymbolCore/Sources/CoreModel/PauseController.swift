/// Pauses and resumes a long-running async operation.
///
/// The operation awaits ``waitWhilePaused()`` at safe checkpoints. While
/// paused, that call suspends, and ``resume()`` lets every waiter
/// continue. The wait is cancellation-safe. A canceled operation unwinds
/// even while paused.
public actor PauseController {
  private var isPaused = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  /// Creates an unpaused controller.
  public init() {}

  /// Holds later ``waitWhilePaused()`` calls until ``resume()``.
  public func pause() {
    isPaused = true
  }

  /// Ends the pause and wakes every waiter.
  public func resume() {
    isPaused = false
    wakeAll()
  }

  /// Suspends while paused, and returns at once otherwise.
  public func waitWhilePaused() async {
    guard isPaused else { return }
    await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        if isPaused, !Task.isCancelled {
          waiters.append(continuation)
        } else {
          continuation.resume()
        }
      }
    } onCancel: {
      Task { await self.wakeAll() }
    }
  }

  private func wakeAll() {
    let resumed = waiters
    waiters.removeAll()
    for continuation in resumed {
      continuation.resume()
    }
  }
}
