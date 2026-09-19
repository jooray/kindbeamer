import Cocoa
import FlutterMacOS

class ServicesProvider: NSObject {
  static let shared = ServicesProvider()
  private var pending: [String] = []
  private let lock = NSLock()

  @objc func sendFilesToKindle(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
    guard let urls = pboard.readObjects(
      forClasses: [NSURL.self],
      options: [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly: true]
    ) as? [NSURL] else {
      return
    }
    let paths = urls.compactMap { $0.path }
    guard !paths.isEmpty else { return }
    lock.lock()
    pending.append(contentsOf: paths)
    lock.unlock()
    NSApp.activate(ignoringOtherApps: true)
  }

  func takePending() -> [String] {
    lock.lock()
    defer {
      pending = []
      lock.unlock()
    }
    return pending
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    NSApp.servicesProvider = ServicesProvider.shared
  }
}
