import SwiftUI

struct SplashScreen: View {
    @State private var isLoading = true
    @State private var scale: CGFloat = 0.7
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .scaleEffect(scale)
                    .animation(.easeInOut(duration: 1.0).repeatForever(), value: scale)
                
                Text("MoneyLens")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding(.top)
            }
        }
        .onAppear {
            scale = 1.0
        }
    }
}