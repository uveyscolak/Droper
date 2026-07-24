import Foundation

/// Bir rafın öğe durumu. Yalnızca referans tutar; dosyaya dokunmaz.
public final class ShelfStore {
    public private(set) var items: [URL] = []

    /// Öğe listesi her değiştiğinde çağrılır (UI yenileme için).
    public var onItemsChanged: (() -> Void)?
    /// Son öğe de çıkınca çağrılır: raf kendini kapatmalı.
    public var onShouldClose: (() -> Void)?

    public init() {}

    public var count: Int { items.count }
    public var isEmpty: Bool { items.isEmpty }

    /// Ekler; aynı dosya zaten raftaysa eklemez ve `false` döner.
    @discardableResult
    public func add(_ url: URL) -> Bool {
        let standardized = url.standardizedFileURL
        guard !items.contains(standardized) else { return false }
        items.append(standardized)
        onItemsChanged?()
        return true
    }

    /// Birden çok URL ekler; gerçekten eklenen sayısını döner.
    @discardableResult
    public func add(contentsOf urls: [URL]) -> Int {
        var added = 0
        for url in urls where addWithoutNotify(url) { added += 1 }
        if added > 0 { onItemsChanged?() }
        return added
    }

    public func remove(_ url: URL) {
        let standardized = url.standardizedFileURL
        guard let index = items.firstIndex(of: standardized) else { return }
        items.remove(at: index)
        onItemsChanged?()
        if items.isEmpty { onShouldClose?() }
    }

    public func removeAll() {
        guard !items.isEmpty else { return }
        items.removeAll()
        onItemsChanged?()
        onShouldClose?()
    }

    private func addWithoutNotify(_ url: URL) -> Bool {
        let standardized = url.standardizedFileURL
        guard !items.contains(standardized) else { return false }
        items.append(standardized)
        return true
    }
}
