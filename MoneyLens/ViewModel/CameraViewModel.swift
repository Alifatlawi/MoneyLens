//
//  CameraViewModel.swift
//  MoneyLens
//
//  Created by BLG-BC-018 on 22.11.2024.
//

import Foundation
import AVFoundation
import CoreImage
import Vision
import SwiftUI

class CameraViewModel: NSObject, ObservableObject {
    @Published var detectedAmount: String = ""
    @Published var permissionGranted: Bool = false
    @Published var isSessionRunning: Bool = false
    @Published var error: String?
    @Published var frame: CGImage?
    @Published var detectionResults: [(label: String, confidence: Float)] = []
    
    let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue", qos: .userInteractive)
    private let processingQueue = DispatchQueue(label: "processingQueue", qos: .userInitiated, attributes: .concurrent)
    private let speechSynthesizer = AVSpeechSynthesizer()
    private weak var settingsViewModel: SettingsViewModel?
    private var lastDetectedAmount = ""
    private var consecutiveDetections = 0
    private var requiredConsecutiveDetections = 3
    private let minimumConfidence: Float = 0.8
    private var isProcessing = false {
        didSet {
            print("DEBUG: Processing state changed to: \(isProcessing)")
        }
    }
    private var detectionHistory: [String: Int] = [:] // Track detection history
    private var recentDetections: [String] = [] // Store recent detections
    private var lastDetectionTime: CFTimeInterval = 0
    private let detectionInterval: CFTimeInterval = 0.4
    private let historyWindowSize = 10
    private let imageContext = CIContext(options: [.useSoftwareRenderer: false])
    private var lastProcessedImage: CGImage?
    private let consecutiveThreshold200TL = 3  // Require more consecutive detections for 200 TL
    private var lastConfidences: [(String, Float)] = []
    private let confidenceHistorySize = 5
    private let denominationThresholds: [String: Float] = [
        "5-tl": 0.90,
        "10-tl": 0.90,
        "20-tl": 0.92,
        "50-tl": 0.93,
        "100-tl": 0.94,
        "200-tl": 0.85
    ]
    private let consecutiveHighConfidenceRequired = 5
    private let minimumStableDetections = 4
    private let highValueConfidenceWindow = 8
    private let highValueConfidenceThreshold: Float = 0.999  // Very high confidence required
    private let minimumConsecutiveDetections = 8  // Require 8 consecutive detections
    private let maxCompetingDetectionConfidence: Float = 0.3  // Limit competing detections
    
    init(settingsViewModel: SettingsViewModel) {
        self.settingsViewModel = settingsViewModel
        super.init()
        setupSession()
    }
    
    private let banknoteCharacteristics: [String: (width: Double, height: Double)] = [
        "5-tl": (130, 64),
        "10-tl": (136, 64),
        "20-tl": (142, 68),
        "50-tl": (148, 68),
        "100-tl": (154, 72),
        "200-tl": (160, 76)
    ]
    
    private let requiredDetectionsPerDenomination: [String: Int] = [
         "5-tl": 3,
         "10-tl": 3,
         "20-tl": 4,
         "50-tl": 4,
         "100-tl": 5,
         "200-tl": 7
     ]
     
    
    func setupSession() {
        print("DEBUG: Starting setup session")
        sessionQueue.async { [weak self] in
            self?.checkPermission()
        }
    }
    
