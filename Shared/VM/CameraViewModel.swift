import CoreImage
import Vision
import SwiftUI

class CameraViewModel: ObservableObject {
    @Published var error: Error?
    @Published var frame: CGImage?
    
    @Published var detectedDescription: String = ""
    
    private var isDetecting = false
    
    private let context = CIContext()
    
    private let cameraManager = CameraManager.shared
    private let frameManager = FrameManager.shared
    
    init() {
        setupSubscriptions()
    }
    
    func setupSubscriptions() {
        cameraManager.$error
            .receive(on: RunLoop.main)
            .map { $0 }
            .assign(to: &$error)
        
        frameManager.$current
            .receive(on: RunLoop.main)
            .compactMap { buffer in
                guard let image = CGImage.create(from: buffer) else {
                    return nil
                }
                
                let ciImage = CIImage(cgImage: image)
                self.runDetector()
                
                return self.context.createCGImage(ciImage, from: ciImage.extent)
            }
            .assign(to: &$frame)
    }
    
    func runDetector() {
        guard !isDetecting, let model = try? VNCoreMLModel(for: BeerImageModel(configuration: .init()).model) else {
            print("MODEL ERROR")
            return
        }
        
        guard let frame = frame else {
            print("IMAGE ERROR")
            return
        }
        
        let image = UIImage(cgImage: frame)
        
        isDetecting = true
        
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            if let observations = request.results as? [VNClassificationObservation] {
                let top3 = observations.prefix(through: 2)
                    .map { ($0.identifier, Double($0.confidence)) }
                print(observations)
                //var label = ""
                //for place in top3 {
                let split = top3[0].0.split(separator: "\t")
                print(split)
                self?.detectedDescription = split.joined(separator: "\n")
                //}
                
                self?.isDetecting = false
            }
        }
        
        request.imageCropAndScaleOption = .centerCrop
        
        let handler = VNImageRequestHandler(cgImage: image.cgImage!)
        
        try? handler.perform([request])
    }
    
    func continueDetector() {
        
    }
}
