import AppKit
import Darwin
import SQLite3

final class AlertWindow: NSPanel {
    // Notifications must leave keyboard input with the user's current app.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class AlertView: NSView {
    let options: Options
    let icon: NSImage

    init(frame frameRect: NSRect, options: Options, icon: NSImage) {
        self.options = options
        self.icon = icon
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if options.theme == "classic" {
            drawClassic()
        } else {
            drawBeacon()
        }
    }

    private func drawBeacon() {
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let accent = options.color
        let base = dark ? hexColor(0x292724) : hexColor(0xfffaf5)
        let background = base.blended(withFraction: dark ? 0.08 : 0.04, of: accent) ?? base
        let ink = dark ? hexColor(0xffeddf) : hexColor(0x463225)
        let secondary = dark ? hexColor(0xcbb49e) : hexColor(0x88705c)
        let rect = bounds.insetBy(dx: 7, dy: 7)
        let outline = NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(dark ? 0.30 : 0.15)
        shadow.shadowBlurRadius = 7
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.set()
        background.setFill()
        outline.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.saveGraphicsState()
        outline.addClip()
        accent.setFill()
        NSBezierPath(rect: NSRect(x: rect.minX, y: rect.minY, width: 5, height: rect.height)).fill()
        NSGraphicsContext.restoreGraphicsState()

        let iconSize = min(56, rect.height - 28)
        let tile = NSRect(x: rect.minX + 20, y: rect.midY - iconSize / 2, width: iconSize, height: iconSize)
        NSGraphicsContext.saveGraphicsState()
        let rotation = NSAffineTransform()
        rotation.translateX(by: tile.midX, yBy: tile.midY)
        rotation.rotate(byDegrees: 6)
        rotation.translateX(by: -tile.midX, yBy: -tile.midY)
        rotation.concat()
        (background.blended(withFraction: dark ? 0.22 : 0.18, of: accent) ?? accent).setFill()
        NSBezierPath(roundedRect: tile, xRadius: 14, yRadius: 14).fill()
        NSGraphicsContext.restoreGraphicsState()

        let imageRect = tile.insetBy(dx: options.iconPath == nil ? 15 : 6, dy: options.iconPath == nil ? 15 : 6)
        let size = icon.size
        if size.width > 0 && size.height > 0 {
            let scale = min(imageRect.width / size.width, imageRect.height / size.height)
            let target = NSRect(x: imageRect.midX - size.width * scale / 2,
                                y: imageRect.midY - size.height * scale / 2,
                                width: size.width * scale, height: size.height * scale)
            icon.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1,
                      respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        }

        let x = tile.maxX + 16
        let width = max(1, rect.maxX - x - 18)
        if options.dynamicContent {
            drawText(options.title.uppercased(), rect: NSRect(x: x, y: rect.midY + 22, width: width, height: 14),
                     font: .systemFont(ofSize: 9, weight: .medium), color: secondary, tracking: 0.7)
            drawText(options.message, rect: NSRect(x: x, y: rect.midY - 19, width: width, height: 39),
                     font: .systemFont(ofSize: 14.5, weight: .semibold), color: ink, multiline: true)
            drawText(options.subtitle, rect: NSRect(x: x, y: rect.midY - 36, width: width, height: 15),
                     font: .systemFont(ofSize: 10.5), color: secondary)
        } else {
            drawText(options.title.uppercased(), rect: NSRect(x: x, y: rect.midY + 16, width: width, height: 15),
                     font: .systemFont(ofSize: 9, weight: .medium), color: secondary, tracking: 1.1)
            drawText(options.message, rect: NSRect(x: x, y: rect.midY - 7, width: width, height: 23),
                     font: .systemFont(ofSize: 17, weight: .semibold), color: ink)
            drawText(options.subtitle, rect: NSRect(x: x, y: rect.midY - 29, width: width, height: 18),
                     font: .systemFont(ofSize: 12), color: secondary)
        }
    }

