import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(LocalizedStrings.language[viewModel.currentLanguage] ?? "Language")) {
                    Picker("Language", selection: $viewModel.currentLanguage) {
                        ForEach([Language.english, Language.turkish], id: \.self) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStrings.settings[viewModel.currentLanguage] ?? "Settings")
        }
    }
}