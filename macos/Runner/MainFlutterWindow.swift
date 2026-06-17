import AVFoundation
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerThumbnailChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  private func registerThumbnailChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "gtube/thumbnail", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "generate", let path = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      // Generate on a background thread so UI never blocks.
      DispatchQueue.global(qos: .userInitiated).async {
        let data = MainFlutterWindow.generateThumbnail(path: path)
        DispatchQueue.main.async {
          if let data {
            result(FlutterStandardTypedData(bytes: data))
          } else {
            result(nil)
          }
        }
      }
    }
  }

  private static func generateThumbnail(path: String) -> Data? {
    let url = URL(fileURLWithPath: path)
    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 240, height: 240)

    // Try at 0 s; fall back to 1 s if the first frame isn't ready.
    for seconds in [0.0, 1.0] {
      let time = CMTime(seconds: seconds, preferredTimescale: 600)
      if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(
          using: .jpeg,
          properties: [.compressionFactor: NSNumber(value: 0.72)]
        )
      }
    }
    return nil
  }
}
