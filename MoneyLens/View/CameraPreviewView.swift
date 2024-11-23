import SwiftUI
import AVFoundation

class CameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    init(session: AVCaptureSession) {
        print("DEBUG: Initializing CameraPreviewView")
        super.init(frame: .zero)
        videoPreviewLayer.session = session
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.connection?.videoOrientation = .portrait
        backgroundColor = .black
        print("DEBUG: CameraPreviewView initialized with session")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        print("DEBUG: CameraPreviewView layoutSubviews called, frame: \(frame)")
        videoPreviewLayer.frame = bounds
    }
}
