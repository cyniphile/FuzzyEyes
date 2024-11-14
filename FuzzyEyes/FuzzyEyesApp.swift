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
        
        backgroundTimer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
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
    override init() {
        super.init()
        print("AppDelegate: Initializing")
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("AppDelegate: App did finish launching")
        requestNotificationPermissions()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("AppDelegate: App will terminate")
        TimerManager.shared.stopBackgroundTimer()
    }

    func requestNotificationPermissions() {
        print("AppDelegate: Requesting notification permissions")
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("AppDelegate: Notification permission granted")
                DispatchQueue.main.async {
                    NSApp.registerForRemoteNotifications()
                }
            } else {
                print("AppDelegate: Notification permission denied: \(String(describing: error))")
            }
        }
    }

    func checkNotificationPermissions() {
        print("AppDelegate: Checking notification permissions")
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("AppDelegate: Current notification settings:")
            print("  Authorization status: \(settings.authorizationStatus.rawValue)")
            print("  Alert setting: \(settings.alertSetting.rawValue)")
            print("  Sound setting: \(settings.soundSetting.rawValue)")
            print("  Badge setting: \(settings.badgeSetting.rawValue)")
            print("  Notification center setting: \(settings.notificationCenterSetting.rawValue)")

            if settings.authorizationStatus != .authorized {
                DispatchQueue.main.async {
                    self.requestNotificationPermissions()
                }
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("AppDelegate: Will present notification")
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("AppDelegate: Did receive notification response")
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: NSNotification.Name("NotificationTapped"), object: nil)
        completionHandler()
    }
}

@main
struct TimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var timerManager = TimerManager.shared
    @State private var isFullScreen = false

    var body: some Scene {
        WindowGroup {
            ContentView(isFullScreen: $isFullScreen)
                .environmentObject(timerManager)
        }
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra("FuzzyEyes", systemImage: "eye") {
            Button("Open FuzzyEyes") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first {
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
    @Binding var isFullScreen: Bool
    @State private var timeRemaining = 20
    @Environment(\.scenePhase) private var scenePhase
    @State private var windowObserver: Any?
    @EnvironmentObject private var timerManager: TimerManager

    var body: some View {
        Group {
            if isFullScreen {
                TimerView(timeRemaining: $timeRemaining, isFullScreen: $isFullScreen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else {
                VStack {
                    Text("FuzzyEyes running in background")
                        .padding()
                    Button("Send Test Notification") {
                        print("ContentView: Test notification button pressed")
                        timerManager.sendManualNotification()
                    }
                    .padding()
                    Button("Check Permissions") {
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.checkNotificationPermissions()
                        }
                    }
                    .padding()
                    // Debug button
                    Button(timerManager.isTimerRunning ? "Stop Timer" : "Start Timer") {
                        if timerManager.isTimerRunning {
                            timerManager.stopBackgroundTimer()
                        } else {
                            timerManager.startBackgroundTimer()
                        }
                    }
                    .padding()
                }
                .frame(width: 200, height: 150)
            }
        }
        .onAppear {
            print("ContentView: View appeared")
            setupNotificationObserver()
            setupNotificationCategory()
            timerManager.startBackgroundTimer()
        }
        .onDisappear {
            print("ContentView: View disappeared")
        }
    }

    func setupNotificationObserver() {
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NotificationTapped"),
            object: nil,
            queue: .main
        ) { _ in
            print("ContentView: Notification tapped, showing full screen")
            isFullScreen = true
            if let window = NSApp.windows.first {
                window.setFrame(NSScreen.main?.frame ?? .zero, display: true)
            }
        }
    }

    func setupNotificationCategory() {
        let category = UNNotificationCategory(
            identifier: "TIMER_ALERT",
            actions: [
                UNNotificationAction(
                    identifier: "START_TIMER",
                    title: "Start Timer",
                    options: .foreground)
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}

struct TimerView: View {
    @Binding var timeRemaining: Int
    @Binding var isFullScreen: Bool
    @State private var timer: Timer?
    @State private var audioPlayer: AVAudioPlayer?

    var body: some View {
        VStack {
            Text("\(timeRemaining)")
                .font(.system(size: 120, weight: .bold))
                .foregroundColor(.white)
                .padding()
        }
        .onAppear {
            startTimer()
        }
    }

    func playSound() {
        NSSound(named: "Submarine")?.play()
    }

    func startTimer() {
        timeRemaining = 20
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer.invalidate()
                playSound()
                isFullScreen = false
                if let window = NSApp.windows.first {
                    window.setFrame(
                        CGRect(x: 0, y: 0, width: 200, height: 150), display: true, animate: true)
                    window.center()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let window = NSApp.windows.first {
                        window.close()
                    }
                }
            }
        }
    }
}
