import AppIntents

struct ChooShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddShoppingItemIntent(),
            phrases: [
                "Add item in \(.applicationName)",
                "Add to \(.applicationName) list",
                "\(.applicationName) shopping"
            ],
            shortTitle: "Add Shopping Item",
            systemImageName: "cart.badge.plus"
        )
        AppShortcut(
            intent: AddEventIntent(),
            phrases: [
                "Add event in \(.applicationName)",
                "New event in \(.applicationName)",
                "\(.applicationName) new event"
            ],
            shortTitle: "Add Event",
            systemImageName: "calendar.badge.plus"
        )
        AppShortcut(
            intent: AddBillIntent(),
            phrases: [
                "Add bill in \(.applicationName)",
                "New bill in \(.applicationName)",
                "\(.applicationName) new bill"
            ],
            shortTitle: "Add Bill",
            systemImageName: "dollarsign.circle"
        )
    }
}
