import Foundation
import VisionCamera

@objc(VisionCameraHearthRate)
public class VisionCameraHearthRate: FrameProcessorPlugin {
  static var pulseDetector = PulseDetector()
  static var hueFilter = Filter()

  static var BPM: Int = 0;
  static var state: String = "RECORDING";
  static var validFrameCounter = 0

  public override init(proxy: VisionCameraProxyHolder, options: [AnyHashable : Any]! = [:]) {
      super.init(proxy: proxy, options: options)
  }
  
  public override func callback(_ frame: Frame, withArguments arguments: [AnyHashable : Any]?) -> Any? {
    var redmean: CGFloat = 0.0;
    var greenmean: CGFloat = 0.0;
    var bluemean: CGFloat = 0.0;

    guard let pixelBuffer = CMSampleBufferGetImageBuffer(frame.buffer) else {
      print("Failed to get CVPixelBuffer!")
      return nil
    }
    let cameraImage = CIImage(cvPixelBuffer: pixelBuffer)

    if ((arguments?.isEmpty) == nil) {
      if let shouldReset = arguments?[0] as? NSString {
        if shouldReset == "true" {
          VisionCameraHearthRate.validFrameCounter = 0
          VisionCameraHearthRate.pulseDetector.reset()
          VisionCameraHearthRate.state = "BEGIN"
          VisionCameraHearthRate.BPM = 0
        }
      }
    }

    let extent = cameraImage.extent
    let inputExtent = CIVector(x: extent.origin.x, y: extent.origin.y, z: extent.size.width, w: extent.size.height)
    let averageFilter = CIFilter(name: "CIAreaAverage",
                                 parameters: [kCIInputImageKey: cameraImage, kCIInputExtentKey: inputExtent])!
    let outputImage = averageFilter.outputImage!

    let ctx = CIContext(options:nil)
    let cgImage = ctx.createCGImage(outputImage, from:outputImage.extent)!

    let rawData:NSData = cgImage.dataProvider!.data!
    let pixels = rawData.bytes.assumingMemoryBound(to: UInt8.self)
    let bytes = UnsafeBufferPointer<UInt8>(start:pixels, count:rawData.length)
    var BGRA_index = 0
    for pixel in UnsafeBufferPointer(start: bytes.baseAddress, count: bytes.count) {
      switch BGRA_index {
      case 0:
        redmean = CGFloat (pixel)
      case 1:
        greenmean = CGFloat (pixel)
      case 2:
        bluemean = CGFloat (pixel)
      case 3:
        break
      default:
        break
      }
      BGRA_index += 1
    }
    var filtered = 0.0
    let hsv = rgb2hsv((red: redmean, green: greenmean, blue: bluemean, alpha: 1.0))
    if (hsv.1 > 0.5 && hsv.2 > 0.5) { // finger on the camera
      VisionCameraHearthRate.state = "RECORDING"
      VisionCameraHearthRate.BPM = lroundf(60.0/VisionCameraHearthRate.pulseDetector.getAverage())
      VisionCameraHearthRate.validFrameCounter += 1

      // Filter the hue value - the filter is a simple BAND PASS FILTER that removes any DC component and any high frequency noise
      if VisionCameraHearthRate.validFrameCounter > 60 {
        filtered = VisionCameraHearthRate.hueFilter.processValue(value: Double(hsv.0))
        VisionCameraHearthRate.pulseDetector.addNewValue(newVal: filtered, atTime: CACurrentMediaTime())
      }
    } else {
      VisionCameraHearthRate.validFrameCounter = 0
      VisionCameraHearthRate.pulseDetector.reset()
      VisionCameraHearthRate.state = "BEGIN"
      VisionCameraHearthRate.BPM = 0
    }

    return [
      "hue": hsv.0,
      "saturation": hsv.1,
      "brightness": hsv.2,
      "filtered": filtered,
      "red": redmean,
			"blue": bluemean,
			"green": greenmean,
			"time": Date().timeIntervalSince1970,
      "BPM": VisionCameraHearthRate.BPM,
      "state": VisionCameraHearthRate.state,
      "count": VisionCameraHearthRate.validFrameCounter
    ]
  }
}
