import ApplicationServices

/// Check whether SpacePeek is trusted for Accessibility.
/// `prompt`: when true, macOS shows its system prompt the first time.
/// We default to `false` to avoid stacking the system prompt under our own alert.
func isAccessibilityTrusted(prompt: Bool = false) -> Bool {
    let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let options: CFDictionary = [promptKey: prompt] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

func ensureAccessibility(completion: @escaping (Bool) -> Void) {
    completion(isAccessibilityTrusted(prompt: false))
}
