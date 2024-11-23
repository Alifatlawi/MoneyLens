import SwiftUI

struct HomeView: View {
    @StateObject private var settingsVM = SettingsViewModel()
    @StateObject private var cameraVM: CameraViewModel
    
    init() {
        let settings = SettingsViewModel()
        _settingsVM = StateObject(wrappedValue: settings)
        _cameraVM = StateObject(wrappedValue: CameraViewModel(settingsViewModel: settings))
    }
    
    var body: some View {
        TabView {
            CameraView(viewModel: cameraVM)
                .tabItem {
                    Image(systemName: "camera")
                    Text(LocalizedStrings.camera[settingsVM.currentLanguage] ?? "Camera")
                }
                .ignoresSafeArea()
                .tag(0)
            
            SettingsView(viewModel: settingsVM)
                .tabItem {
                    Image(systemName: "gear")
                    Text(LocalizedStrings.settings[settingsVM.currentLanguage] ?? "Settings")
                }
                .tag(1)
        }
        .environmentObject(settingsVM)
        .accentColor(.blue)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .systemBackground
            
            UITabBar.appearance().scrollEdgeAppearance = appearance
            UITabBar.appearance().standardAppearance = appearance
        }
    }
}

#Preview {
    HomeView()
}