import AppIntents
import FirebaseFirestore

struct AddBillIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Bill"
    static var description: IntentDescription = "Add a bill to your Choo calendar"

    @Parameter(title: "Bill Title")
    var billTitle: String

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Due Date")
    var dueDate: Date

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard SharedUserContext.isLoggedIn,
              let familyId = SharedUserContext.familyId,
              let displayName = SharedUserContext.displayName else {
            return .result(dialog: "Please open Choo and sign in first.")
        }

        let db = Firestore.firestore()
        let dueStart = Calendar.current.startOfDay(for: dueDate)
        let data: [String: Any] = [
            "familyId": familyId,
            "title": billTitle,
            "startDate": Timestamp(date: dueStart),
            "endDate": Timestamp(date: dueStart),
            "createdBy": displayName,
            "isBill": true,
            "amount": amount,
            "reminderEnabled": true,
            "attendeeUIDs": [String]()
        ]

        try await db.collection("families").document(familyId)
            .collection("events")
            .addDocument(data: data)

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: dueDate)

        return .result(dialog: "Added $\(String(format: "%.2f", amount)) \(billTitle) bill due \(dateStr).")
    }
}
