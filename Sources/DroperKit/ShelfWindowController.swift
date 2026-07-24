import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

/// Tek bir yüzen raf: NSPanel + dosya kabul eden içerik + dışarı sürüklenebilir öğe ızgarası.
public final class ShelfWindowController: NSObject {
    public let store = ShelfStore()
    public let panel: NSPanel

    /// Sürükleme tetiklemesiyle açıldıysa true: sürükleme rafa uğramadan biterse
    /// ve raf boşsa kendini kapatır. Menüden açılan raflar açık kalır.
    public let closesWhenDragAbandoned: Bool

    private let settings: SettingsStore
    private let onClosed: (ShelfWindowController) -> Void

    private let itemsStack = NSStackView()
    private let countBadge = NSTextField(labelWithString: "0")
    private let emptyLabel = NSTextField(labelWithString: "Dosyaları buraya bırakın")
    private let errorLabel = NSTextField(labelWithString: "")
    private var errorURLs: Set<URL> = []

    private let promiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "droper.file-promise"
        queue.qualityOfService = .userInitiated
        return queue
    }()

    private static let columns = 3
    private static let cellSize = NSSize(width: 76, height: 86)
    private static let width: CGFloat = 252
    private static let headerHeight: CGFloat = 34
    private static let maxVisibleGridRows = 3

    public init(
        at point: NSPoint,
        settings: SettingsStore,
        closesWhenDragAbandoned: Bool = false,
        onClosed: @escaping (ShelfWindowController) -> Void
    ) {
        self.settings = settings
        self.closesWhenDragAbandoned = closesWhenDragAbandoned
        self.onClosed = onClosed

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 132),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true

        super.init()

        buildContent()
        store.onItemsChanged = { [weak self] in self?.refreshItems() }
        store.onShouldClose = { [weak self] in self?.close() }
        refreshItems()
        position(near: point)
    }

    // MARK: - Görünüm kurulumu

    private func buildContent() {
        let root = ShelfDropView()
        root.material = .hudWindow
        root.state = .active
        root.blendingMode = .behindWindow
        root.wantsLayer = true
        root.layer?.cornerRadius = 12
        root.layer?.masksToBounds = true
        root.onFilesDropped = { [weak self] urls in
            self?.store.add(contentsOf: urls)
        }

        // Başlık: tümünü-sürükle tutamacı, sayaç, kapat.
        let grip = DragAllGripView()
        grip.onDrag = { [weak self] view, event in
            guard let self, !self.store.isEmpty else { return }
            self.beginDrag(of: self.store.items, from: view, with: event)
        }
        grip.setContentHuggingPriority(.required, for: .horizontal)

        countBadge.font = .systemFont(ofSize: 11, weight: .bold)
        countBadge.textColor = .white
        countBadge.alignment = .center
        countBadge.wantsLayer = true
        countBadge.layer?.backgroundColor = NSColor.systemBlue.cgColor
        countBadge.layer?.cornerRadius = 8
        countBadge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            countBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
            countBadge.heightAnchor.constraint(equalToConstant: 16),
        ])

        let closeButton = NSButton(
            title: "✕", target: self, action: #selector(closeButtonPressed))
        closeButton.bezelStyle = .inline
        closeButton.isBordered = false
        closeButton.font = .systemFont(ofSize: 12, weight: .bold)
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.setContentHuggingPriority(.required, for: .horizontal)

        let header = NSStackView(views: [grip, NSView(), countBadge, closeButton])
        header.orientation = .horizontal
        header.spacing = 6
        header.edgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        header.translatesAutoresizingMaskIntoConstraints = false

        itemsStack.orientation = .vertical
        itemsStack.alignment = .leading
        itemsStack.spacing = 4
        itemsStack.edgeInsets = NSEdgeInsets(top: 2, left: 8, bottom: 6, right: 8)
        itemsStack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.verticalScroller?.alphaValue = 0.5
        scroll.documentView = itemsStack
        scroll.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.font = .systemFont(ofSize: 11)
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        errorLabel.font = .systemFont(ofSize: 10)
        errorLabel.textColor = .systemRed
        errorLabel.lineBreakMode = .byTruncatingMiddle
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(header)
        root.addSubview(scroll)
        root.addSubview(emptyLabel)
        root.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: root.topAnchor, constant: 4),
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: Self.headerHeight - 4),

            scroll.topAnchor.constraint(equalTo: header.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -4),

            itemsStack.widthAnchor.constraint(equalTo: scroll.widthAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),

            errorLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 10),
            errorLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -10),
            errorLabel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -4),
        ])

        panel.contentView = root
    }

    // MARK: - Yaşam döngüsü

    public func show() {
        panel.orderFrontRegardless()
    }

    public func close() {
        panel.orderOut(nil)
        onClosed(self)
    }

    @objc private func closeButtonPressed() {
        // Dosyalar zaten yerinde duruyor; kapatmak veri kaybettirmez.
        close()
    }

    private func position(near point: NSPoint) {
        var origin = NSPoint(x: point.x + 16, y: point.y - panel.frame.height + 16)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(point) })
            ?? NSScreen.main {
            let visible = screen.visibleFrame
            origin.x = min(max(origin.x, visible.minX + 4), visible.maxX - panel.frame.width - 4)
            origin.y = min(max(origin.y, visible.minY + 4), visible.maxY - panel.frame.height - 4)
        }
        panel.setFrameOrigin(origin)
    }

    // MARK: - Öğe ızgarası

    private func refreshItems() {
        for view in itemsStack.arrangedSubviews {
            itemsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let urls = store.items
        var index = 0
        while index < urls.count {
            let rowURLs = urls[index..<min(index + Self.columns, urls.count)]
            let cells: [NSView] = rowURLs.map { url in
                let cell = ShelfItemCell(
                    url: url,
                    size: Self.cellSize,
                    showsError: errorURLs.contains(url))
                cell.onDrag = { [weak self] view, event in
                    self?.beginDrag(of: [url], from: view, with: event)
                }
                return cell
            }
            let rowStack = NSStackView(views: cells)
            rowStack.orientation = .horizontal
            rowStack.spacing = 2
            rowStack.alignment = .top
            itemsStack.addArrangedSubview(rowStack)
            index += Self.columns
        }

        countBadge.stringValue = "\(store.count)"
        emptyLabel.isHidden = !store.isEmpty
        resizeToFit()
    }

    private func resizeToFit() {
        let gridRows = max(1, Int(ceil(Double(store.count) / Double(Self.columns))))
        let visibleRows = min(gridRows, Self.maxVisibleGridRows)
        let height = Self.headerHeight + CGFloat(visibleRows) * (Self.cellSize.height + 4) + 12
        var frame = panel.frame
        let topLeft = NSPoint(x: frame.minX, y: frame.maxY)
        frame.size = NSSize(width: Self.width, height: height)
        frame.origin = NSPoint(x: topLeft.x, y: topLeft.y - height)
        panel.setFrame(frame, display: true)
    }

    private func showError(for url: URL) {
        errorURLs.insert(url)
        errorLabel.stringValue = "Taşınamadı: \(url.lastPathComponent)"
        errorLabel.isHidden = false
        refreshItems()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.errorLabel.isHidden = true
        }
    }

    // MARK: - Dışarı sürükleme (file promise)

    private func beginDrag(of urls: [URL], from view: NSView, with event: NSEvent) {
        let location = view.convert(event.locationInWindow, from: nil)
        var draggingItems: [NSDraggingItem] = []
        for (index, url) in urls.enumerated() {
            let provider = NSFilePromiseProvider(
                fileType: Self.fileType(for: url), delegate: self)
            provider.userInfo = url
            let item = NSDraggingItem(pasteboardWriter: provider)
            let image = ThumbnailLoader.shared.cachedImage(for: url)
                ?? NSWorkspace.shared.icon(forFile: url.path)
            let offset = CGFloat(index) * 3
            item.setDraggingFrame(
                NSRect(
                    x: location.x - 24 + offset, y: location.y - 24 - offset,
                    width: 48, height: 48),
                contents: image)
            draggingItems.append(item)
        }
        view.beginDraggingSession(with: draggingItems, event: event, source: self)
    }

    private static func fileType(for url: URL) -> String {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        if isDirectory.boolValue, !url.hasDirectoryPath || url.pathExtension.isEmpty {
            return UTType.folder.identifier
        }
        return UTType(filenameExtension: url.pathExtension)?.identifier
            ?? UTType.data.identifier
    }
}

