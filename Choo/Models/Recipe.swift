import Foundation
import FirebaseFirestore

struct Ingredient: Codable, Hashable {
    var name: String        // "chicken breast"
    var quantity: String?   // "500g", "2 cups", "1 bunch"
}

// MARK: - Recipe Metadata Enums

enum CuisineType: String, CaseIterable, Identifiable, Codable {
    case italian, asian, mexican, greek, bbq, comfort, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .italian: "Italian"
        case .asian: "Asian"
        case .mexican: "Mexican"
        case .greek: "Greek"
        case .bbq: "BBQ"
        case .comfort: "Comfort"
        case .other: "Other"
        }
    }
}

enum CarbType: String, CaseIterable, Identifiable, Codable {
    case rice, pasta, noodles, bread, wraps, none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rice: "Rice"
        case .pasta: "Pasta"
        case .noodles: "Noodles"
        case .bread: "Bread"
        case .wraps: "Wraps"
        case .none: "None"
        }
    }
}

enum PrepEffort: String, CaseIterable, Identifiable, Codable {
    case easy       // ≤30 min
    case medium     // 30–60 min
    case big        // 60+ min or AM prep

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .big: "Big cook"
        }
    }
}

enum CalorieDensity: String, CaseIterable, Identifiable, Codable {
    case light, moderate, rich

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: "Light"
        case .moderate: "Moderate"
        case .rich: "Rich"
        }
    }
}

