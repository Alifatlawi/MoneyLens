import Foundation

public class SettingsViewModel: ObservableObject {
    @Published public var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "AppLanguage")
        }
    }
    
    public init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage") ?? Language.english.rawValue
        currentLanguage = Language(rawValue: savedLanguage) ?? .english
    }
}