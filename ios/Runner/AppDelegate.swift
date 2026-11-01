import CoreMotion
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let calibratedMagnetometer = CalibratedMagnetometer()
  private let headingStream = HeadingStream()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CalibratedMagnetometer") {
      FlutterEventChannel(
        name: "exam_guard/magnetometer",
        binaryMessenger: registrar.messenger()
      ).setStreamHandler(calibratedMagnetometer)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HeadingStream") {
      FlutterEventChannel(
        name: "exam_guard/heading",
        binaryMessenger: registrar.messenger()
      ).setStreamHandler(headingStream)
    }
  }
}

/// Streams Core Motion's *calibrated* magnetic field (device bias removed)
/// as [x, y, z (µT), accuracy, timestamp]. The raw magnetometer that
/// plugins use on iOS includes the phone's own bias — often hundreds of µT —
/// so rotating the phone alone would look like a magnet.
/// accuracy: -1 uncalibrated, 0 low, 1 medium, 2 high.
final class CalibratedMagnetometer: NSObject, FlutterStreamHandler {
  private let motion = CMMotionManager()

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    guard motion.isDeviceMotionAvailable else {
      return FlutterError(
        code: "unavailable",
        message: "Device motion is not available",
        details: nil
      )
    }
    // The magnetic field is only filled in with a magnetometer-corrected
    // reference frame.
    let available = CMMotionManager.availableAttitudeReferenceFrames()
    let frame: CMAttitudeReferenceFrame =
      available.contains(.xArbitraryCorrectedZVertical)
      ? .xArbitraryCorrectedZVertical
      : .xMagneticNorthZVertical
    guard available.contains(frame) else {
      return FlutterError(
        code: "unavailable",
        message: "No magnetometer reference frame",
        details: nil
      )
    }
    motion.deviceMotionUpdateInterval = 1.0 / 50.0
    motion.startDeviceMotionUpdates(using: frame, to: OperationQueue.main) { data, error in
      if let error = error {
        events(FlutterError(code: "error", message: error.localizedDescription, details: nil))
        return
      }
      guard let data = data else { return }
      let m = data.magneticField
      events([
        m.field.x, m.field.y, m.field.z,
        Int(m.accuracy.rawValue),
        data.timestamp,
      ])
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    motion.stopDeviceMotionUpdates()
    return nil
  }
}

/// Compass heading of the phone's top edge (degrees from magnetic north,
/// tilt-compensated by Core Motion) as [degrees, accuracy] ~20 times a
/// second. accuracy: -1 uncalibrated, 0 low, 1 medium, 2 high.
final class HeadingStream: NSObject, FlutterStreamHandler {
  private let motion = CMMotionManager()

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    guard motion.isDeviceMotionAvailable,
      CMMotionManager.availableAttitudeReferenceFrames().contains(.xMagneticNorthZVertical)
    else {
      return FlutterError(
        code: "unavailable",
        message: "No compass heading on this device",
        details: nil
      )
    }
    motion.deviceMotionUpdateInterval = 1.0 / 20.0
    motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: OperationQueue.main) {
      data, error in
      if let error = error {
        events(FlutterError(code: "error", message: error.localizedDescription, details: nil))
        return
      }
      guard let data = data else { return }
      events([data.heading, Int(data.magneticField.accuracy.rawValue)])
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    motion.stopDeviceMotionUpdates()
    return nil
  }
}