struct Recipe: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String        // "Spaghetti Bolognese"
    var icon: String        // emoji e.g. "🍝"
    var ingredients: [Ingredient]
    var isDefault: Bool     // true for the built-in recipes
    var servings: Int?      // default 4

    // Metadata fields (optional for backward compatibility)
    var prepTimeMinutes: Int?
    var cuisine: String?
    var carbType: String?
    var prepEffort: String?
    var calorieDensity: String?

    // MARK: - Computed Enum Accessors

    var cuisineType: CuisineType? {
        guard let raw = cuisine else { return nil }
        return CuisineType(rawValue: raw)
    }

    var carbTypeEnum: CarbType? {
        guard let raw = carbType else { return nil }
        return CarbType(rawValue: raw)
    }

    var prepEffortEnum: PrepEffort? {
        guard let raw = prepEffort else { return nil }
        return PrepEffort(rawValue: raw)
    }

    var calorieDensityEnum: CalorieDensity? {
        guard let raw = calorieDensity else { return nil }
        return CalorieDensity(rawValue: raw)
    }

    var prepTimeDisplay: String? {
        guard let mins = prepTimeMinutes, mins > 0 else { return nil }
        if mins >= 60 {
            let hours = mins / 60
            let remainder = mins % 60
            return remainder > 0 ? "\(hours)hr \(remainder)min" : "\(hours) hrs"
        }
        return "\(mins) min"
    }

    // MARK: - Default Recipes

    static let defaults: [Recipe] = [
        Recipe(name: "Chicken Pasta", icon: "🍝", ingredients: [
            .init(name: "Chicken"), .init(name: "Pasta"), .init(name: "Veggies"),
            .init(name: "Pasta Sauce"), .init(name: "Passata"), .init(name: "Canned Tomatoes"),
        ], isDefault: true, servings: 4, prepTimeMinutes: 30,
              cuisine: "italian", carbType: "pasta", prepEffort: "easy", calorieDensity: "moderate"),

        Recipe(name: "Fish Tacos", icon: "🌮", ingredients: [
            .init(name: "Frozen Fish"), .init(name: "Burritos"), .init(name: "Avocado"),
            .init(name: "Spanish Onion"), .init(name: "Coriander"),
        ], isDefault: true, servings: 4, prepTimeMinutes: 25,
              cuisine: "mexican", carbType: "wraps", prepEffort: "easy", calorieDensity: "light"),

        Recipe(name: "Curry", icon: "🍛", ingredients: [
            .init(name: "Butter Chicken"), .init(name: "Coconut Milk"), .init(name: "Jasmine Rice"),
            .init(name: "Stock"), .init(name: "Tomato Paste"), .init(name: "Veggies"),
        ], isDefault: true, servings: 4, prepTimeMinutes: 35,
              cuisine: "asian", carbType: "rice", prepEffort: "medium", calorieDensity: "moderate"),

        Recipe(name: "Fish", icon: "🐟", ingredients: [
            .init(name: "Salmon"), .init(name: "Salad"), .init(name: "Jasmine Rice"),
            .init(name: "Broccolini"),
        ], isDefault: true, servings: 4, prepTimeMinutes: 25,
              cuisine: "other", carbType: "rice", prepEffort: "easy", calorieDensity: "light"),

        Recipe(name: "Suey and Papa", icon: "🍲", ingredients: [],
               isDefault: true, servings: 4, prepTimeMinutes: 20,
               cuisine: "comfort", carbType: "none", prepEffort: "easy", calorieDensity: "light"),

        Recipe(name: "Schnitty", icon: "🍗", ingredients: [
            .init(name: "Chicken Schnitzel"), .init(name: "Salad"), .init(name: "Veggies"),
        ], isDefault: true, servings: 4, prepTimeMinutes: 25,
              cuisine: "comfort", carbType: "none", prepEffort: "easy", calorieDensity: "moderate"),

        Recipe(name: "Risotto", icon: "🍚", ingredients: [
            .init(name: "Arborio Rice"), .init(name: "Stock"), .init(name: "Meat"),
            .init(name: "Veggies"),
        ], isDefault: true, servings: 4, prepTimeMinutes: 40,
              cuisine: "italian", carbType: "rice", prepEffort: "medium", calorieDensity: "rich"),

        Recipe(name: "Tacos", icon: "🫔", ingredients: [
            .init(name: "Burritos"), .init(name: "Veggies"), .init(name: "Beef Mince"),
            .init(name: "Taco Spice"), .init(name: "Coriander"), .init(name: "Refried Beans"),
        ], isDefault: true, servings: 4, prepTimeMinutes: 25,
              cuisine: "mexican", carbType: "wraps", prepEffort: "easy", calorieDensity: "moderate"),

        Recipe(name: "Bolognese", icon: "🫕", ingredients: [
            .init(name: "Beef Mince"), .init(name: "Veggies"), .init(name: "Pasta Sauce"),
            .init(name: "Passata"), .init(name: "Pasta"),
        ], isDefault: true, servings: 4, prepTimeMinutes: 45,
              cuisine: "italian", carbType: "pasta", prepEffort: "medium", calorieDensity: "moderate"),

        Recipe(name: "Stir Fry", icon: "🥘", ingredients: [
            .init(name: "Noodles"), .init(name: "Prawns"), .init(name: "Veggies"),
            .init(name: "Soy Sauce"), .init(name: "White Wine Vinegar"),
        ], isDefault: true, servings: 4, prepTimeMinutes: 25,
              cuisine: "asian", carbType: "noodles", prepEffort: "easy", calorieDensity: "light"),

        Recipe(name: "Quiche", icon: "🥧", ingredients: [
            .init(name: "Quiche"), .init(name: "Salad"),
        ], isDefault: true, servings: 4, prepTimeMinutes: 15,
              cuisine: "comfort", carbType: "none", prepEffort: "easy", calorieDensity: "moderate"),

        Recipe(name: "Roast", icon: "🍖", ingredients: [
            .init(name: "Roast Meat"), .init(name: "Veggies"),
        ], isDefault: true, servings: 6, prepTimeMinutes: 120,
              cuisine: "comfort", carbType: "none", prepEffort: "big", calorieDensity: "rich"),

        Recipe(name: "BBQ", icon: "🥩", ingredients: [
            .init(name: "Steak"), .init(name: "Potatoes"),
        ], isDefault: true, servings: 4, prepTimeMinutes: 40,
              cuisine: "bbq", carbType: "none", prepEffort: "medium", calorieDensity: "rich"),

        Recipe(name: "Pizza", icon: "🍕", ingredients: [
            .init(name: "Frozen Pizza"), .init(name: "Salad"),
        ], isDefault: true, servings: 4, prepTimeMinutes: 15,
              cuisine: "italian", carbType: "none", prepEffort: "easy", calorieDensity: "rich"),

        Recipe(name: "Bitsa", icon: "🍽️", ingredients: [],
               isDefault: true, servings: 4, prepTimeMinutes: 15,
               cuisine: "other", carbType: "none", prepEffort: "easy", calorieDensity: "light"),

        Recipe(name: "Tomato Soup", icon: "🍅", ingredients: [
            .init(name: "Passata"), .init(name: "Stock"), .init(name: "Pasta"),
            .init(name: "Veggies"), .init(name: "Meat"),
        ], isDefault: true, servings: 4, prepTimeMinutes: 30,
              cuisine: "italian", carbType: "bread", prepEffort: "easy", calorieDensity: "light"),

        Recipe(name: "Eat Out", icon: "🍟", ingredients: [],
               isDefault: true, servings: 4, prepTimeMinutes: 0,
               cuisine: "other", carbType: "none", prepEffort: "easy", calorieDensity: "moderate"),

        Recipe(name: "Lasagne", icon: "🧀", ingredients: [
            .init(name: "Beef Mince"), .init(name: "Veggies"), .init(name: "Lasagne Pasta"),
            .init(name: "Ricotta"), .init(name: "Passata"), .init(name: "Pasta Sauce"),
            .init(name: "Tomato Paste"),
        ], isDefault: true, servings: 6, prepTimeMinutes: 90,
              cuisine: "italian", carbType: "pasta", prepEffort: "big", calorieDensity: "rich"),

        Recipe(name: "Burgers", icon: "🍔", ingredients: [
            .init(name: "Beef Patties"), .init(name: "Burger Buns"), .init(name: "Salad"),
            .init(name: "Potatoes"),
        ], isDefault: true, servings: 4, prepTimeMinutes: 40,
              cuisine: "bbq", carbType: "bread", prepEffort: "medium", calorieDensity: "rich"),
    ]
}
