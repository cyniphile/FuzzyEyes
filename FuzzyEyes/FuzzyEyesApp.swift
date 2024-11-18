import AVFoundation
import SwiftUI
import UserNotifications

class TimerManager: ObservableObject {
    static let shared = TimerManager()
    private var backgroundTimer: Timer?
    @Published var isTimerRunning = false
    
    private init() {
        print("TimerManager: Initialized")
    }
    
    func startBackgroundTimer() {
        // Cancel any existing timer first
        stopBackgroundTimer()
        
        print("TimerManager: Starting background timer, current state: \(isTimerRunning)")
        isTimerRunning = true
        
        backgroundTimer = Timer(timeInterval: 1200, repeats: true) { [weak self] _ in
            print("TimerManager: Timer fired at \(Date())")
            self?.sendNotification()
        }
        
        // Make sure to add the timer to the main run loop
        RunLoop.main.add(backgroundTimer!, forMode: .common)
        
        print("TimerManager: Timer started successfully")
    }
    
    func stopBackgroundTimer() {
        print("TimerManager: Stopping background timer")
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        isTimerRunning = false
    }
    
    func sendManualNotification() {
        print("TimerManager: Sending manual notification")
        sendNotification()
    }
    
    private func sendNotification() {
        print("TimerManager: Preparing notification at \(Date())")
        let content = UNMutableNotificationContent()
        content.title = "Time for a break!"
        content.body = "Click to start your 20-second timer"
        content.sound = .default
        content.interruptionLevel = .critical
        content.relevanceScore = 1.0
        content.categoryIdentifier = "TIMER_ALERT"

        let request = UNNotificationRequest(
            identifier: "timer-notification",
            content: content,
            trigger: nil)
        
        // Remove existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("TimerManager: Error sending notification: \(error)")
            } else {
                print("TimerManager: Notification scheduled successfully at \(Date())")
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var timerWindow: NSWindow?

    override init() {
        super.init()
        print("AppDelegate: Initializing")
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("AppDelegate: App finished launching")
        TimerManager.shared.startBackgroundTimer()
    }
    
    // ... existing methods ...

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("AppDelegate: Did receive notification response with action identifier: \(response.actionIdentifier)")
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // The user opened the app from the notification
            NSApp.activate(ignoringOtherApps: true)
            presentTimerView()
        }
        completionHandler()
    }

    func dismissTimerWindow() {
        if let window = timerWindow {
            window.orderOut(nil) // Removes window from view stack
            window.close()       // Closes the window
            timerWindow = nil
        }
    }


    func presentTimerView() {
        if timerWindow != nil {
            // Timer window is already presented
            return
        }

        let timerView = TimerView {
            DispatchQueue.main.async {
                // Dismiss the window when the timer ends
                self.timerWindow?.orderOut(nil) // Ensure it's removed from the screen
                self.timerWindow?.close()
                self.timerWindow = nil
                self.dismissTimerWindow()
            }
        }

        let window = NSWindow(
            contentRect: NSScreen.main?.frame ?? NSRect.zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)
        window.contentView = NSHostingView(rootView: timerView)
        window.level = .mainMenu + 1
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false // Prevent premature release
        window.makeKeyAndOrderFront(nil)
        window.toggleFullScreen(nil)
        self.timerWindow = window
    }

}


@main
struct TimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var timerManager = TimerManager.shared

    var body: some Scene {
        MenuBarExtra("FuzzyEyes", systemImage: "eye") {
            Button("Open FuzzyEyes") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "ContentViewWindow" }) {
                    window.makeKeyAndOrderFront(nil)
                } else {
                    // Create a new window with ContentView
                    let contentView = ContentView()
                        .environmentObject(timerManager)
                    let window = NSWindow(
                        contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                        styleMask: [.titled, .closable, .resizable],
                        backing: .buffered,
                        defer: false)
                    window.contentView = NSHostingView(rootView: contentView)
                    window.title = "FuzzyEyes"
                    window.identifier = NSUserInterfaceItemIdentifier(rawValue: "ContentViewWindow")
                    window.center()
                    window.makeKeyAndOrderFront(nil)
                }
            }
            Button("Quit") {
                TimerManager.shared.stopBackgroundTimer()
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var timerManager: TimerManager

    var body: some View {
        VStack {
            Text("FuzzyEyes running in background")
                .padding()
            Button("Send Test Notification") {
                print("ContentView: Test notification button pressed")
                timerManager.sendManualNotification()
            }
            .padding()
            Button(timerManager.isTimerRunning ? "Stop Timer" : "Start Timer") {
                if timerManager.isTimerRunning {
                    timerManager.stopBackgroundTimer()
                } else {
                    timerManager.startBackgroundTimer()
                }
            }
            .padding()
        }
        .frame(width: 400, height: 300)
        .onAppear {
            print("ContentView: View appeared")
            timerManager.startBackgroundTimer()
        }
        .onDisappear {
            print("ContentView: View disappeared")
        }
    }
}




// In your TimerView
struct TimerView: View {
    var onTimerEnd: (() -> Void)?
    @State private var timeRemaining = 20
    @State private var timer: Timer?

    var body: some View {
        VStack {
            Text("\(timeRemaining)")
                .font(.system(size: 120, weight: .bold))
                .foregroundColor(.white)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            startTimer()
        }
    }

    func playSound() {
        NSSound(named: "Submarine")?.play()
    }

    func startTimer() {
        timeRemaining = 20 // Set your desired timer duration
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer.invalidate()
                playSound()
                DispatchQueue.main.async {
                    onTimerEnd?() // Properly trigger cleanup
                }
            }
        }
    }

}

