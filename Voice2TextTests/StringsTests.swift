import XCTest
@testable import Voice2Text

final class StringsTests: XCTestCase {

    // MARK: - All static L properties are non-empty for both languages

    /// Collect all simple (no-arg) String properties from L enum.
    /// We test each one in both English and Chinese to ensure completeness.
    private static let simpleStringProperties: [(String, () -> String)] = [
        // OnboardingView — Welcome
        ("welcomeTitle", { L.welcomeTitle }),
        ("welcomeSubtitle", { L.welcomeSubtitle }),
        ("getStarted", { L.getStarted }),
        // OnboardingView — Model Selection
        ("chooseModel", { L.chooseModel }),
        ("chooseModelSubtitle", { L.chooseModelSubtitle }),
        ("skipAppleSpeech", { L.skipAppleSpeech }),
        ("downloadAndContinue", { L.downloadAndContinue }),
        ("downloaded", { L.downloaded }),
        ("downloadComplete", { L.downloadComplete }),
        // OnboardingView — Permissions
        ("globalHotkey", { L.globalHotkey }),
        ("hotkeyDescription", { L.hotkeyDescription }),
        ("hotkeyFeature1", { L.hotkeyFeature1 }),
        ("hotkeyFeature2", { L.hotkeyFeature2 }),
        ("hotkeyFeature3", { L.hotkeyFeature3 }),
        ("accessibilityNote", { L.accessibilityNote }),
        ("accessibilityGranted", { L.accessibilityGranted }),
        ("openSystemSettings", { L.openSystemSettings }),
        ("continueButton", { L.continueButton }),
        ("skipForNow", { L.skipForNow }),
        // ContentView
        ("autoPunctuation", { L.autoPunctuation }),
        ("aiRevise", { L.aiRevise }),
        ("localLLMBadge", { L.localLLMBadge }),
        ("reformatting", { L.reformatting }),
        ("transcribing", { L.transcribing }),
        ("starting", { L.starting }),
        ("recording", { L.recording }),
        ("holdSpaceToRecord", { L.holdSpaceToRecord }),
        ("noModelLoaded", { L.noModelLoaded }),
        ("noNetwork", { L.noNetwork }),
        ("settingsTooltip", { L.settingsTooltip }),
        ("firstUseTooltip", { L.firstUseTooltip }),
        // ContentView — Alerts
        ("micAccessRequired", { L.micAccessRequired }),
        ("micAccessMessage", { L.micAccessMessage }),
        ("enableAutoPaste", { L.enableAutoPaste }),
        ("autoPasteMessage", { L.autoPasteMessage }),
        ("accessibilityNeedsRefresh", { L.accessibilityNeedsRefresh }),
        ("accessibilityRefreshMessage", { L.accessibilityRefreshMessage }),
        ("later", { L.later }),
        ("disableGlobalHotkey", { L.disableGlobalHotkey }),
        // MenuBarView
        ("stopRecording", { L.stopRecording }),
        ("startRecording", { L.startRecording }),
        ("output", { L.output }),
        ("downloadLabel", { L.downloadLabel }),
        ("copyTranscription", { L.copyTranscription }),
        ("openWindow", { L.openWindow }),
        ("settings", { L.settings }),
        ("punctuationRestore", { L.punctuationRestore }),
        ("quit", { L.quit }),
        // FloatingRecordingPanel
        ("floatingRecording", { L.floatingRecording }),
        ("floatingTranscribing", { L.floatingTranscribing }),
        ("floatingReformatting", { L.floatingReformatting }),
        ("floatingPasted", { L.floatingPasted }),
        // TranscriptionView
        ("transcriptionPlaceholder", { L.transcriptionPlaceholder }),
        // CopyButton
        ("copyTooltip", { L.copyTooltip }),
        // HotkeyRecorderView
        ("pressShortcut", { L.pressShortcut }),
        ("reset", { L.reset }),
        // SettingsView — Tabs
        ("generalTab", { L.generalTab }),
        ("modelsTab", { L.modelsTab }),
        ("shortcutsTab", { L.shortcutsTab }),
        ("advancedTab", { L.advancedTab }),
        // SettingsView — General
        ("languageSection", { L.languageSection }),
        ("languageLabel", { L.languageLabel }),
        ("sttEngineSection", { L.sttEngineSection }),
        ("engineLabel", { L.engineLabel }),
        ("networkAvailable", { L.networkAvailable }),
        ("noNetworkAppleSpeech", { L.noNetworkAppleSpeech }),
        ("outputScriptSection", { L.outputScriptSection }),
        ("scriptLabel", { L.scriptLabel }),
        // SettingsView — Models
        ("selectButton", { L.selectButton }),
        ("selectedLabel", { L.selectedLabel }),
        ("downloadButton", { L.downloadButton }),
        ("deleteTooltip", { L.deleteTooltip }),
        ("cancelButton", { L.cancelButton }),
        ("loading", { L.loading }),
        // SettingsView — Shortcuts
        ("globalPushToTalk", { L.globalPushToTalk }),
        ("enableGlobalHotkey", { L.enableGlobalHotkey }),
        ("shortcutLabel", { L.shortcutLabel }),
        ("hotkeyUsageHint", { L.hotkeyUsageHint }),
        ("accessibilitySection", { L.accessibilitySection }),
        ("accessibilityGrantedStatus", { L.accessibilityGrantedStatus }),
        ("accessibilityNotGrantedStatus", { L.accessibilityNotGrantedStatus }),
        ("accessibilityWarning", { L.accessibilityWarning }),
        // SettingsView — Advanced
        ("punctuationSection", { L.punctuationSection }),
        ("enablePunctuation", { L.enablePunctuation }),
        ("punctuationDescription", { L.punctuationDescription }),
        ("developerSection", { L.developerSection }),
        ("devModeToggle", { L.devModeToggle }),
        ("debugLogTitle", { L.debugLogTitle }),
        ("resetOnboarding", { L.resetOnboarding }),
        ("onboardingReset", { L.onboardingReset }),
        ("clear", { L.clear }),
        ("copyAll", { L.copyAll }),
        // SettingsView — AI Services
        ("aiServicesTab", { L.aiServicesTab }),
        ("postEditProviderSection", { L.postEditProviderSection }),
        ("providerNone", { L.providerNone }),
        ("providerLocalLLM", { L.providerLocalLLM }),
        ("providerCloudAPI", { L.providerCloudAPI }),
        ("localLLMModelSection", { L.localLLMModelSection }),
        ("recommended", { L.recommended }),
        ("localLLMNotImplemented", { L.localLLMNotImplemented }),
        ("localLLMDownloadPrompt", { L.localLLMDownloadPrompt }),
        ("qwen35NoThinkNote", { L.qwen35NoThinkNote }),
        ("downloadRecommended", { L.downloadRecommended }),
        ("cloudAPIWarning", { L.cloudAPIWarning }),
        ("apiCredentialsSection", { L.apiCredentialsSection }),
        ("baseURLLabel", { L.baseURLLabel }),
        ("baseURLPlaceholder", { L.baseURLPlaceholder }),
        ("modelLabel", { L.modelLabel }),
        ("modelPlaceholder", { L.modelPlaceholder }),
        ("apiTokenLabel", { L.apiTokenLabel }),
        ("apiTokenPlaceholder", { L.apiTokenPlaceholder }),
        ("saveToken", { L.saveToken }),
        ("deleteToken", { L.deleteToken }),
        ("tokenSaved", { L.tokenSaved }),
        ("tokenNotSet", { L.tokenNotSet }),
        ("tokenIsSet", { L.tokenIsSet }),
        ("checkAPI", { L.checkAPI }),
        ("checking", { L.checking }),
        ("postEditReviseSection", { L.postEditReviseSection }),
        ("postEditProviderDescription", { L.postEditProviderDescription }),
        ("reviseFailedBanner", { L.reviseFailedBanner }),
        ("reviseFailedFallbackBanner", { L.reviseFailedFallbackBanner }),
        ("lowAudioBanner", { L.lowAudioBanner }),
        ("customPromptLabel", { L.customPromptLabel }),
        ("resetToDefault", { L.resetToDefault }),
        ("savePrompt", { L.savePrompt }),
        ("saved", { L.saved }),
        ("punctuationHandledByRevise", { L.punctuationHandledByRevise }),
        ("reviseExclusivityNote", { L.reviseExclusivityNote }),
        ("invalidBaseURL", { L.invalidBaseURL }),
        ("insecureURLWarning", { L.insecureURLWarning }),
        ("saveCredentials", { L.saveCredentials }),
        ("revert", { L.revert }),
        ("unsavedChanges", { L.unsavedChanges }),
        ("credentialsSaved", { L.credentialsSaved }),
        // Punctuation Model
        ("downloadPunctuationModel", { L.downloadPunctuationModel }),
        ("deletePunctuationModel", { L.deletePunctuationModel }),
        ("punctuationModelDownloaded", { L.punctuationModelDownloaded }),
        ("punctuationModelSizeNote", { L.punctuationModelSizeNote }),
    ]