// MARK: - NSDraggingSource

extension ShelfWindowController: NSDraggingSource {
    public func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }
}

// MARK: - NSFilePromiseProviderDelegate

extension ShelfWindowController: NSFilePromiseProviderDelegate {
    public func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String
    ) -> String {
        (filePromiseProvider.userInfo as? URL)?.lastPathComponent ?? "dosya"
    }

    public func filePromiseProvider(
        _ filePromiseProvider: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard let source = filePromiseProvider.userInfo as? URL else {
            completionHandler(CocoaError(.fileNoSuchFile))
            return
        }
        do {
            try FileTransfer.deliver(source, to: url, mode: settings.transferMode)
            completionHandler(nil)
            DispatchQueue.main.async { [weak self] in
                self?.errorURLs.remove(source)
                self?.store.remove(source)
            }
        } catch {
            completionHandler(error)
            DispatchQueue.main.async { [weak self] in
                self?.showError(for: source)
            }
        }
    }

    public func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        promiseQueue
    }
}

// MARK: - Küçük resim üretici

/// QuickLook önizlemesi üretir ve önbelleğe alır; hazır olana dek sistem ikonu döner.
final class ThumbnailLoader {
    static let shared = ThumbnailLoader()

    private var cache: [URL: NSImage] = [:]

