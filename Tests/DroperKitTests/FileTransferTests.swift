import Foundation
import Testing

@testable import DroperKit

struct FileTransferTests {
    private let fm = FileManager.default

    /// Her test için benzersiz geçici çalışma alanı: base/src ve base/dst.
    private func makeWorkspace() throws -> (base: URL, src: URL, dst: URL) {
        let base = fm.temporaryDirectory
            .appendingPathComponent("droper-tests-\(UUID().uuidString)")
        let src = base.appendingPathComponent("src")
        let dst = base.appendingPathComponent("dst")
        try fm.createDirectory(at: src, withIntermediateDirectories: true)
        try fm.createDirectory(at: dst, withIntermediateDirectories: true)
        return (base, src, dst)
    }

    private func makeFile(_ name: String, in dir: URL, content: String = "droper") throws -> URL {
        let url = dir.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test func moveRemovesSourceAndCreatesDestination() throws {
        let ws = try makeWorkspace()
        defer { try? fm.removeItem(at: ws.base) }
        let file = try makeFile("a.txt", in: ws.src, content: "içerik")

        let result = try FileTransfer.transfer(file, toDirectory: ws.dst, mode: .move)

        #expect(!fm.fileExists(atPath: file.path), "taşımada kaynak silinmeli")
        #expect(fm.fileExists(atPath: result.path))
        #expect(try String(contentsOf: result, encoding: .utf8) == "içerik")
    }

    @Test func copyKeepsSource() throws {
        let ws = try makeWorkspace()
        defer { try? fm.removeItem(at: ws.base) }
        let file = try makeFile("b.txt", in: ws.src)

        let result = try FileTransfer.transfer(file, toDirectory: ws.dst, mode: .copy)

        #expect(fm.fileExists(atPath: file.path), "kopyalamada kaynak durmalı")
        #expect(fm.fileExists(atPath: result.path))
    }

    @Test func nameCollisionProducesNumberedCopies() throws {
        let ws = try makeWorkspace()
        defer { try? fm.removeItem(at: ws.base) }
        _ = try makeFile("rapor.txt", in: ws.dst, content: "eski")
        let file = try makeFile("rapor.txt", in: ws.src, content: "yeni")

        let second = try FileTransfer.transfer(file, toDirectory: ws.dst, mode: .copy)
        #expect(second.lastPathComponent == "rapor 2.txt")

        let third = try FileTransfer.transfer(file, toDirectory: ws.dst, mode: .copy)
        #expect(third.lastPathComponent == "rapor 3.txt")

        // Üzerine yazılmadı: orijinal hedef dosya içeriği korunur.
        let original = ws.dst.appendingPathComponent("rapor.txt")
        #expect(try String(contentsOf: original, encoding: .utf8) == "eski")
    }

    @Test func extensionlessCollisionAlsoNumbered() throws {
        let ws = try makeWorkspace()
        defer { try? fm.removeItem(at: ws.base) }
        _ = try makeFile("Makefile", in: ws.dst)
        let file = try makeFile("Makefile", in: ws.src)

        let result = try FileTransfer.transfer(file, toDirectory: ws.dst, mode: .copy)
        #expect(result.lastPathComponent == "Makefile 2")
    }

    @Test func moveToSameDirectoryIsNoOp() throws {
        let ws = try makeWorkspace()
        defer { try? fm.removeItem(at: ws.base) }
        let file = try makeFile("c.txt", in: ws.src)

        let result = try FileTransfer.transfer(file, toDirectory: ws.src, mode: .move)

        #expect(result == file)
        #expect(fm.fileExists(atPath: file.path))
        #expect(!fm.fileExists(atPath: ws.src.appendingPathComponent("c 2.txt").path))
    }

    @Test func unwritableDestinationThrowsAndKeepsSource() throws {
        let ws = try makeWorkspace()
        defer {
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: ws.dst.path)
            try? fm.removeItem(at: ws.base)
        }
        let file = try makeFile("d.txt", in: ws.src)
        try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: ws.dst.path)

        #expect(throws: (any Error).self) {
            try FileTransfer.transfer(file, toDirectory: ws.dst, mode: .move)
        }
        #expect(fm.fileExists(atPath: file.path), "hata durumunda kaynak bozulmamalı")
    }

    @Test func missingSourceThrows() throws {
        let ws = try makeWorkspace()
        defer { try? fm.removeItem(at: ws.base) }
        let ghost = ws.src.appendingPathComponent("yok.txt")

        #expect(throws: FileTransferError.sourceMissing(ghost.path)) {
            try FileTransfer.transfer(ghost, toDirectory: ws.dst, mode: .move)
        }
    }

    @Test func deliverToExactURLUniquifiesWhenOccupied() throws {
        let ws = try makeWorkspace()
        defer { try? fm.removeItem(at: ws.base) }
        _ = try makeFile("e.txt", in: ws.dst, content: "dolu")
        let file = try makeFile("e.txt", in: ws.src, content: "gelen")

        let target = ws.dst.appendingPathComponent("e.txt")
        let result = try FileTransfer.deliver(file, to: target, mode: .move)

        #expect(result.lastPathComponent == "e 2.txt")
        #expect(try String(contentsOf: target, encoding: .utf8) == "dolu")
        #expect(try String(contentsOf: result, encoding: .utf8) == "gelen")
        #expect(!fm.fileExists(atPath: file.path))
    }
}
