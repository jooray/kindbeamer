import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    // The command line reaches `main(args)` only when handed over explicitly;
    // that is what `--send` and the file paths after it travel on.
    let project = FlutterDartProject()
    project.dartEntrypointArguments = MainFlutterWindow.dartArguments(CommandLine.arguments)
    let flutterViewController = FlutterViewController(project: project)
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

  /// argv without the executable and the options Cocoa adds on its own
  /// (`-psn_…` from older Finders, `-NSDocumentRevisionsDebugMode YES` and the
  /// like from Xcode).
  static func dartArguments(_ argv: [String]) -> [String] {
    var out: [String] = []
    var i = 1
    while i < argv.count {
      let a = argv[i]
      if a.hasPrefix("-psn_") {
        i += 1
      } else if (a.hasPrefix("-NS") || a.hasPrefix("-Apple")) && !a.hasPrefix("--") {
        i += 2
      } else {
        out.append(a)
        i += 1
      }
    }
    return out
  }
}
