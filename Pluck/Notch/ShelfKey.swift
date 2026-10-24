import AppKit
import SwiftUI

/// The keys the Shelf answers, as Finder and Photos have them.
enum ShelfKey: Equatable {
    case move(MoveCommandDirection)
    /// Esc: the selection first, then the Shelf.
    case escape
    /// ⌘W
    case close
    /// Return, so the next ⌘V lands in the user's app.
    case copyAndClose
    case copy
    case preview
    case trash
    case undo
    case pin
    case selectAll

    init?(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let plain = flags.isEmpty
        let command = flags == .command
        let key = event.charactersIgnoringModifiers?.lowercased()
        let special = event.specialKey

        if plain, let direction = special.flatMap({ Self.arrows[$0] }) {
            self = .move(direction)
        } else if plain, key == "\u{1b}" {
            self = .escape
        } else if command, key == "w" {
            self = .close
        } else if plain, special == .carriageReturn || special == .enter {
            self = .copyAndClose
        } else if command, key == "c" {
            self = .copy
        } else if plain, key == " " {
            self = .preview
        } else if plain || command, special == .delete || special == .deleteForward {
            self = .trash
        } else if command, key == "z" {
            self = .undo
        } else if plain || command, key == "p" {
            self = .pin
        } else if command, key == "a" {
            self = .selectAll
        } else {
            return nil
        }
    }

    /// Holding a key down repeats only the arrows.
    var repeats: Bool {
        if case .move = self { true } else { false }
    }

    private static let arrows: [NSEvent.SpecialKey: MoveCommandDirection] = [
        .leftArrow: .left, .rightArrow: .right, .upArrow: .up, .downArrow: .down,
    ]
}