    func cachedImage(for url: URL) -> NSImage? {
        cache[url.standardizedFileURL]
    }

    /// `update` en az bir kez hemen (ikonla), önizleme üretilince ikinci kez çağrılır.
    func loadThumbnail(for url: URL, size: CGSize, update: @escaping (NSImage) -> Void) {
        let key = url.standardizedFileURL
        if let cached = cache[key] {
            update(cached)
            return
        }
        update(NSWorkspace.shared.icon(forFile: url.path))

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url, size: size, scale: scale, representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            [weak self] representation, _ in
            guard let representation else { return }
            let image = representation.nsImage
            DispatchQueue.main.async {
                self?.cache[key] = image
                update(image)
            }
        }
    }
}

// MARK: - Dosya kabul eden zemin

final class ShelfDropView: NSVisualEffectView {
    var onFilesDropped: (([URL]) -> Void)?

    private let readOptions: [NSPasteboard.ReadingOptionKey: Any] = [
        .urlReadingFileURLsOnly: true
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard canRead(sender) else { return [] }
        animator().alphaValue = 0.85
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        animator().alphaValue = 1
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        animator().alphaValue = 1
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard
            let urls = sender.draggingPasteboard.readObjects(
                forClasses: [NSURL.self], options: readOptions) as? [URL],
            !urls.isEmpty
        else { return false }
        onFilesDropped?(urls)
        return true
    }

    private func canRead(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: readOptions)
    }
}

// MARK: - Tümünü sürükle tutamacı

final class DragAllGripView: NSView {
    var onDrag: ((NSView, NSEvent) -> Void)?
    private var dragStarted = false

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor =
            NSColor.secondaryLabelColor.withAlphaComponent(0.18).cgColor

        let label = NSTextField(labelWithString: "☰ Tümünü sürükle")
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 20),
        ])
        toolTip = "Tüm öğeleri tek harekette sürükleyip hedefe bırak"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    // Tıklama pencereyi TAŞIMASIN; sürükleme öğeleri götürsün.
    override var mouseDownCanMoveWindow: Bool { false }

    // Etiket tıklamayı yutmasın; sürükleme bu görünümden başlasın.
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        dragStarted = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !dragStarted else { return }
        dragStarted = true
        onDrag?(self, event)
    }

    override func mouseUp(with event: NSEvent) {
        dragStarted = false
    }
}

// MARK: - Izgara hücresi

final class ShelfItemCell: NSView {
    let url: URL
    var onDrag: ((NSView, NSEvent) -> Void)?
    private var dragStarted = false
    private let thumbView = NSImageView()

    init(url: URL, size: NSSize, showsError: Bool) {
        self.url = url
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        thumbView.imageScaling = .scaleProportionallyUpOrDown
        thumbView.wantsLayer = true
        thumbView.layer?.cornerRadius = 6
        thumbView.layer?.masksToBounds = true
        thumbView.translatesAutoresizingMaskIntoConstraints = false

        let name = NSTextField(labelWithString: url.lastPathComponent)
        name.font = .systemFont(ofSize: 9)
        name.textColor = .secondaryLabelColor
        name.alignment = .center
        name.lineBreakMode = .byTruncatingMiddle
        name.translatesAutoresizingMaskIntoConstraints = false

        addSubview(thumbView)
        addSubview(name)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size.width),
            heightAnchor.constraint(equalToConstant: size.height),

            thumbView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            thumbView.centerXAnchor.constraint(equalTo: centerXAnchor),
            thumbView.widthAnchor.constraint(equalToConstant: 56),
            thumbView.heightAnchor.constraint(equalToConstant: 56),

            name.topAnchor.constraint(equalTo: thumbView.bottomAnchor, constant: 2),
            name.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            name.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
        ])

        if showsError {
            let badge = NSTextField(labelWithString: "⚠︎")
            badge.font = .systemFont(ofSize: 12, weight: .bold)
            badge.textColor = .systemRed
            badge.toolTip = "Bu öğe taşınamadı; rafta bekliyor."
            badge.translatesAutoresizingMaskIntoConstraints = false
            addSubview(badge)
            NSLayoutConstraint.activate([
                badge.topAnchor.constraint(equalTo: topAnchor, constant: 2),
                badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            ])
        }

        toolTip = url.path

        ThumbnailLoader.shared.loadThumbnail(
            for: url, size: NSSize(width: 56, height: 56)
        ) { [weak thumbView] image in
            thumbView?.image = image
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    // Hücrenin HER noktası (yazı dahil) pencereyi taşımak yerine öğeyi sürükler.
    override var mouseDownCanMoveWindow: Bool { false }

    // Alt görünümler (resim/etiket) tıklamayı yutmasın; sürükleme hücreden başlasın.
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        dragStarted = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !dragStarted else { return }
        dragStarted = true
        onDrag?(self, event)
    }

    override func mouseUp(with event: NSEvent) {
        dragStarted = false
    }
}