    // MARK: - English completeness

    func testAllStringsNonEmptyInEnglish() {
        AppState.shared.uiLanguage = .english
        for (name, getter) in Self.simpleStringProperties {
            let value = getter()
            XCTAssertFalse(value.isEmpty, "L.\(name) is empty in English")
        }
    }

    // MARK: - Chinese completeness

    func testAllStringsNonEmptyInChinese() {
        AppState.shared.uiLanguage = .chinese
        for (name, getter) in Self.simpleStringProperties {
            let value = getter()
            XCTAssertFalse(value.isEmpty, "L.\(name) is empty in Chinese")
        }
    }

    // MARK: - Language switching

    func testStringsChangeWithLanguage() {
        AppState.shared.uiLanguage = .english
        let englishWelcome = L.welcomeTitle

        AppState.shared.uiLanguage = .chinese
        let chineseWelcome = L.welcomeTitle

        XCTAssertNotEqual(englishWelcome, chineseWelcome,
                          "welcomeTitle should be different in English vs Chinese")
    }

    // MARK: - Parameterized strings

    func testDownloadingContainsModelName() {
        AppState.shared.uiLanguage = .english
        let result = L.downloading("tiny")
        XCTAssertTrue(result.contains("tiny"), "downloading() should contain the model name")

        AppState.shared.uiLanguage = .chinese
        let resultZh = L.downloading("tiny")
        XCTAssertTrue(resultZh.contains("tiny"), "downloading() should contain the model name in Chinese too")
    }