    private func drawText(_ text: String, rect: NSRect, font: NSFont, color: NSColor, tracking: CGFloat = 0, multiline: Bool = false) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = .left
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph, .kern: tracking
        ]
        if multiline {
            NSAttributedString(string: text, attributes: attributes).draw(
                with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        } else {
            (text as NSString).draw(in: rect, withAttributes: attributes)
        }
    }

    private func drawClassic() {
        let color = options.color

        let bubbleRect = bounds.insetBy(dx: 6, dy: 12)
            .offsetBy(dx: 0, dy: 8)
        let radius: CGFloat = min(28, bubbleRect.height * 0.38)

        // soft white highlight behind the bubble, similar to modern chat icons
        let shadowPath = NSBezierPath(roundedRect: bubbleRect.offsetBy(dx: -3, dy: -3), xRadius: radius, yRadius: radius)
        NSColor.white.withAlphaComponent(0.18).setFill()
        shadowPath.fill()

        // main rounded bubble
        let path = NSBezierPath(roundedRect: bubbleRect, xRadius: radius, yRadius: radius)

        // right-bottom tail
        let tail = NSBezierPath()
        let tailBaseX = bubbleRect.maxX - bubbleRect.width * 0.25
        let tailBaseY = bubbleRect.minY + 8
        tail.move(to: NSPoint(x: tailBaseX, y: tailBaseY + 4))
        tail.curve(
            to: NSPoint(x: bubbleRect.maxX - 28, y: bounds.minY + 10),
            controlPoint1: NSPoint(x: tailBaseX + 8, y: tailBaseY - 6),
            controlPoint2: NSPoint(x: bubbleRect.maxX - 42, y: bounds.minY + 14)
        )
        tail.curve(
            to: NSPoint(x: bubbleRect.maxX - 42, y: bubbleRect.minY + 15),
            controlPoint1: NSPoint(x: bubbleRect.maxX - 34, y: bounds.minY + 20),
            controlPoint2: NSPoint(x: bubbleRect.maxX - 43, y: bubbleRect.minY + 8)
        )
        tail.close()

        color.setFill()
        path.fill()
        tail.fill()

        NSColor.white.withAlphaComponent(0.22).setStroke()
        path.lineWidth = 2
        path.stroke()

        // three chat dots
        NSColor.white.withAlphaComponent(0.92).setFill()
        let dotSize: CGFloat = max(8, bounds.height * 0.10)
        let gap: CGFloat = dotSize * 0.75
        let startX = bubbleRect.minX + 30
        let centerY = bubbleRect.midY
        for i in 0..<3 {
            let x = startX + CGFloat(i) * (dotSize + gap)
            let dot = NSBezierPath(ovalIn: NSRect(x: x, y: centerY - dotSize / 2, width: dotSize, height: dotSize))
            dot.fill()
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        (options.message as NSString).draw(in: NSRect(x: bounds.width * 0.34, y: bounds.height * 0.28,
                                                     width: bounds.width * 0.58, height: bounds.height * 0.46),
                                           withAttributes: [.font: NSFont.systemFont(ofSize: max(18, bounds.height * 0.24), weight: .bold),
                                                            .foregroundColor: NSColor.white, .paragraphStyle: paragraph])
    }

    override func mouseDown(with event: NSEvent) {
        NSApp.terminate(nil)
    }
}

struct Options {
    var message = "Codex"
    var title = "Hoàn tất"
    var subtitle = ""
    var subtitleProvided = false
    var theme = "beacon"
    var iconPath: String?
    var symbol = "bolt.fill"
    var duration: TimeInterval = 10
    var color = NSColor(calibratedRed: 0.93, green: 0.53, blue: 0.33, alpha: 1.0)
    var width: CGFloat = 364
    var height: CGFloat = 118
    var position = "center"
    var margin: CGFloat = 24
    var readEvent = true
    var dynamicContent = false
}

