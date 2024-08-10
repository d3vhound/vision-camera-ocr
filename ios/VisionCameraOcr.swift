import Vision
import AVFoundation
import MLKitVision
import MLKitTextRecognition
import CoreImage
import UIKit

@objc(OCRFrameProcessorPlugin)
public class OCRFrameProcessorPlugin: FrameProcessorPlugin {
    private static func orientationToString(_ orientation: UIImage.Orientation) -> String {
        switch orientation {
            case .up: return "up"
            case .down: return "down"
            case .left: return "left"
            case .right: return "right"
            case .upMirrored: return "upMirrored"
            case .downMirrored: return "downMirrored"
            case .leftMirrored: return "leftMirrored"
            case .rightMirrored: return "rightMirrored"
        @unknown default:
            return "unknown"
        }
    }
    
    private static let textRecognizer = TextRecognizer.textRecognizer(options: TextRecognizerOptions.init())
    
    private static func getBlockArray(_ blocks: [TextBlock]) -> [[String: Any]] {
        
        var blockArray: [[String: Any]] = []
        
        for block in blocks {
            blockArray.append([
                "text": block.text,
                "recognizedLanguages": getRecognizedLanguages(block.recognizedLanguages),
                "cornerPoints": getCornerPoints(block.cornerPoints),
                "frame": getFrame(block.frame),
                "boundingBox": getBoundingBox(block.frame) as Any,
                "lines": getLineArray(block.lines),
            ])
        }
        
        return blockArray
    }
    
    private static func getLineArray(_ lines: [TextLine]) -> [[String: Any]] {
        
        var lineArray: [[String: Any]] = []
        
        for line in lines {
            lineArray.append([
                "text": line.text,
                "recognizedLanguages": getRecognizedLanguages(line.recognizedLanguages),
                "cornerPoints": getCornerPoints(line.cornerPoints),
                "frame": getFrame(line.frame),
                "boundingBox": getBoundingBox(line.frame) as Any,
                "elements": getElementArray(line.elements),
            ])
        }
        
        return lineArray
    }
    
    private static func getElementArray(_ elements: [TextElement]) -> [[String: Any]] {
        
        var elementArray: [[String: Any]] = []
        
        for element in elements {
            elementArray.append([
                "text": element.text,
                "cornerPoints": getCornerPoints(element.cornerPoints),
                "frame": getFrame(element.frame),
                "boundingBox": getBoundingBox(element.frame) as Any,
                "symbols": []
            ])
        }
        
        return elementArray
    }
    
    private static func getRecognizedLanguages(_ languages: [TextRecognizedLanguage]) -> [String] {
        
        var languageArray: [String] = []
        
        for language in languages {
            guard let code = language.languageCode else {
                print("No language code exists")
                break;
            }
            languageArray.append(code)
        }
        
        return languageArray
    }
    
    private static func getCornerPoints(_ cornerPoints: [NSValue]) -> [[String: CGFloat]] {
        
        var cornerPointArray: [[String: CGFloat]] = []
        
        for cornerPoint in cornerPoints {
            guard let point = cornerPoint as? CGPoint else {
                print("Failed to convert corner point to CGPoint")
                break;
            }
            cornerPointArray.append([ "x": point.x, "y": point.y])
        }
        
        return cornerPointArray
    }
    
    private static func getFrame(_ frameRect: CGRect) -> [String: CGFloat] {
        
        let offsetX = (frameRect.midX - ceil(frameRect.width)) / 2.0
        let offsetY = (frameRect.midY - ceil(frameRect.height)) / 2.0

        let x = frameRect.maxX + offsetX
        let y = frameRect.minY + offsetY

        return [
          "x": frameRect.midX + (frameRect.midX - x),
          "y": frameRect.midY + (y - frameRect.midY),
          "width": frameRect.width,
          "height": frameRect.height,
          "boundingCenterX": frameRect.midX,
          "boundingCenterY": frameRect.midY
        ]
    }
    
    private static func getBoundingBox(_ rect: CGRect?) -> [String: CGFloat]? {
         return rect.map {[
             "left": $0.minX,
             "top": $0.maxY,
             "right": $0.maxX,
             "bottom": $0.minY
         ]}
    }

    func getOrientation(
        orientation: UIImage.Orientation
    ) -> UIImage.Orientation {
        switch orientation {
        case .up:
            // device is landscape left
            return .up
        case .left:
        // device is portrait
            return .right
        case .down:
            // device is landscape right
            return .down
        case .right:
            // device is upside-down
            return .left
        default:
                return .up
            }
        }
    
    public override func callback(_ frame: Frame, withArguments arguments: [AnyHashable: Any]?) -> Any? {
        let orientation = getOrientation(
            orientation: frame.orientation
        )
        let visionImage = VisionImage(buffer: frame.buffer)
        visionImage.orientation = orientation

        var result: Text
        
        do {
          result = try OCRFrameProcessorPlugin.textRecognizer.results(in: visionImage)
        } catch let error {
          print("Failed to recognize text with error: \(error.localizedDescription).")
          return nil
        }
        
        return [
            "result": [
                "text": result.text,
                "blocks": OCRFrameProcessorPlugin.getBlockArray(result.blocks),
                "orientation": OCRFrameProcessorPlugin.orientationToString(visionImage.orientation),
                "og-orientation": OCRFrameProcessorPlugin.orientationToString(frame.orientation)
            ]
        ]
    }
}
