import Cocoa
import FlutterMacOS

/// Collects file paths handed to the app by macOS (Services menu, "Open With",
/// dock drops) and forwards them to Dart.
///
/// Files can arrive before the Flutter engine is up — during launch the paths
/// are queued and Dart pulls them with `takePendingFiles`; afterwards they are
/// pushed over the same channel.
class FileIntake: NSObject {
  static let shared = FileIntake()

  private var pending: [String] = []
  private let lock = NSLock()
  private var channel: FlutterMethodChannel?

  func attach(channel: FlutterMethodChannel) {
    lock.lock()
    self.channel = channel
    lock.unlock()
  }

  /// Queues paths and nudges Dart to drain the queue. Dart owns the draining so
  /// nothing is lost while the engine is still starting up.
  func add(paths: [String]) {
    guard !paths.isEmpty else { return }
    lock.lock()
    pending.append(contentsOf: paths)
    let channel = self.channel
    lock.unlock()
    if let channel = channel {
      DispatchQueue.main.async {
        channel.invokeMethod("filesAvailable", arguments: nil)
      }
    }
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

  @objc func sendFilesToKindle(_ pboard: NSPasteboard, userData: String, error: NSErrorPointer) {
    guard let urls = pboard.readObjects(
      forClasses: [NSURL.self],
      options: [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly: true]
    ) as? [NSURL] else {
      return
    }
    add(paths: urls.compactMap { $0.path })
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
    NSApp.servicesProvider = FileIntake.shared
  }

  /// Finder "Open With", dock drops and `open -a KindBeamer file.pdf`.
  override func application(_ application: NSApplication, open urls: [URL]) {
    super.application(application, open: urls)
    FileIntake.shared.add(paths: urls.filter { $0.isFileURL }.map { $0.path })
  }
}
