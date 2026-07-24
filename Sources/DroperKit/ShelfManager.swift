import AppKit

/// Açık rafların kaydını tutar; sınırsız sayıda bağımsız raf.
public final class ShelfManager {
    public static let shared = ShelfManager()

    public private(set) var shelves: [ShelfWindowController] = []

    /// Menüden bilinçli açılan raf: sürükleme bitince kapanmaz.
    @discardableResult
    public func openShelf(
        at point: NSPoint, closesWhenDragAbandoned: Bool = false
    ) -> ShelfWindowController {
        let shelf = ShelfWindowController(
            at: point,
            settings: .shared,
            closesWhenDragAbandoned: closesWhenDragAbandoned
        ) { [weak self] closed in
            self?.shelves.removeAll { $0 === closed }
        }
        shelves.append(shelf)
        shelf.show()
        return shelf
    }

    /// Sürükleme tetiklemesi için: imleç yakınında açık raf varsa yenisini açmaz.
    public func openOrReuseShelf(at point: NSPoint) {
        if let near = shelves.first(where: {
            $0.panel.frame.insetBy(dx: -120, dy: -120).contains(point)
        }) {
            near.panel.orderFrontRegardless()
            return
        }
        openShelf(at: point, closesWhenDragAbandoned: true)
    }

    /// Sürükleme rafa uğramadan bittiyse otomatik açılmış boş rafları kapat.
    /// Kısa gecikme, bırakma işleminin (performDragOperation) tamamlanmasına
    /// alan tanır; rafa bir şey bırakıldıysa raf boş olmayacağı için kalır.
    public func dragEnded() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            for shelf in self.shelves
            where shelf.closesWhenDragAbandoned && shelf.store.isEmpty {
                shelf.close()
            }
        }
    }

    public func closeAll() {
        for shelf in shelves { shelf.close() }
    }
}