    private func startSession() {
        print("DEBUG: Starting capture session")
        guard !captureSession.isRunning else {
            print("DEBUG: Session already running")
            return
        }
        
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
            print("DEBUG: Capture session started running")
            DispatchQueue.main.async {
                self?.isSessionRunning = true
            }
        }
    }
    
    private func stopSession() {
        guard captureSession.isRunning else { return }
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = false
            }
        }
    }
    
    private func setupCaptureSession() {
        print("DEBUG: Setting up capture session")
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            print("DEBUG: Configuring capture session")
            
            self.captureSession.beginConfiguration()
            
            // Remove any existing inputs and outputs
            for input in self.captureSession.inputs {
                self.captureSession.removeInput(input)
            }
            for output in self.captureSession.outputs {
                self.captureSession.removeOutput(output)
            }
            
            // Set the preset first
            if self.captureSession.canSetSessionPreset(.high) {
                self.captureSession.sessionPreset = .high
                print("DEBUG: Set session preset to high")
            }
            
            // Configure video input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
                print("DEBUG: Failed to setup video input")
                DispatchQueue.main.async {
                    self.error = "Failed to setup camera input."
                }
                self.captureSession.commitConfiguration()
                return
            }
            
            print("DEBUG: Video input created successfully")
            
            // Add input and output
            if self.captureSession.canAddInput(videoInput) {
                self.captureSession.addInput(videoInput)
                print("DEBUG: Added video input to session")
            }
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: self.processingQueue)
            
            if self.captureSession.canAddOutput(videoOutput) {
                self.captureSession.addOutput(videoOutput)
                print("DEBUG: Added video output to session")
            }
            
            self.captureSession.commitConfiguration()
            print("DEBUG: Committed session configuration")
            
            // Start the session after configuration is committed
            self.startSession()
        }
    }
    
    
    private func checkPermission() {
        print("DEBUG: Checking camera permission")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("DEBUG: Camera permission already authorized")
            DispatchQueue.main.async { [weak self] in
                self?.permissionGranted = true
                // Wait for permission to be set before setting up session
                self?.setupCaptureSession()
            }
        case .notDetermined:
            print("DEBUG: Camera permission not determined")
            requestPermission()
        case .denied, .restricted:
            print("DEBUG: Camera permission denied or restricted")
            DispatchQueue.main.async { [weak self] in
                self?.permissionGranted = false
                self?.error = "Camera access denied. Please enable it in Settings."
            }
        @unknown default:
            print("DEBUG: Unknown camera permission status")
            DispatchQueue.main.async { [weak self] in
                self?.permissionGranted = false
                self?.error = "Unknown camera permission status."
            }
        }
    }
    
    
    private func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
            }
            if granted {
                self?.setupCaptureSession()
            } else {
                DispatchQueue.main.async {
                    self?.error = "Camera permission is required"
                }
            }
        }
    }
    
    private func getBestDetection(from observations: [VNRecognizedObjectObservation]) -> (String, Float)? {
        // Convert observations to array of (label, confidence) tuples
        let detections = observations.flatMap { observation -> [(String, Float)] in
            observation.labels.map { ($0.identifier, Float($0.confidence)) }
        }
        
        // Group by denomination and calculate average confidence
        var denominationConfidences: [String: Float] = [:]
        for (denomination, confidence) in detections {
            denominationConfidences[denomination, default: 0] += confidence
        }
        
        // Get the most frequent denomination from recent history
        let mostFrequent = recentDetections.suffix(historyWindowSize).reduce(into: [:]) { counts, denomination in
            counts[denomination, default: 0] += 1
        }.max(by: { $0.value < $1.value })?.key
        
        // Adjust confidences based on history
        var adjustedConfidences = denominationConfidences
        if let frequent = mostFrequent {
            adjustedConfidences[frequent] = (adjustedConfidences[frequent] ?? 0) * 1.1
        }
        
        // Return the highest confidence detection
        return adjustedConfidences.max(by: { $0.value < $1.value })
    }
    
    private func detectMoney(_ image: CGImage) {
        print("\n--- Starting New Detection ---")
        
        guard let model = try? VNCoreMLModel(for: turkishlirass().model) else {
            print("DEBUG: Failed to load ML model")
            isProcessing = false
            return
        }
        
        // Create and configure the request
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                print("DEBUG: Vision request error: \(error)")
                self.isProcessing = false
                return
            }
            
            guard let observations = request.results as? [VNRecognizedObjectObservation] else {
                print("DEBUG: No valid observations")
                self.isProcessing = false
                return
            }
            
            // Filter observations with minimum confidence
            let minConfidence: Float = 0.3  // Lowered threshold for initial detection
            let validObservations = observations.filter { observation in
                observation.labels.contains { $0.confidence > minConfidence }
            }
            
            if validObservations.isEmpty {
                print("DEBUG: No observations above minimum confidence")
                self.isProcessing = false
                return
            }
            
            // Get all detections with their confidences
            let topDetections = validObservations.flatMap { observation -> [(String, Float)] in
                observation.labels.map { ($0.identifier, Float($0.confidence)) }
            }.sorted { $0.1 > $1.1 }
            
            print("\n--- Detection Results ---")
            print("Number of valid observations: \(validObservations.count)")
            
            for (label, confidence) in topDetections {
                print("Label: \(label), Confidence: \(String(format: "%.2f%%", confidence * 100))")
            }
            
            // Process detections
            self.updateDetectionHistory(topDetections)
            
            if let bestDetection = topDetections.first {
                if bestDetection.1 > 0.95 && bestDetection.0 != "200-tl" {
                    self.handleFastDetection(label: bestDetection.0, confidence: bestDetection.1)
                } else {
                    self.handleEnhancedDetection(label: bestDetection.0, confidence: bestDetection.1)
                }
            }
            
            self.isProcessing = false
        }
        
        request.imageCropAndScaleOption = .scaleFit
        
        do {
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
        } catch {
            print("DEBUG: Vision request failed: \(error)")
            isProcessing = false
        }
    }
    
    private func handleFastDetection(label: String, confidence: Float) {
        if label == lastDetectedAmount {
            consecutiveDetections += 1
            if consecutiveDetections >= 2 { // Changed from 1 to 2 for more stability
                DispatchQueue.main.async {
                    if self.detectedAmount != label {
                        self.detectedAmount = label
                        self.speakAmount(label)
                    }
                }
            }
        } else {
            consecutiveDetections = 1
            lastDetectedAmount = label
        }
    }
    
    private func handleEnhancedDetection(label: String, confidence: Float) {
        // Get required consecutive detections for this denomination
        let requiredDetections = requiredDetectionsPerDenomination[label] ?? self.requiredConsecutiveDetections
        
        if label == lastDetectedAmount {
            consecutiveDetections += 1
        } else {
            consecutiveDetections = 1
            lastDetectedAmount = label
        }
        
        // Modified validation for high-value notes
        if label == "200-tl" || label == "100-tl" {
            let hasStableHistory = validateDenominationHistory(label)
            if !hasStableHistory {
                print("DEBUG: High-value note requires more stable history")
                return
            }
        }
        
        if consecutiveDetections >= requiredDetections {
            DispatchQueue.main.async {
                if self.detectedAmount != label {
                    print("DEBUG: Detected \(label) with confidence \(confidence)")
                    self.detectedAmount = label
                    self.speakAmount(label)
                }
            }
        }
    }
    
    private func validateDenominationHistory(_ denomination: String) -> Bool {
        let recentCount = recentDetections.suffix(historyWindowSize)
            .filter { $0 == denomination }
            .count
        
        // Stricter validation ratios
        let requiredHistoryRatio = if denomination.contains("200") {
            0.75  // Increased from 0.4
        } else if denomination.contains("100") {
            0.70  // New threshold for 100 TL
        } else if denomination.contains("50") {
            0.65  // New threshold for 50 TL
        } else {
            0.60  // Increased from 0.3
        }
        
        let actualRatio = Double(recentCount) / Double(historyWindowSize)
        return actualRatio >= requiredHistoryRatio
    }
    
    private func updateDetectionHistory(_ detections: [(String, Float)]) {
        // Sort detections by confidence
        let sortedDetections = detections.sorted { $0.1 > $1.1 }
        
        // Add top detection to history if it meets minimum confidence
        if let topDetection = sortedDetections.first,
           topDetection.1 > minimumConfidence {
            recentDetections.append(topDetection.0)
            if recentDetections.count > historyWindowSize {
                recentDetections.removeFirst()
            }
            
            // Update detection counts
            detectionHistory = Dictionary(grouping: recentDetections) { $0 }
                .mapValues { $0.count }
            
            print("DEBUG: Updated history - Current counts: \(detectionHistory)")
        }
    }
    
    private func handleDetection(label: String, confidence: Float) {
        // Update confidence history
        lastConfidences.append((label, confidence))
        if lastConfidences.count > confidenceHistorySize {
            lastConfidences.removeFirst()
        }
        
        // Special handling for high-value notes
        if label == "200-tl" || label == "100-tl" {
            if validateHighValueNote(label, confidence) {
                detectedAmount = String(label.split(separator: "-")[0])
                print("DEBUG: High-value note detected: \(label) with confidence \(confidence)")
                return
            }
        }
        
        // Regular validation for other denominations
        if let threshold = denominationThresholds[label], confidence >= threshold {
            detectedAmount = String(label.split(separator: "-")[0])
            print("DEBUG: Note detected: \(label) with confidence \(confidence)")
        }
    }
    
    private func resetDetection() {
        consecutiveDetections = 0
        if !detectedAmount.isEmpty {
            DispatchQueue.main.async {
                self.detectedAmount = ""
            }
        }
    }
    
    private func speakAmount(_ amount: String) {
        guard let settings = settingsViewModel else { return }
        
        let language = settings.currentLanguage
        let text = LocalizedStrings.denominationText(amount, language: language)
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.rawValue)
        utterance.rate = 0.5
        speechSynthesizer.speak(utterance)
    }
    
    private func imagesAreSimilar(_ image1: CGImage, _ image2: CGImage) -> Bool {
        // Simple dimension check
        guard image1.width == image2.width && image1.height == image2.height else {
            return false
        }
        return false // Disable for now, implement more sophisticated comparison if needed
    }
    
    private func validatePhysicalCharacteristics(_ denomination: String) -> Bool {
        guard let characteristics = banknoteCharacteristics[denomination] else { return false }
        
        // Get the current frame dimensions
        guard let currentFrame = frame else { return false }
        
        let aspectRatio = Double(currentFrame.width) / Double(currentFrame.height)
        let expectedAspectRatio = characteristics.width / characteristics.height
        
        // Allow for some tolerance in the aspect ratio comparison
        let tolerance = 0.15
        let aspectRatioMatch = abs(aspectRatio - expectedAspectRatio) <= tolerance
        
        print("DEBUG: Physical Validation for \(denomination)")
        print("Expected aspect ratio: \(expectedAspectRatio)")
        print("Actual aspect ratio: \(aspectRatio)")
        print("Aspect ratio match: \(aspectRatioMatch)")
        
        return aspectRatioMatch
    }
    
    private func updateConfidenceHistory(label: String, confidence: Float) {
        lastConfidences.append((label, confidence))
        if lastConfidences.count > confidenceHistorySize {
            lastConfidences.removeFirst()
        }
    }
    
    private func validateConfidencePattern(_ denomination: String, _ currentConfidence: Float) -> Bool {
        if denomination == "200-tl" {
            return validate200TLDetection(currentConfidence)
        }
        
        // Original validation for other denominations
        let requiredConfidence: Float = denominationThresholds[denomination] ?? 0.85
        let confidenceCount = lastConfidences.filter { 
            $0.0 == denomination && $0.1 > requiredConfidence 
        }.count
        
        let requiredRatio: Float = if denomination == "100-tl" {
            0.75
        } else {
            0.7
        }
        
        let ratio = Float(confidenceCount) / Float(lastConfidences.count)
        return ratio >= requiredRatio
    }
    
    // Add this new method to detect sudden changes
    private func detectSuddenChange(newLabel: String) -> Bool {
        let recentLabels = recentDetections.suffix(3)
        let allSame = recentLabels.allSatisfy { $0 == recentLabels.first }
        return allSame && recentLabels.first != newLabel
    }
    
    func pauseSession() {
        stopSession()
        isProcessing = false
        detectedAmount = ""
    }
    
    func resumeSession() {
        guard permissionGranted else { return }
        startSession()
    }
    
    private func validate200TLDetection(_ currentConfidence: Float) -> Bool {
        let recentHistory = lastConfidences.suffix(3) // Reduced from 5 to 3
        
        // Debug logging
        print("DEBUG: 200 TL Validation Stats:")
        print("Current Confidence: \(String(format: "%.2f%%", currentConfidence * 100))")
        
        // Case 1: Single very high confidence detection
        if currentConfidence >= 0.999 {
            print("DEBUG: Ultra-high confidence detection")
            return true
        }
        
        // Case 2: Multiple high confidence detections
        let highConfidenceDetections = recentHistory.filter { 
            $0.0 == "200-tl" && $0.1 >= 0.95 
        }
        
        print("DEBUG: High confidence detections in window: \(highConfidenceDetections.count)")
        
        if highConfidenceDetections.count >= 2 {
            print("DEBUG: Multiple high confidence detections")
            return true
        }
        
        // Case 3: Consistent medium-high confidence
        let mediumConfidenceDetections = recentHistory.filter { 
            $0.0 == "200-tl" && $0.1 >= 0.85 
        }
        
        if mediumConfidenceDetections.count >= 3 {
            print("DEBUG: Consistent medium-high confidence pattern")
            return true
        }
        
        print("DEBUG: Validation pending - building confidence history")
        return false
    }
    
    private func validateStablePattern(_ denomination: String) -> Bool {
        let recentLabels = recentDetections.suffix(6)
        let denominationCount = recentLabels.filter { $0 == denomination }.count
        return Double(denominationCount) / Double(recentLabels.count) >= 0.8
    }
    
    private func validateHighValueNote(_ label: String, _ confidence: Float) -> Bool {
        // For 200 TL, we need special validation
        if label == "200-tl" {
            // Get recent history for 200 TL detections
            let recentDetections = lastConfidences.suffix(3)  // Look at last 3 detections
            let highConfidenceCount = recentDetections.filter { 
                $0.0 == "200-tl" && $0.1 >= 0.85 
            }.count
            
            print("DEBUG: 200 TL validation - High confidence count: \(highConfidenceCount)")
            
            // Either very high single confidence or multiple high confidence detections
            return confidence >= 0.95 || highConfidenceCount >= 2
        }
        
        // For 100 TL, slightly less strict
        if label == "100-tl" {
            return confidence >= 0.90
        }
        
        return false
    }
}

extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastDetectionTime >= detectionInterval else { return }
        
        guard !isProcessing else {
            print("DEBUG: Skipping frame - still processing")
            return
        }
        
        isProcessing = true
        lastDetectionTime = currentTime
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("DEBUG: Failed to get image buffer")
            isProcessing = false
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        guard let cgImage = imageContext.createCGImage(ciImage, from: ciImage.extent) else {
            print("DEBUG: Failed to create CGImage")
            isProcessing = false
            return
        }
        
        detectMoney(cgImage)
    }
}



// Add this extension for image resizing
extension CGImage {
    func resized(to size: CGSize) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil,
                                      width: Int(size.width),
                                      height: Int(size.height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            return nil
        }
        
        context.interpolationQuality = .medium  // Changed to medium for better performance
        context.draw(self, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }
}

