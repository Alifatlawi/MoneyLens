//
//  ContentView.swift
//  MoneyLens
//
//  Created by BLG-BC-018 on 22.11.2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var settingsVM = SettingsViewModel()
    @StateObject private var cameraViewModel: CameraViewModel
    @State private var showingSplash = true
    @State private var selectedTab = 0
    
    init() {
        let settings = SettingsViewModel()
        _settingsVM = StateObject(wrappedValue: settings)
        _cameraViewModel = StateObject(wrappedValue: CameraViewModel(settingsViewModel: settings))
    }
    
    var body: some View {
        Group {
            if showingSplash {
                SplashScreen()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showingSplash = false
                            }
                        }
                    }
            } else {
                TabView(selection: $selectedTab) {
                    // Camera Tab
                    ZStack {
                        if cameraViewModel.permissionGranted {
                            CameraView(viewModel: cameraViewModel)
                                .edgesIgnoringSafeArea(.all)
                            
                            VStack {
                                Spacer()
                                if !cameraViewModel.detectedAmount.isEmpty {
                                    Text(LocalizedStrings.denominationText(
                                        cameraViewModel.detectedAmount,
                                        language: settingsVM.currentLanguage
                                    ))
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(10)
                                    .transition(.opacity)
                                    .animation(.easeInOut, value: cameraViewModel.detectedAmount)
                                }
                            }
                            .padding(.bottom, 50)
                        } else {
                            if let error = cameraViewModel.error {
                                VStack {
                                    Image(systemName: "camera.slash.fill")
                                        .font(.largeTitle)
                                        .padding()
                                    Text(error)
                                        .multilineTextAlignment(.center)
                                        .padding()
                                    Button(LocalizedStrings.openSettings[settingsVM.currentLanguage] ?? "Open Settings") {
                                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(settingsUrl)
                                        }
                                    }
                                    .padding()
                                }
                            } else {
                                ProgressView(LocalizedStrings.requestingAccess[settingsVM.currentLanguage] ?? "Requesting camera access...")
                            }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(LocalizedStrings.accessibilityLabel[settingsVM.currentLanguage] ?? "Camera view for detecting Turkish Lira")
                    .accessibilityHint(LocalizedStrings.accessibilityHint[settingsVM.currentLanguage] ?? "Point the camera at Turkish Lira bills to detect their value")
                    .onAppear {
                        cameraViewModel.setupSession()
                    }
                    .tabItem {
                        Image(systemName: "camera")
                        Text(LocalizedStrings.camera[settingsVM.currentLanguage] ?? "Camera")
                    }
                    .tag(0)
                    
                    // Settings Tab
                    SettingsView(viewModel: settingsVM)
                        .tabItem {
                            Image(systemName: "gear")
                            Text(LocalizedStrings.settings[settingsVM.currentLanguage] ?? "Settings")
                        }
                        .tag(1)
                }
                .onChange(of: selectedTab) { newTab in
                    if newTab == 1 {
                        cameraViewModel.pauseSession()
                    } else {
                        cameraViewModel.resumeSession()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