struct ProjectAlert: Decodable {
    var path: String
    var name: String
    var icon: String?
}

struct AlertSettings: Decodable {
    var projects: [ProjectAlert]
}

func condensed(_ text: String, limit: Int) -> String {
    let clean = text.components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }.joined(separator: " ")
    return clean.count > limit ? String(clean.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…" : clean
}

func alertTime(_ date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "vi_VN")
    formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
    formatter.dateFormat = "HH:mm:ss"
    return formatter.string(from: date)
}

func eventThreadID(_ event: [String: Any]) -> String? {
    for key in ["session_id", "thread_id", "thread-id"] {
        if let id = event[key] as? String, !id.isEmpty { return id }
    }
    return nil
}

func threadTitle(_ event: [String: Any], codexHome: URL? = nil) -> String? {
    for key in ["thread_title", "thread_name", "thread-title"] {
        if let title = event[key] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return condensed(title, limit: 140)
        }
    }
    guard let id = eventThreadID(event) else { return nil }
    let home = codexHome ?? ProcessInfo.processInfo.environment["CODEX_HOME"].flatMap {
        $0.isEmpty ? nil : URL(fileURLWithPath: $0)
    } ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
    var fallback: String?
    for relative in ["state_5.sqlite", "sqlite/state_5.sqlite"] {
        let path = home.appendingPathComponent(relative).path
        guard FileManager.default.fileExists(atPath: path) else { continue }
        var handle: OpaquePointer?
        guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK,
              let database = handle else {
            if let handle { sqlite3_close(handle) }
            continue
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 20)
        // The app's curated/renamed title is `name`; older CLI databases only
        // have `title`, which may still contain the original user prompt.
        for column in ["name", "title"] {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, "SELECT \(column) FROM threads WHERE id = ? LIMIT 1", -1, &statement, nil) == SQLITE_OK,
                  let query = statement else { continue }
            defer { sqlite3_finalize(query) }
            sqlite3_bind_text(query, 1, id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            if sqlite3_step(query) == SQLITE_ROW, let value = sqlite3_column_text(query, 0) {
                let text = String(cString: value).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    if column == "name" { return condensed(text, limit: 140) }
                    if fallback == nil { fallback = condensed(text, limit: 140) }
                }
            }
        }
    }
    // The session index also carries CLI titles and renamed conversation names.
    if let file = try? FileHandle(forReadingFrom: home.appendingPathComponent("session_index.jsonl")) {
        defer { try? file.close() }
        if let size = try? file.seekToEnd() {
            let offset = size > 2_097_152 ? size - 2_097_152 : 0
            try? file.seek(toOffset: offset)
            if let data = try? file.readToEnd(), let text = String(data: data, encoding: .utf8) {
                var indexed: String?
                for line in text.split(separator: "\n") {
                    guard let raw = line.data(using: .utf8),
                          let entry = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
                          entry["id"] as? String == id,
                          let title = entry["thread_name"] as? String,
                          !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                    indexed = condensed(title, limit: 140)
                }
                if let indexed { return indexed }
            }
        }
    }
    return fallback
}

