import AppKit
import Carbon

/// Minimal global hotkey using Carbon RegisterEventHotKey.
final class GlobalHotKey {
    struct Modifiers: OptionSet {
        let rawValue: UInt32
        static let command = Modifiers(rawValue: UInt32(cmdKey))
        static let shift = Modifiers(rawValue: UInt32(shiftKey))
        static let option = Modifiers(rawValue: UInt32(optionKey))
        static let control = Modifiers(rawValue: UInt32(controlKey))
    }

    private let keyCode: UInt32
    private let modifiers: Modifiers
    private let handler: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private let hotKeyID: UInt32

    init(keyCode: UInt32, modifiers: Modifiers, handler: @escaping () -> Void) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.handler = handler
        self.hotKeyID = GlobalHotKey.nextID
        GlobalHotKey.nextID += 1
    }

    func register() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if let handler = GlobalHotKey.handlers[hotKeyID.id] {
                    DispatchQueue.main.async { handler() }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )
        guard status == noErr else { return }

        GlobalHotKey.handlers[hotKeyID] = handler
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x514E5443), id: hotKeyID) // 'QNTC'
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers.rawValue,
            id,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if registerStatus == noErr {
            hotKeyRef = ref
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        GlobalHotKey.handlers[hotKeyID] = nil
        hotKeyRef = nil
        eventHandler = nil
    }

    deinit {
        // Best-effort cleanup; Carbon refs are not MainActor-isolated.
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }
}
