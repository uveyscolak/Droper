import Foundation

public enum TransferMode: String, CaseIterable, Sendable {
    case move
    case copy
}

public enum FileTransferError: Error, Equatable {
    case sourceMissing(String)
    case verificationFailed(String)
}

/// Saf, test edilebilir dosya taşıma/kopyalama mantığı.
/// Üzerine yazma yok: ad çakışmasında "ad 2.uzantı" biçiminde benzersizleştirilir.
public struct FileTransfer {
    /// Verilen dizinde çakışmayan bir hedef URL üretir ("ad.txt" → "ad 2.txt" → "ad 3.txt").
    public static func uniqueDestination(
        for fileName: String,
        in directory: URL,
        fileManager: FileManager = .default
    ) -> URL {
        var candidate = directory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: candidate.path) else { return candidate }

        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var counter = 2
        repeat {
            let name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            candidate = directory.appendingPathComponent(name)
            counter += 1
        } while fileManager.fileExists(atPath: candidate.path)
        return candidate
    }

    /// Kaynağı hedef DİZİNE taşır/kopyalar. Taşı modunda kaynak zaten o dizindeyse no-op.
    @discardableResult
    public static func transfer(
        _ source: URL,
        toDirectory directory: URL,
        mode: TransferMode,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard fileManager.fileExists(atPath: source.path) else {
            throw FileTransferError.sourceMissing(source.path)
        }
        let sourceDir = source.deletingLastPathComponent().standardizedFileURL.path
        if mode == .move, sourceDir == directory.standardizedFileURL.path {
            return source
        }
        let destination = uniqueDestination(
            for: source.lastPathComponent, in: directory, fileManager: fileManager)
        try perform(mode, from: source, to: destination, fileManager: fileManager)
        return destination
    }

    /// Kaynağı TAM hedef URL'ye teslim eder (file promise akışı için).
    /// Hedef doluysa aynı dizinde benzersiz ada kayar.
    @discardableResult
    public static func deliver(
        _ source: URL,
        to destination: URL,
        mode: TransferMode,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard fileManager.fileExists(atPath: source.path) else {
            throw FileTransferError.sourceMissing(source.path)
        }
        if mode == .move,
            source.standardizedFileURL.path == destination.standardizedFileURL.path {
            return source
        }
        var target = destination
        if fileManager.fileExists(atPath: target.path) {
            target = uniqueDestination(
                for: destination.lastPathComponent,
                in: destination.deletingLastPathComponent(),
                fileManager: fileManager)
        }
        try perform(mode, from: source, to: target, fileManager: fileManager)
        return target
    }

    private static func perform(
        _ mode: TransferMode, from source: URL, to destination: URL, fileManager: FileManager
    ) throws {
        switch mode {
        case .copy:
            try fileManager.copyItem(at: source, to: destination)
        case .move:
            do {
                try fileManager.moveItem(at: source, to: destination)
            } catch let moveError {
                // Farklı volume'lar arası move başarısız olabilir: kopyala + sil dene.
                // Kopya da olmazsa orijinal hata fırlatılır; kaynak her durumda bozulmaz.
                do {
                    try fileManager.copyItem(at: source, to: destination)
                } catch {
                    throw moveError
                }
                try fileManager.removeItem(at: source)
            }
        }
    }
}