func resultSummary(_ message: String) -> String {
    var fenced = false
    for raw in message.components(separatedBy: .newlines) {
        var line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.hasPrefix("```") || line.hasPrefix("~~~") { fenced.toggle(); continue }
        if fenced || line.isEmpty || line.hasPrefix("::") { continue }
        line = line.replacingOccurrences(of: #"!?\[([^\]]+)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        line = line.replacingOccurrences(of: #"^\s*(?:#{1,6}\s*|[-*>]\s+|\d+[.)]\s+)"#, with: "", options: .regularExpression)
        line = line.replacingOccurrences(of: #"[`*_]"#, with: "", options: .regularExpression)
        if !line.trimmingCharacters(in: .whitespaces).isEmpty { return condensed(line, limit: 95) }
    }
    return "Đã kết thúc lượt xử lý."
}

func readHookEvent() -> [String: Any]? {
    guard isatty(STDIN_FILENO) == 0 else { return nil }
    var input = Data()
    var buffer = [UInt8](repeating: 0, count: 8192)
    let deadline = Date().addingTimeInterval(0.15)
    // A normal interactive invocation may inherit an open, empty pipe. Never
    // block waiting for it, and bound the size of the hook's JSON payload.
    while input.count < 1_048_576 && Date() < deadline {
        var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
        guard poll(&descriptor, 1, input.isEmpty ? 50 : 20) > 0,
              descriptor.revents & Int16(POLLIN | POLLHUP) != 0 else { break }
        let count = Darwin.read(STDIN_FILENO, &buffer, min(buffer.count, 1_048_576 - input.count))
        if count <= 0 { break }
        input.append(contentsOf: buffer.prefix(count))
    }
    guard !input.isEmpty,
          let event = try? JSONSerialization.jsonObject(with: input) as? [String: Any] else { return nil }
    return event
}

func applyingHookEvent(_ event: [String: Any]?, to original: Options, projects: [ProjectAlert], at date: Date = Date()) -> Options {
    guard let event,
          event["hook_event_name"] as? String == "Stop" || event["type"] as? String == "agent-turn-complete" else { return original }
    var options = original
    let rawCwd = event["cwd"] as? String ?? ""
    let cwd = rawCwd.isEmpty ? "" : URL(fileURLWithPath: rawCwd).standardizedFileURL.path
    let project = projects.filter {
        let path = URL(fileURLWithPath: ($0.path as NSString).expandingTildeInPath).standardizedFileURL.path
        return cwd == path || cwd.hasPrefix(path.hasSuffix("/") ? path : path + "/")
    }.max { $0.path.count < $1.path.count }
    let projectName = project?.name ?? (cwd.isEmpty ? "" : URL(fileURLWithPath: cwd).lastPathComponent)
    options.title = projectName.isEmpty ? "Codex" : "Codex · " + condensed(projectName, limit: 32)
    options.message = resultSummary(event["last_assistant_message"] as? String ?? event["last-assistant-message"] as? String ?? "")
    options.subtitle = threadTitle(event) ?? eventThreadID(event).map { "Thread " + String($0.prefix(8)) } ?? ""
    options.dynamicContent = true
    if original.iconPath == nil, let path = project?.icon {
        let expanded = (path as NSString).expandingTildeInPath
        if let image = NSImage(contentsOfFile: expanded), image.size.width > 0, image.size.height > 0 {
            options.iconPath = expanded
        }
    }
    return options
}

func hexColor(_ value: Int) -> NSColor {
    NSColor(calibratedRed: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255, alpha: 1)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("mac-alert: " + message + "\n").utf8))
    exit(1)
}

func loadIcon(options: Options) -> NSImage {
    if let raw = options.iconPath {
        let path = (raw as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: path) else { fail("Icon file does not exist: " + path) }
        if URL(fileURLWithPath: path).pathExtension.lowercased() == "app" {
            return NSWorkspace.shared.icon(forFile: path)
        }
        guard let image = NSImage(contentsOfFile: path), image.size.width > 0, image.size.height > 0 else {
            fail("Cannot read icon image: " + path + ". Use PNG, JPEG, ICNS or an app bundle.")
        }
        return image
    }
    guard let image = NSImage(systemSymbolName: options.symbol, accessibilityDescription: nil) else {
        fail("Unknown SF Symbol: " + options.symbol)
    }
    let configuration = NSImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        .applying(NSImage.SymbolConfiguration(paletteColors: [options.color]))
    return image.withSymbolConfiguration(configuration) ?? image
}

