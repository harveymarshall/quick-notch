import AppKit
import Carbon

/// Minimal global hotkey using Carbon RegisterEventHotKey.
final class GlobalHotKey: @unchecked Sendable {
    struct Modifiers: OptionSet, Sendable {
        let rawValue: UInt32
        static let command = Modifiers(rawValue: UInt32(cmdKey))
        static let shift = Modifiers(rawValue: UInt32(shiftKey))
        static let option = Modifiers(rawValue: UInt32(optionKey))
        static let control = Modifiers(rawValue: UInt32(controlKey))
    }

    private final class HandlerStore: @unchecked Sendable {
        private let lock = NSLock()
        private var handlers: [UInt32: @Sendable () -> Void] = [:]
        private var nextID: UInt32 = 1

        func allocateID() -> UInt32 {
            lock.lock()
            defer { lock.unlock() }
            let id = nextID
            nextID += 1
            return id
        }

        func setHandler(_ handler: @escaping @Sendable () -> Void, for id: UInt32) {
            lock.lock()
            handlers[id] = handler
            lock.unlock()
        }

        func removeHandler(for id: UInt32) {
            lock.lock()
            handlers[id] = nil
            lock.unlock()
        }

        func handler(for id: UInt32) -> (@Sendable () -> Void)? {
            lock.lock()
            defer { lock.unlock() }
            return handlers[id]
        }
    }

    private static let store = HandlerStore()

    private let keyCode: UInt32
    private let modifiers: Modifiers
    private let handler: @Sendable () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let hotKeyID: UInt32

    init(keyCode: UInt32, modifiers: Modifiers, handler: @escaping @Sendable () -> Void) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.handler = handler
        self.hotKeyID = GlobalHotKey.store.allocateID()
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
                if let handler = GlobalHotKey.store.handler(for: hotKeyID.id) {
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

        GlobalHotKey.store.setHandler(handler, for: hotKeyID)
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
        GlobalHotKey.store.removeHandler(for: hotKeyID)
        hotKeyRef = nil
        eventHandler = nil
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }
}
