/// Drag state machine: idle -> lifted <-> outside -> pending -> idle.
struct DragCoordinator: Equatable {
    enum Phase: Equatable {
        case idle
        case lifted(String) // capsule raised inside the popover
        case outside(String) // dragged out: bar previews the app as closed
        case pending(String) // dropped outside, waiting for the app to quit
    }

    private(set) var phase = Phase.idle

    var liftedID: String? {
        if case let .lifted(id) = phase { id } else { nil }
    }

    /// The slice currently shown as "already closed".
    var previewID: String? {
        switch phase {
        case let .outside(id), let .pending(id): id
        default: nil
        }
    }

    mutating func begin(_ id: String) {
        if phase == .idle { phase = .lifted(id) }
    }

    mutating func move(inside: Bool) {
        switch phase {
        case let .lifted(id) where !inside: phase = .outside(id)
        case let .outside(id) where inside: phase = .lifted(id)
        default: break
        }
    }

    /// Returns the id to quit when dropped outside; dropping inside cancels.
    mutating func drop() -> String? {
        switch phase {
        case let .outside(id):
            phase = .pending(id)
            return id
        case .lifted:
            phase = .idle
            return nil
        default:
            return nil
        }
    }

    /// Quit confirmed or failed.
    mutating func resolve() {
        if case .pending = phase { phase = .idle }
    }
}
