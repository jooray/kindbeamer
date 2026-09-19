import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "dev.stkn.kindbeamer/intake",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "takePendingFiles" {
        result(FileIntake.shared.takePending())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    FileIntake.shared.attach(channel: channel)

    super.awakeFromNib()
  }
}
