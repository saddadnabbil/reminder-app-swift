import SwiftUI
import UserNotifications

@main
struct MyApp: App {
    // Set delegate for notifications
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    requestNotificationPermission()
                }
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted.")
            } else {
                print("❌ Notification permission denied.")
            }
        }
    }
}

struct ContentView: View {
    @State private var reminders: [Reminder] = []
    @State private var showAddReminderView = false
    @State private var showDeleteConfirmation = false  // State untuk menampilkan modal konfirmasi
    @State private var reminderToDelete: Reminder?  // Reminder yang sedang dipilih untuk dihapus

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(reminders) { reminder in
                        VStack(alignment: .leading) {
                            Text(reminder.title)
                                .font(.headline)
                            Text(reminder.message)
                                .font(.subheadline)
                            Text(formatDate(reminder.date))
                                .font(.footnote)
                                .foregroundColor(.gray)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                // Tampilkan modal konfirmasi ketika swipe delete
                                self.reminderToDelete = reminder
                                self.showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteReminderByIndex)
                }
                .navigationTitle("Reminders")

                HStack {
                    Button(action: {
                        self.showAddReminderView.toggle()
                    }) {
                        Text("Add Reminder")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }

                    Button(action: {
                        self.testNotification()
                    }) {
                        Text("Test Notification")
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
            .sheet(isPresented: $showAddReminderView) {
                AddReminderView { title, message, date in
                    let reminder = Reminder(title: title, message: message, date: date)
                    reminders.append(reminder)
                    self.scheduleNotification(reminder: reminder)
                }
            }
            .confirmationDialog("Are you sure you want to delete this reminder?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let reminder = reminderToDelete {
                        deleteReminder(reminder)
                    }
                }
                Button("Cancel", role: .cancel) {
                    // Canceled, do nothing
                }
            }
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy hh:mm a"
        return formatter.string(from: date)
    }

    func testNotification() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    print("✅ Permission granted for test notification")
                    self.scheduleTestNotification()
                } else {
                    print("❌ Permission denied for test notification")
                }
            }
        }
    }

    func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification shown immediately!"
        content.sound = .default
        
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule test notification: \(error.localizedDescription)")
            } else {
                print("✅ Realtime test notification scheduled successfully!")
            }
        }
    }

    func scheduleNotification(reminder: Reminder) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.message
        content.sound = .default
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
        
        let currentDate = Date()
        
        print("Current date: \(currentDate)")
        print("Reminder date: \(reminder.date)")
        
        if let reminderDate = Calendar.current.date(from: triggerDate), reminderDate < currentDate {
            print("✅ Reminder date is in the past, scheduling notification immediately!")
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            
            let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Failed to schedule notification: \(error.localizedDescription)")
                } else {
                    print("✅ Notification scheduled immediately for reminder: \(reminder.title)")
                }
            }
        } else {
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            
            let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Failed to schedule notification: \(error.localizedDescription)")
                } else {
                    print("✅ Notification scheduled successfully for reminder: \(reminder.title)")
                }
            }
        }
    }

    func deleteReminder(_ reminder: Reminder) {
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders.remove(at: index)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
            print("✅ Deleted reminder and corresponding notification")
        }
    }

    func deleteReminderByIndex(at offsets: IndexSet) {
        for index in offsets {
            let reminder = reminders[index]
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
        }
        reminders.remove(atOffsets: offsets)
    }
}

struct AddReminderView: View {
    @State private var title: String = ""
    @State private var message: String = ""
    @State private var date: Date = Date()
    
    var onSave: (String, String, Date) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Reminder")) {
                    TextField("Title", text: $title)
                    TextField("Message", text: $message)
                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                Button("Save") {
                    if !title.isEmpty && !message.isEmpty {
                        onSave(title, message, date)
                        dismiss()
                    }
                }
                .disabled(title.isEmpty || message.isEmpty)
            }
            .navigationTitle("Add Reminder")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
}

struct Reminder: Identifiable {
    var id = UUID()
    var title: String
    var message: String
    var date: Date
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// Delegate for handling notifications while in foreground or background
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when the app is in the foreground
        completionHandler([.banner, .sound, .badge]) // Use `.banner` instead of `.alert`
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle the response when user taps on the notification
        print("Notification tapped: \(response.notification.request.content.title)")
        completionHandler()
    }
}
