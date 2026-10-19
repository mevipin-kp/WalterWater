import AppKit
import SwiftUI
import QuartzCore

@main
struct WalterWaterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var reminderTimer: Timer?
    private var alertWindow: NSWindow?
    private let intervalKey = "reminderInterval"
    private let pausedKey = "remindersPaused"

    private var interval: TimeInterval {
        let saved = UserDefaults.standard.double(forKey: intervalKey)
        return saved == 0 ? 3600 : saved
    }
    private var isPaused: Bool { UserDefaults.standard.bool(forKey: pausedKey) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildMenu()
        scheduleReminder()
    }

    private func buildMenu() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem.button?.title = "💧"
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Walter Water", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(item("Remind every 30 minutes", action: #selector(set30Minutes)))
        menu.addItem(item("Remind every hour", action: #selector(setOneHour)))
        menu.addItem(item("Remind every 2 hours", action: #selector(setTwoHours)))
        menu.addItem(.separator())
        menu.addItem(item("Remind me now", action: #selector(remindNow)))
        menu.addItem(item(isPaused ? "Resume reminders" : "Pause reminders", action: #selector(togglePause)))
        menu.addItem(.separator())
        menu.addItem(item("Quit Walter Water", action: #selector(quitApp), key: "q"))
        statusItem.menu = menu
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let value = NSMenuItem(title: title, action: action, keyEquivalent: key)
        value.target = self
        return value
    }

    private func setInterval(_ value: TimeInterval) {
        UserDefaults.standard.set(value, forKey: intervalKey)
        scheduleReminder()
    }
    @objc private func set30Minutes() { setInterval(1800) }
    @objc private func setOneHour() { setInterval(3600) }
    @objc private func setTwoHours() { setInterval(7200) }
    @objc private func remindNow() { showReminder() }
    @objc private func togglePause() {
        UserDefaults.standard.set(!isPaused, forKey: pausedKey)
        buildMenu()
        scheduleReminder()
    }
    @objc private func quitApp() { NSApp.terminate(nil) }

    private func scheduleReminder(after delay: TimeInterval? = nil) {
        reminderTimer?.invalidate()
        guard !isPaused else { return }
        reminderTimer = Timer.scheduledTimer(withTimeInterval: delay ?? interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.showReminder()
            self.scheduleReminder()
        }
    }

    private func showReminder() {
        if let alertWindow, alertWindow.isVisible {
            alertWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let size = NSSize(width: 390, height: 450)
        let finalFrame = NSRect(x: screen.visibleFrame.midX - size.width / 2,
                                y: screen.visibleFrame.midY - size.height / 2,
                                width: size.width, height: size.height)
        let startFrame = finalFrame.offsetBy(dx: -screen.visibleFrame.width - size.width, dy: 0)
        let content = FloatingReminderView(onDrank: { [weak self] in self?.closeReminder() }, onSnooze: { [weak self] in
            self?.closeReminder()
            self?.scheduleReminder(after: 600)
        })
        let window = NSWindow(contentRect: startFrame,
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .floating
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: content.frame(width: size.width, height: size.height))
        alertWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 1.05
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(finalFrame, display: true)
        }
    }

    private func closeReminder() {
        guard let window = alertWindow else { return }
        let destination = window.frame.offsetBy(dx: -window.frame.width - 30, dy: 0)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.55
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().setFrame(destination, display: true)
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self, weak window] in
            window?.close()
            self?.alertWindow = nil
        })
    }
}

struct FloatingReminderView: View {
    let onDrank: () -> Void
    let onSnooze: () -> Void
    @State private var confirmed = false
    @State private var leaving = false

    var body: some View {
        VStack(spacing: 13) {
            HStack(spacing: 7) {
                Image(systemName: "drop.fill").foregroundStyle(.cyan)
                Text("WATER BREAK").font(.caption.weight(.bold)).tracking(2).foregroundStyle(.secondary)
            }
            AnimatedBottleView(confirmed: confirmed).frame(width: 150, height: 205).padding(.top, 2)
            Text(confirmed ? "Great job!" : "Time to hydrate")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .contentTransition(.opacity)
            Text(confirmed ? "Keep taking care of yourself." : "Take a few sips of water.")
                .font(.system(size: 14)).foregroundStyle(.secondary)

            if confirmed {
                Label("Water break complete", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.semibold)).foregroundStyle(.green).padding(.top, 7)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: confirmDrank) {
                    Label("I drank water", systemImage: "checkmark")
                        .font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 11)
                }
                .buttonStyle(.borderedProminent).tint(.cyan).keyboardShortcut(.defaultAction).padding(.horizontal, 18)
                Button("Remind me in 10 minutes", action: onSnooze)
                    .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 22).frame(width: 390, height: 450)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.regularMaterial)
                .overlay { RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.7), lineWidth: 1) }
                .shadow(color: .black.opacity(0.18), radius: 34, y: 18)
        }
        .scaleEffect(leaving ? 0.72 : 1).opacity(leaving ? 0 : 1)
        .animation(.spring(response: 0.5, dampingFraction: 0.72), value: leaving)
    }

    private func confirmDrank() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) { confirmed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            withAnimation(.easeInOut(duration: 0.4)) { leaving = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { onDrank() }
    }
}

