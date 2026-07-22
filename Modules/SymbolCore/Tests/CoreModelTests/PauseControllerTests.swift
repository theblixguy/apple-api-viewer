import CoreModel
import Testing

@Suite("Pause controller", .tags(.indexing))
struct PauseControllerTests {
  @Test("Wait returns immediately when not paused")
  func returnsImmediatelyWhenNotPaused() async {
    let controller = PauseController()
    await controller.waitWhilePaused()
  }

  @Test("Resume releases a waiter")
  func resumeReleasesAWaiter() async {
    let controller = PauseController()
    await controller.pause()
    let waiter = Task { () -> Bool in
      await controller.waitWhilePaused()
      return true
    }
    await controller.resume()
    #expect(await waiter.value)
  }

  @Test("Cancellation releases a paused waiter")
  func cancellationReleasesAPausedWaiter() async {
    let controller = PauseController()
    await controller.pause()
    let waiter = Task { () -> Bool in
      await controller.waitWhilePaused()
      return true
    }
    waiter.cancel()
    #expect(await waiter.value)
  }
}
