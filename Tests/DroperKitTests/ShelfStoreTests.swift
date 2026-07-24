import Foundation
import Testing

@testable import DroperKit

struct ShelfStoreTests {
    private let a = URL(fileURLWithPath: "/tmp/droper-a.txt")
    private let b = URL(fileURLWithPath: "/tmp/droper-b.txt")

    @Test func addAppendsAndNotifies() {
        let store = ShelfStore()
        var changed = 0
        store.onItemsChanged = { changed += 1 }

        #expect(store.add(a))
        #expect(store.add(b))
        #expect(store.count == 2)
        #expect(store.items == [a, b])
        #expect(changed == 2)
    }

    @Test func duplicateIsNotAddedTwice() {
        let store = ShelfStore()
        #expect(store.add(a))
        #expect(!store.add(a))
        // Aynı dosyanın standartlaşmamış hali de yinelenmemeli.
        #expect(!store.add(URL(fileURLWithPath: "/tmp/../tmp/droper-a.txt")))
        #expect(store.count == 1)
    }

    @Test func bulkAddReportsOnlyNewItems() {
        let store = ShelfStore()
        _ = store.add(a)
        let added = store.add(contentsOf: [a, b])
        #expect(added == 1)
        #expect(store.count == 2)
    }

    @Test func removingLastItemSignalsClose() {
        let store = ShelfStore()
        var closeSignals = 0
        store.onShouldClose = { closeSignals += 1 }
        _ = store.add(a)
        _ = store.add(b)

        store.remove(a)
        #expect(closeSignals == 0, "raf doluyken kapanma sinyali gelmemeli")

        store.remove(b)
        #expect(closeSignals == 1, "son öğe çıkınca kapanma sinyali gelmeli")
        #expect(store.isEmpty)
    }

    @Test func removeUnknownItemDoesNothing() {
        let store = ShelfStore()
        var closeSignals = 0
        store.onShouldClose = { closeSignals += 1 }
        _ = store.add(a)

        store.remove(b)
        #expect(store.count == 1)
        #expect(closeSignals == 0)
    }

    @Test func removeAllSignalsCloseOnce() {
        let store = ShelfStore()
        var closeSignals = 0
        store.onShouldClose = { closeSignals += 1 }
        _ = store.add(a)
        _ = store.add(b)

        store.removeAll()
        #expect(store.isEmpty)
        #expect(closeSignals == 1)

        // Boşken tekrar çağrılırsa sinyal yinelenmez.
        store.removeAll()
        #expect(closeSignals == 1)
    }
}