struct AnimatedBottleView: View {
    let confirmed: Bool
    @State private var floating = false
    @State private var shimmer = false
    @State private var bubbles = false

    var body: some View {
        ZStack {
            Circle().fill(Color.cyan.opacity(0.09)).frame(width: 146, height: 146)
            Circle().stroke(Color.cyan.opacity(0.13), lineWidth: 1).frame(width: 174, height: 174)
                .scaleEffect(shimmer ? 1.08 : 0.94).opacity(shimmer ? 0.35 : 0.8)
                .animation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true), value: shimmer)

            BottleShape()
                .fill(LinearGradient(colors: [.white, Color(red: 0.82, green: 0.96, blue: 1)], startPoint: .leading, endPoint: .trailing))
                .overlay {
                    WaterFillShape(progress: confirmed ? 0.9 : 0.63)
                        .fill(LinearGradient(colors: [.cyan.opacity(0.7), .blue.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                        .clipShape(BottleShape()).padding(3).animation(.easeInOut(duration: 0.8), value: confirmed)
                }
                .overlay { BottleShape().stroke(Color.cyan.opacity(0.65), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round)) }
                .overlay {
                    VStack(spacing: 3) {
                        Text("WATER").font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1.2)
                        Image(systemName: "drop.fill").font(.system(size: 17))
                    }
                    .foregroundStyle(.white.opacity(0.95)).padding(.vertical, 9).padding(.horizontal, 13)
                    .background(.blue.opacity(0.28), in: RoundedRectangle(cornerRadius: 10)).offset(y: 30)
                }
                .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 4).fill(.blue.gradient).frame(width: 35, height: 16).offset(y: -8) }
                .frame(width: 91, height: 154)
                .rotationEffect(.degrees(confirmed ? 7 : (floating ? 3 : -3)), anchor: .bottom)
                .offset(y: floating ? -8 : 8)
                .animation(.easeInOut(duration: 1.55).repeatForever(autoreverses: true), value: floating)

            ForEach(0..<4) { index in
                Circle().fill(.cyan.opacity(0.7)).frame(width: CGFloat(5 + index % 2 * 3), height: CGFloat(5 + index % 2 * 3))
                    .offset(x: CGFloat(index - 2) * 24, y: bubbles ? -68 : 24).opacity(bubbles ? 0.1 : 0.9)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true).delay(Double(index) * 0.22), value: bubbles)
            }

            Image(systemName: confirmed ? "checkmark.circle.fill" : "sparkle")
                .font(.system(size: 27, weight: .medium)).foregroundStyle(confirmed ? Color.green : Color.cyan)
                .offset(x: 61, y: -69).scaleEffect(shimmer ? 1.12 : 0.82)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: shimmer)
        }
        .onAppear { floating = true; shimmer = true; bubbles = true }
        .accessibilityLabel("Floating animated water bottle")
    }
}

struct BottleShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.36, y: rect.height * 0.03))
            path.addLine(to: CGPoint(x: rect.width * 0.64, y: rect.height * 0.03))
            path.addLine(to: CGPoint(x: rect.width * 0.64, y: rect.height * 0.18))
            path.addCurve(to: CGPoint(x: rect.width * 0.84, y: rect.height * 0.32), control1: CGPoint(x: rect.width * 0.64, y: rect.height * 0.25), control2: CGPoint(x: rect.width * 0.84, y: rect.height * 0.24))
            path.addLine(to: CGPoint(x: rect.width * 0.95, y: rect.height * 0.87))
            path.addQuadCurve(to: CGPoint(x: rect.width * 0.84, y: rect.height * 0.98), control: CGPoint(x: rect.width * 0.94, y: rect.height * 0.98))
            path.addLine(to: CGPoint(x: rect.width * 0.16, y: rect.height * 0.98))
            path.addQuadCurve(to: CGPoint(x: rect.width * 0.05, y: rect.height * 0.87), control: CGPoint(x: rect.width * 0.06, y: rect.height * 0.98))
            path.addLine(to: CGPoint(x: rect.width * 0.16, y: rect.height * 0.32))
            path.addCurve(to: CGPoint(x: rect.width * 0.36, y: rect.height * 0.18), control1: CGPoint(x: rect.width * 0.16, y: rect.height * 0.24), control2: CGPoint(x: rect.width * 0.36, y: rect.height * 0.25))
            path.closeSubpath()
        }
    }
}

struct WaterFillShape: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let surfaceY = rect.height * (1 - progress)
        return Path { path in
            path.move(to: CGPoint(x: 0, y: surfaceY))
            path.addCurve(to: CGPoint(x: rect.width, y: surfaceY),
                          control1: CGPoint(x: rect.width * 0.3, y: surfaceY - 9),
                          control2: CGPoint(x: rect.width * 0.7, y: surfaceY + 9))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
    }
}

struct AnimatedGIFView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.animates = true
        if let url = Bundle.main.url(forResource: "water", withExtension: "gif") {
            view.image = NSImage(contentsOf: url)
        }
        return view
    }
    func updateNSView(_ nsView: NSImageView, context: Context) {}
}