func parseColor(_ raw: String) -> NSColor {
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch value {
    case "green": return NSColor(calibratedRed: 0.0, green: 0.90, blue: 0.35, alpha: 1.0)
    case "red": return NSColor(calibratedRed: 1.0, green: 0.10, blue: 0.10, alpha: 1.0)
    case "yellow": return NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.0, alpha: 1.0)
    case "purple": return NSColor(calibratedRed: 0.55, green: 0.25, blue: 1.0, alpha: 1.0)
    case "blue": return NSColor(calibratedRed: 0.0, green: 0.42, blue: 1.0, alpha: 1.0)
    case "orange": return NSColor(calibratedRed: 1.0, green: 0.48, blue: 0.0, alpha: 1.0)
    default:
        var hex = value
        if hex.hasPrefix("#") { hex.removeFirst() }
        if hex.count == 6, let number = Int(hex, radix: 16) {
            return NSColor(
                calibratedRed: CGFloat((number >> 16) & 0xff) / 255.0,
                green: CGFloat((number >> 8) & 0xff) / 255.0,
                blue: CGFloat(number & 0xff) / 255.0,
                alpha: 1.0
            )
        }
        return NSColor(calibratedRed: 0.0, green: 0.90, blue: 0.35, alpha: 1.0)
    }
}

func parseDuration(_ raw: String) -> TimeInterval {
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if value.hasSuffix("ms"), let n = Double(value.dropLast(2)) {
        return max(0.1, n / 1000.0)
    }
    if value.hasSuffix("s"), let n = Double(value.dropLast()) {
        return max(0.1, n)
    }
    if value.hasSuffix("m"), let n = Double(value.dropLast()) {
        return max(0.1, n * 60.0)
    }
    if let n = Double(value) {
        return max(0.1, n)
    }
    return 10
}

func parseOptions() -> Options {
    var options = Options()
    var args = Array(CommandLine.arguments.dropFirst())

    if args.count == 1, !args[0].hasPrefix("-") {
        options.message = args[0]
        return options
    }

    while !args.isEmpty {
        let arg = args.removeFirst()
        switch arg {
        case "--result-layout":
            options.dynamicContent = true
        case "--no-event":
            options.readEvent = false
        case "--theme":
            if !args.isEmpty { options.theme = args.removeFirst().lowercased() }
        case "--title", "-t":
            if !args.isEmpty { options.title = args.removeFirst() }
        case "--subtitle":
            if !args.isEmpty {
                options.subtitle = args.removeFirst()
                options.subtitleProvided = true
            }
        case "--icon", "-i":
            if !args.isEmpty { options.iconPath = args.removeFirst() }
        case "--symbol":
            if !args.isEmpty { options.symbol = args.removeFirst() }
        case "--message", "-m":
            if !args.isEmpty { options.message = args.removeFirst() }
        case "--duration", "-d":
            if !args.isEmpty { options.duration = parseDuration(args.removeFirst()) }
        case "--color", "-c":
            if !args.isEmpty { options.color = parseColor(args.removeFirst()) }
        case "--width":
            if !args.isEmpty, let width = Double(args.removeFirst()) { options.width = CGFloat(width) }
        case "--height":
            if !args.isEmpty, let height = Double(args.removeFirst()) { options.height = CGFloat(height) }
        case "--position", "-p":
            if !args.isEmpty { options.position = args.removeFirst().lowercased() }
        case "--margin":
            if !args.isEmpty, let margin = Double(args.removeFirst()) { options.margin = CGFloat(margin) }
        case "--help", "-h":
            print("""
            Usage:
              mac-alert "Codex done"
              mac-alert --message "Codex done" --color green --duration 10s
              mac-alert --title "My Supporter" --message "Đồng bộ xong" --icon /path/to/icon.png

            Theme: beacon (default), classic
            Content: --title, --message, --subtitle
            Codex Stop JSON on stdin supplies project/result text automatically.
            --no-event keeps the explicitly supplied text, ignoring stdin.
            Icon: --icon /path/to/image.png (also JPEG, ICNS, .app)
                  --symbol bolt.fill (any available SF Symbol; default: bolt.fill)
            Colors: green, red, yellow, purple, blue, orange, #00ffcc
            Duration: 500ms, 10s, 1m, or bare seconds
            Position: center, bottom-right, bottom-left, top-right, top-left
            Dismiss: click popup or wait for its duration
            The popup does not activate or take keyboard focus.
            """)
            exit(0)
        default:
            if !arg.hasPrefix("-") { options.message = arg }
        }
    }

    guard ["beacon", "classic"].contains(options.theme) else { fail("Unknown theme: " + options.theme) }
    guard options.width.isFinite, options.height.isFinite, options.margin.isFinite else {
        fail("Window dimensions and margin must be finite numbers.")
    }
    options.width = max(260, options.width)
    options.height = max(100, options.height)
    return options
}

