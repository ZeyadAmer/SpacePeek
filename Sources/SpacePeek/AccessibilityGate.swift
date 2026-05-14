import ApplicationServices

func ensureAccessibility(completion: @escaping (Bool) -> Void) {
    let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let options: CFDictionary = [promptKey: true] as CFDictionary
    let trusted = AXIsProcessTrustedWithOptions(options)
    completion(trusted)
}
