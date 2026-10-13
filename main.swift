// Lapso — メニューバー常駐の目盛り型タイマー
import AppKit
import ServiceManagement
import UserNotifications

// UI文言の日英切替（システムの優先言語が日本語なら日本語、それ以外は英語）
let isJapanese = Locale.preferredLanguages.first?.hasPrefix("ja") == true
func L(_ ja: String, _ en: String) -> String { isJapanese ? ja : en }

enum Mode { case idle, countdown }

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, UNUserNotificationCenterDelegate {
    var item: NSStatusItem!
    let menu = NSMenu()
    let quickMinutes = 30
    var ticker: Timer?

    var mode: Mode = .idle
    var running = false
    var finished = false

    // カウントダウン: 設定時間と終了時刻
    var phaseLength: TimeInterval = 0
    var deadline = Date()
    var pausedRemaining: TimeInterval = 0

    var colorBar = UserDefaults.standard.bool(forKey: "colorBar")

    let segments = 20

    // MARK: - 起動

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.imagePosition = .imageLeft
        menu.delegate = self
        // 左クリック=再生/停止（0:00なら30分スタート）、右クリック=メニュー（item.menu を常設すると左クリックも奪われるため都度付け外し）
        item.button?.target = self
        item.button?.action = #selector(onClick)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert]) { _, _ in }

        ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(ticker!, forMode: .common)

        // 動作確認用（単位は秒）: open Lapso.app --args -start 60
        let start = UserDefaults.standard.double(forKey: "start")
        if start > 0 { startCountdown(start) }
        render()
    }

    // MARK: - 時間計算

    var remaining: TimeInterval { running ? max(0, deadline.timeIntervalSinceNow) : pausedRemaining }

    // MARK: - 操作

    func startCountdown(_ seconds: TimeInterval) {
        mode = .countdown
        finished = false
        phaseLength = seconds
        deadline = Date().addingTimeInterval(phaseLength)
        running = true
        render()
    }

    func togglePause() {
        guard mode != .idle, !finished else { return }
        if running {
            pausedRemaining = remaining
            running = false
        } else {
            deadline = Date().addingTimeInterval(pausedRemaining)
            running = true
        }
        render()
    }

    func reset() {
        mode = .idle
        running = false
        finished = false
        render()
    }

    // MARK: - 毎tick

    func tick() {
        guard running else { return }
        switch mode {
        case .countdown:
            if remaining <= 0 {
                pausedRemaining = 0
                finish(message: L("タイマー終了", "Time's up"))
            }
        case .idle:
            break
        }
        render()
    }

    func finish(message: String) {
        running = false
        finished = true
        notify(message)
    }

    // MARK: - 表示

    func render() {
        guard let button = item?.button else { return }
        var lit = 0
        var seconds: TimeInterval = 0
        switch mode {
        case .idle:
            break
        case .countdown:
            seconds = remaining.rounded(.up)
            let unit = phaseLength / Double(segments)
            lit = unit > 0 ? Int((remaining / unit).rounded(.up)) : 0
        }
        button.image = barImage(lit: min(max(lit, 0), segments), paused: mode != .idle && !running && !finished)

        // 時刻と見間違えないよう「30M00S」表記（M・S は小さく）
        let title = NSMutableAttributedString()
        if mode != .idle {
            let digit: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)]
            let unit: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 9, weight: .medium)]
            title.append(NSAttributedString(string: String(format: " %02d", Int(seconds) / 60), attributes: digit))
            title.append(NSAttributedString(string: "M", attributes: unit))
            title.append(NSAttributedString(string: String(format: "%02d", Int(seconds) % 60), attributes: digit))
            title.append(NSAttributedString(string: "S", attributes: unit))
        }
        button.attributedTitle = title
    }

    // iOS のシステムカラー（ライト / ダーク）
    static let iosGreen = dynamic(0x34C759, 0x30D158)
    static let iosYellow = dynamic(0xFFCC00, 0xFFD60A)
    static let iosRed = dynamic(0xFF3B30, 0xFF453A)

    static func dynamic(_ light: Int, _ dark: Int) -> NSColor {
        func rgb(_ v: Int) -> NSColor {
            NSColor(srgbRed: CGFloat(v >> 16 & 0xFF) / 255, green: CGFloat(v >> 8 & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: 1)
        }
        return NSColor(name: nil) { ap in
            ap.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? rgb(dark) : rgb(light)
        }
    }

    // 20目盛りのバー。消えた目盛りは薄く残す
    // モノクロ: テンプレート画像でライト/ダーク自動追従
    // カラー: 残り11目盛り以上=緑、5〜10=黄、4以下=赤（半分・4分の1で切り替え）
    func barImage(lit: Int, paused: Bool = false) -> NSImage {
        let w: CGFloat = 3, gap: CGFloat = 1, h: CGFloat = 11, imageH: CGFloat = 16
        let size = NSSize(width: CGFloat(segments) * w + CGFloat(segments - 1) * gap, height: imageH)
        let color = colorBar
        // 一時停止中は点灯目盛りを色はそのまま薄くする
        let litAlpha: CGFloat = paused ? 0.4 : 1.0
        let litColor: NSColor = lit > 10 ? Self.iosGreen : lit > 4 ? Self.iosYellow : Self.iosRed
        let image = NSImage(size: size, flipped: false) { _ in
            for i in 0..<self.segments {
                let rect = NSRect(x: CGFloat(i) * (w + gap), y: (imageH - h) / 2, width: w, height: h)
                if color {
                    (i < lit ? litColor.withAlphaComponent(litAlpha) : NSColor.labelColor.withAlphaComponent(0.22)).setFill()
                } else {
                    NSColor.black.withAlphaComponent(i < lit ? litAlpha : 0.22).setFill()
                }
                rect.fill()
            }
            return true
        }
        image.isTemplate = !color
        return image
    }

    // MARK: - 通知

    func notify(_ body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Lapso"
        content.body = body
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner])
    }

    // MARK: - メニュー

    @objc func onClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            item.menu = menu
            item.button?.performClick(nil)
        } else {
            if mode == .idle || finished {
                startCountdown(TimeInterval(quickMinutes * 60))
            } else {
                togglePause()
            }
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        item.menu = nil
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        for m in [30, 60] {
            let i = action(L("\(m)分", "\(m) min"), #selector(onPreset(_:)))
            i.tag = m
            menu.addItem(i)
        }
        if mode != .idle { menu.addItem(action(L("リセット", "Reset"), #selector(onReset))) }
        menu.addItem(.separator())

        let colorItem = action(L("カラー表示", "Color Bar"), #selector(onColor))
        colorItem.state = colorBar ? .on : .off
        menu.addItem(colorItem)
        let login = action(L("ログイン時に起動", "Launch at Login"), #selector(onLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(action(L("Lapsoを終了", "Quit Lapso"), #selector(onQuit)))
    }

    func action(_ title: String, _ sel: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        i.target = self
        return i
    }

    @objc func onPreset(_ sender: NSMenuItem) { startCountdown(TimeInterval(sender.tag * 60)) }
    @objc func onReset() { reset() }
    @objc func onQuit() { NSApp.terminate(nil) }

    @objc func onColor() {
        colorBar.toggle()
        UserDefaults.standard.set(colorBar, forKey: "colorBar")
        render()
    }

    @objc func onLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            showError(L("ログイン項目の設定に失敗しました", "Couldn't update the login item") + ": \(error.localizedDescription)")
        }
    }

    // MARK: - ダイアログ

    func showError(_ text: String) {
        let alert = NSAlert()
        alert.messageText = text
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
