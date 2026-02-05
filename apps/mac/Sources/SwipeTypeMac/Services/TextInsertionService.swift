import Cocoa
import Carbon.HIToolbox

private let swipeTypeSyntheticEventUserData: Int64 = 0x53575459

class TextInsertionService {
    static let shared = TextInsertionService()

    private init() {}

    func insertText(_ text: String) {
        let (contentToPaste, trailingKeys) = splitTrailingKeys(text)

        if contentToPaste.isEmpty {
            if !trailingKeys.isEmpty {
                DispatchQueue.main.async {
                    self.sendTrailingKeys(trailingKeys)
                }
            }
            return
        }

        let pasteboard = NSPasteboard.general
        let hadInitialContents = pasteboard.pasteboardItems?.isEmpty == false

        let savedContents = pasteboard.pasteboardItems?.compactMap { item -> [(NSPasteboard.PasteboardType, Data)]? in
            item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            }
        }.flatMap { $0 } ?? []

        pasteboard.clearContents()
        pasteboard.setString(contentToPaste, forType: .string)
        let expectedChangeCount = pasteboard.changeCount

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if !contentToPaste.isEmpty {
                self.sendPaste()
            }

            if !trailingKeys.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    self.sendTrailingKeys(trailingKeys)
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard pasteboard.changeCount == expectedChangeCount else { return }
                if !savedContents.isEmpty {
                    pasteboard.clearContents()
                    for (type, data) in savedContents {
                        pasteboard.setData(data, forType: type)
                    }
                } else if !hadInitialContents {
                    pasteboard.clearContents()
                }
            }
        }
    }

    private func sendPaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand

        markSynthetic(cmdDown)
        markSynthetic(vDown)
        markSynthetic(vUp)
        markSynthetic(cmdUp)

        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }

    private func markSynthetic(_ event: CGEvent?) {
        event?.setIntegerValueField(.eventSourceUserData, value: swipeTypeSyntheticEventUserData)
    }

    private func sendTrailingKeys(_ keys: [TrailingKey]) {
        for key in keys {
            switch key {
            case .space:
                sendKeyPress(virtualKey: CGKeyCode(kVK_Space))
            case .return:
                sendKeyPress(virtualKey: CGKeyCode(kVK_Return))
            case .tab:
                sendKeyPress(virtualKey: CGKeyCode(kVK_Tab))
            }
        }
    }

    private func sendKeyPress(virtualKey: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)

        markSynthetic(down)
        markSynthetic(up)

        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private enum TrailingKey {
        case space
        case `return`
        case tab
    }

    private func splitTrailingKeys(_ text: String) -> (content: String, trailing: [TrailingKey]) {
        guard !text.isEmpty else { return ("", []) }

        var endIndex = text.endIndex
        while endIndex > text.startIndex {
            let previous = text.index(before: endIndex)
            let ch = text[previous]
            if ch == " " || ch == "\n" || ch == "\t" {
                endIndex = previous
            } else {
                break
            }
        }

        let content = String(text[..<endIndex])
        let suffix = text[endIndex...]
        var trailing: [TrailingKey] = []
        trailing.reserveCapacity(suffix.count)
        for ch in suffix {
            switch ch {
            case " ": trailing.append(.space)
            case "\n": trailing.append(.return)
            case "\t": trailing.append(.tab)
            default: break
            }
        }

        return (content, trailing)
    }
}