var parsedOptions = parseOptions()
if !parsedOptions.subtitleProvided && parsedOptions.subtitle.isEmpty {
    parsedOptions.subtitle = "Thông báo lúc " + alertTime()
}
let settingsURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/mac-alert-projects.json")
let settings = (try? Data(contentsOf: settingsURL)).flatMap { try? JSONDecoder().decode(AlertSettings.self, from: $0) }
let hookEvent = parsedOptions.readEvent ? readHookEvent() : nil
let options = applyingHookEvent(hookEvent,
                                to: parsedOptions, projects: settings?.projects ?? [])

// Let the Stop hook return promptly; its two-second timeout must not kill the
// popup or make the turn wait for the display duration. No shell is involved.
if hookEvent != nil && options.dynamicContent && parsedOptions.readEvent {
    let popup = Process()
    popup.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    popup.arguments = Array(CommandLine.arguments.dropFirst()) + [
        "--no-event", "--result-layout", "--title", options.title,
        "--message", options.message, "--subtitle", options.subtitle
    ] + (options.iconPath.map { ["--icon", $0] } ?? [])
    popup.standardInput = FileHandle.nullDevice
    popup.standardOutput = FileHandle.nullDevice
    popup.standardError = FileHandle.nullDevice
    do { try popup.run() } catch { fail("Cannot start popup: " + error.localizedDescription) }
    print("{}")
    exit(0)
}

func windowOrigin(screen: NSRect, options: Options) -> NSPoint {
    let m = options.margin
    switch options.position {
    case "bottom-right", "right-bottom", "br":
        return NSPoint(x: screen.maxX - options.width - m, y: screen.minY + m)
    case "bottom-left", "left-bottom", "bl":
        return NSPoint(x: screen.minX + m, y: screen.minY + m)
    case "top-right", "right-top", "tr":
        return NSPoint(x: screen.maxX - options.width - m, y: screen.maxY - options.height - m)
    case "top-left", "left-top", "tl":
        return NSPoint(x: screen.minX + m, y: screen.maxY - options.height - m)
    default:
        return NSPoint(x: screen.midX - options.width / 2, y: screen.midY - options.height / 2)
    }
}

let app = NSApplication.shared
// Also prevent AppKit's launch lifecycle from activating this helper app.
app.setActivationPolicy(.prohibited)
let icon = loadIcon(options: options)

let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
let origin = windowOrigin(screen: screen, options: options)

let window = AlertWindow(
    contentRect: NSRect(x: origin.x, y: origin.y, width: options.width, height: options.height),
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)
window.isOpaque = false
window.backgroundColor = .clear
window.hasShadow = true
window.hidesOnDeactivate = false
window.becomesKeyOnlyIfNeeded = true
window.level = .screenSaver
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

let view = AlertView(frame: NSRect(x: 0, y: 0, width: options.width, height: options.height), options: options, icon: icon)

window.contentView = view
window.orderFrontRegardless()

DispatchQueue.main.asyncAfter(deadline: .now() + options.duration) {
    NSApp.terminate(nil)
}

app.run()
