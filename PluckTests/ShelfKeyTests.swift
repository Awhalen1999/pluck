import AppKit
import Testing
@testable import Pluck

private func key(_ characters: String, _ flags: NSEvent.ModifierFlags = []) -> NSEvent {
    NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil,
                     characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: 0)!
}

private func special(_ key: NSEvent.SpecialKey) -> String { String(Character(UnicodeScalar(key.rawValue)!)) }

@Test func theShelfAnswersTheKeysFinderAndPhotosUse() {
    #expect(ShelfKey(key(special(.leftArrow))) == .move(.left))
    #expect(ShelfKey(key(special(.downArrow))) == .move(.down))
    #expect(ShelfKey(key("\u{1b}")) == .escape)
    #expect(ShelfKey(key("w", .command)) == .close)
    #expect(ShelfKey(key("\r")) == .copyAndClose)
    #expect(ShelfKey(key("c", .command)) == .copy)
    #expect(ShelfKey(key(" ")) == .preview)
    #expect(ShelfKey(key(special(.delete))) == .trash)
    #expect(ShelfKey(key(special(.delete), .command)) == .trash)
    #expect(ShelfKey(key("z", .command)) == .undo)
    #expect(ShelfKey(key("p")) == .pin)
    #expect(ShelfKey(key("a", .command)) == .selectAll)
}

@Test func anyOtherKeyIsLeftToTheApp() {
    #expect(ShelfKey(key("c")) == nil)
    #expect(ShelfKey(key("x")) == nil)
    #expect(ShelfKey(key("q", .command)) == nil)
    #expect(ShelfKey(key("a", [.command, .shift])) == nil)
    #expect(ShelfKey(key(special(.leftArrow), .option)) == nil)
}

@Test func holdingAKeyRepeatsOnlyTheArrows() {
    #expect(ShelfKey.move(.up).repeats)
    #expect(!ShelfKey.trash.repeats)
    #expect(!ShelfKey.copy.repeats)
}