    func testCharCountFormat() {
        AppState.shared.uiLanguage = .english
        let result = L.charCount(42)
        XCTAssertTrue(result.contains("42"), "charCount should contain the number")
    }

    func testApiValidFormat() {
        AppState.shared.uiLanguage = .english
        let result = L.apiValid(150)
        XCTAssertTrue(result.contains("150"), "apiValid should contain latency")
    }

    func testApiInvalidFormat() {
        AppState.shared.uiLanguage = .english
        let result = L.apiInvalid("timeout")
        XCTAssertTrue(result.contains("timeout"), "apiInvalid should contain the error message")
    }

    func testWhatsNewTitleFormat() {
        AppState.shared.uiLanguage = .english
        let result = L.whatsNewTitle("2.8.1")
        XCTAssertTrue(result.contains("2.8.1"), "whatsNewTitle should contain version")
    }

    func testModelMenuFormat() {
        AppState.shared.uiLanguage = .english
        let result = L.modelMenu("small")
        XCTAssertTrue(result.contains("small"), "modelMenu should contain model name")
    }

    func testDownloadingProgressFormat() {
        AppState.shared.uiLanguage = .english
        let result = L.downloadingProgress(75)
        XCTAssertTrue(result.contains("75"), "downloadingProgress should contain percentage")
    }

    func testContinueWithFormat() {
        AppState.shared.uiLanguage = .english
        let result = L.continueWith("base")
        XCTAssertTrue(result.contains("base"), "continueWith should contain model name")
    }

    // MARK: - UILanguage

    func testUILanguageSystemDefault() {
        // Should return either .english or .chinese without crashing
        let lang = UILanguage.systemDefault
        XCTAssertTrue(UILanguage.allCases.contains(lang))
    }

    func testUILanguageCaseIterable() {
        XCTAssertEqual(UILanguage.allCases.count, 2)
        XCTAssertTrue(UILanguage.allCases.contains(.english))
        XCTAssertTrue(UILanguage.allCases.contains(.chinese))
    }
}
