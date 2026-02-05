//
//  AppState.swift
//  SwipeTypeMac
//

import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    // Core state
    @Published var predictions: [Prediction] = []
    @Published var currentInput: String = ""
    @Published var isOverlayVisible = false
    @Published var isWordCommitted = false  // True after debounce timeout
    @Published var inputTimestamps: [TimeInterval] = []
    @Published var isPlaybackActive = false
    @Published var playbackStartTime: TimeInterval = 0

    // Status
    @Published var isDictionaryLoaded = false
    @Published var dictionaryWordCount = 0

    private var requestId = 0
    private var debounceTimer: Timer?
    private var debounceDelay: TimeInterval { AppSettings.debounceDelay }

    private init() {}

    // MARK: - Dictionary Management

    func loadDictionary() {
        let wordCount = SwipeEngineBridge.shared.loadBundledDictionary()
        isDictionaryLoaded = wordCount > 0
        dictionaryWordCount = wordCount
    }

    // MARK: - Input Handling

    /// Returns word to insert if previous word was committed
    func addCharacter(_ char: Character) -> String? {
        var wordToInsert: String? = nil

        // If word is committed (debounce passed), insert it and start fresh
        if AppSettings.autoCommitAfterPause, isWordCommitted, let first = predictions.first {
            wordToInsert = first.word
            reset()
        }

        currentInput.append(char)
        inputTimestamps.append(Date().timeIntervalSinceReferenceDate)
        isPlaybackActive = false
        playbackStartTime = 0
        triggerPrediction()
        resetDebounceTimer()

        return wordToInsert
    }

    func deleteCharacter() {
        reset()
    }

    func selectPrediction(at index: Int) -> String? {
        guard index >= 0, index < predictions.count else { return nil }
        let word = predictions[index].word
        reset()
        return word
    }

    func reset() {
        requestId += 1
        currentInput = ""
        predictions = []
        isWordCommitted = false
        inputTimestamps = []
        isPlaybackActive = false
        playbackStartTime = 0
        cancelDebounceTimer()
    }

    func toggleOverlay() {
        isOverlayVisible.toggle()
        if !isOverlayVisible {
            reset()
        }
    }

    func hideOverlay() {
        isOverlayVisible = false
        reset()
    }

    // MARK: - Debounce Timer

    private func resetDebounceTimer() {
        cancelDebounceTimer()
        isWordCommitted = false

        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceDelay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !self.currentInput.isEmpty && !self.predictions.isEmpty {
                    self.isWordCommitted = true
                }
                if AppSettings.playSwipeAnimation, self.currentInput.count >= 2 {
                    self.isPlaybackActive = true
                    self.playbackStartTime = Date().timeIntervalSinceReferenceDate
                }
            }
        }
    }

    private func cancelDebounceTimer() {
        debounceTimer?.invalidate()
        debounceTimer = nil
    }

    // MARK: - Prediction

    private func triggerPrediction() {
        requestId += 1
        let thisRequest = requestId
        let input = currentInput

        DispatchQueue.global(qos: .userInitiated).async {
            let results = SwipeEngineBridge.shared.predict(input: input, limit: 5)
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.requestId == thisRequest else { return }
                self.predictions = results
            }
        }
    }
}
