import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ReceiptText") {
      ReceiptText.register(messenger: registrar.messenger())
    }
  }
}

/// On-device receipt text recognition with Apple Vision. Nothing leaves the phone.
/// Returns one entry per recognized line: text plus its box (top-left origin, 0...1).
enum ReceiptText {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "expensetracker/receipt_text", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognize",
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        let lines = recognize(path: path)
        DispatchQueue.main.async { result(lines) }
      }
    }
  }

  private static func recognize(path: String) -> [[String: Any]] {
    guard let image = UIImage(contentsOfFile: path), let cg = image.cgImage else { return [] }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    let handler = VNImageRequestHandler(
      cgImage: cg, orientation: CGImagePropertyOrientation(image.imageOrientation), options: [:])
    do {
      try handler.perform([request])
    } catch {
      return []
    }
    return (request.results ?? []).compactMap { obs in
      guard let text = obs.topCandidates(1).first?.string else { return nil }
      let b = obs.boundingBox
      return ["text": text, "x": b.minX, "y": 1 - b.maxY, "w": b.width, "h": b.height]
    }
  }
}

extension CGImagePropertyOrientation {
  init(_ o: UIImage.Orientation) {
    switch o {
    case .up: self = .up
    case .upMirrored: self = .upMirrored
    case .down: self = .down
    case .downMirrored: self = .downMirrored
    case .left: self = .left
    case .leftMirrored: self = .leftMirrored
    case .right: self = .right
    case .rightMirrored: self = .rightMirrored
    @unknown default: self = .up
    }
  }
}
