import Foundation

public enum Language: String {
    case english = "en"
    case turkish = "tr"
    
    public var displayName: String {
        switch self {
        case .english: return "English"
        case .turkish: return "Türkçe"
        }
    }
}

public struct LocalizedStrings {
    public static func denominationText(_ amount: String, language: Language) -> String {
        let number = amount.components(separatedBy: "-")[0]
        
        switch language {
        case .english:
            return "\(number) Turkish Lira"
        case .turkish:
            return "\(number) Türk Lirası"
        }
    }
    
    public static let settings: [Language: String] = [
        .english: "Settings",
        .turkish: "Ayarlar"
    ]
    
    public static let language: [Language: String] = [
        .english: "Language",
        .turkish: "Dil"
    ]
    
    public static let camera: [Language: String] = [
        .english: "Camera",
        .turkish: "Kamera"
    ]
    
    public static let openSettings: [Language: String] = [
        .english: "Open Settings",
        .turkish: "Ayarları Aç"
    ]
    
    public static let requestingAccess: [Language: String] = [
        .english: "Requesting camera access...",
        .turkish: "Kamera izni isteniyor..."
    ]
    
    public static let accessibilityLabel: [Language: String] = [
        .english: "Camera view for detecting Turkish Lira",
        .turkish: "Türk Lirası tespit etmek için kamera görünümü"
    ]
    
    public static let accessibilityHint: [Language: String] = [
        .english: "Point the camera at Turkish Lira bills to detect their value",
        .turkish: "Değerini tespit etmek için kamerayı Türk Lirası banknotlarına doğrultun"
    ]
}