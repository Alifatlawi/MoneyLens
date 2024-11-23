import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    @ObservedObject var viewModel: CameraViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    
    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView(session: viewModel.captureSession)
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.videoPreviewLayer.frame = uiView.bounds
    }
}

// Add overlay view for detected amount
struct CameraOverlayView: View {
    @ObservedObject var viewModel: CameraViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    
    var body: some View {
        ZStack {
            if !viewModel.detectedAmount.isEmpty {
                VStack {
                    Spacer()
                    Text(LocalizedStrings.denominationText(viewModel.detectedAmount, 
                         language: settingsVM.currentLanguage))
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .transition(.opacity)
                        .animation(.easeInOut, value: viewModel.detectedAmount)
                }
                .padding(.bottom, 50)
            }
        }
    }
}

