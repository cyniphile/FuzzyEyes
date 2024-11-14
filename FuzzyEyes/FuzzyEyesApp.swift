import SwiftUI
import UserNotifications
import AVFoundation

@main
struct TimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var isFullScreen = false

    var body: some Scene {
        WindowGroup {
            ContentView(isFullScreen: $isFullScreen)
        }
        .windowStyle(.hiddenTitleBar)
        
        MenuBarExtra("FuzzyEyes", systemImage: "timer") {
            Button("Open FuzzyEyes") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
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
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("AppDelegate: Will present notification")
        completionHandler([.banner, .sound, .list])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        print("AppDelegate: Did receive notification response")
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: NSNotification.Name("NotificationTapped"), object: nil)
        completionHandler()
    }
}


struct ContentView: View {
    @Binding var isFullScreen: Bool
    @State private var timeRemaining = 20
    @State private var timer: Timer?
    @Environment(\.scenePhase) private var scenePhase
    @State private var windowObserver: Any?
    
    
    
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
                        sendImmedateNotification()
                    }
                    .padding()
                    Button("Check Permissions") {
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.checkNotificationPermissions()
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
            setupNotificationCategory()  // Add this line
            startBackgroundTimer()
        }
    }
    func setupNotificationObserver() {
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NotificationTapped"),
            object: nil,
            queue: .main) { _ in
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
    
    func sendImmedateNotification() {
        print("ContentView: Sending immediate notification")
        let content = UNMutableNotificationContent()
        content.title = "Time for a break!"
        content.body = "Click to start your 20-second timer"
        content.sound = .default
        content.interruptionLevel = .critical
        content.relevanceScore = 1.0
        content.categoryIdentifier = "TIMER_ALERT"
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("ContentView: Error sending notification: \(error)")
            } else {
                print("ContentView: Test notification scheduled successfully")
            }
        }
    }
    
    func startBackgroundTimer() {
        print("ContentView: Starting background timer")
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1200, repeats: true) { _ in
            print("ContentView: Timer fired")
            sendImmedateNotification()
        }
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
            .foregroundColor(.white)
            .padding()
        }
        .onAppear {
            startTimer()
            setupSound()
        }
    }
    
    func setupSound() {
         // Choose a system sound
         if let soundURL = Bundle.main.url(forResource: "sound", withExtension: "mp3") {
             do {
                 audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                 audioPlayer?.prepareToPlay()
             } catch {
                 print("Error loading sound: \(error)")
             }
         }
     }
    
    func playSound() {
        // Option 1: Play system beep
        NSSound.beep()
        // Option 2: Play custom sound if setup
        audioPlayer?.play()
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
                    window.setFrame(CGRect(x: 0, y: 0, width: 200, height: 150), display: true, animate: true)
                    window.center()
                }
            }
        }
    }
}
