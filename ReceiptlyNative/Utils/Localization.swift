import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case russian = "ru"

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .english:
            return "en"
        case .russian:
            return "ru_RU"
        }
    }

    var locale: Locale {
        Locale(identifier: localeIdentifier)
    }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .russian:
            return "Русский"
        }
    }

    static var current: AppLanguage {
        let rawValue = UserDefaults.standard.string(forKey: AppPreferences.appLanguageKey) ?? AppLanguage.english.rawValue
        return AppLanguage(rawValue: rawValue) ?? .english
    }
}

func loc(_ english: String, _ russian: String) -> String {
    switch AppLanguage.current {
    case .english:
        return english
    case .russian:
        return russian
    }
}

func appLocale() -> Locale {
    AppLanguage.current.locale
}

private func englishCount(_ count: Int, singular: String, plural: String) -> String {
    "\(count) \(count == 1 ? singular : plural)"
}

private func russianPluralWord(_ count: Int, one: String, few: String, many: String) -> String {
    let value = abs(count) % 100
    let lastDigit = value % 10

    if (11...14).contains(value) {
        return many
    }
    if lastDigit == 1 {
        return one
    }
    if (2...4).contains(lastDigit) {
        return few
    }
    return many
}

func localizedReceiptCountText(_ count: Int) -> String {
    switch AppLanguage.current {
    case .english:
        return englishCount(count, singular: "receipt", plural: "receipts")
    case .russian:
        return "\(count) \(russianPluralWord(count, one: "чек", few: "чека", many: "чеков"))"
    }
}

func localizedItemCountText(_ count: Int) -> String {
    switch AppLanguage.current {
    case .english:
        return englishCount(count, singular: "item", plural: "items")
    case .russian:
        return "\(count) \(russianPluralWord(count, one: "позиция", few: "позиции", many: "позиций"))"
    }
}

func localizedQuantityText(_ count: Int) -> String {
    loc("Quantity \(count)", "Количество \(count)")
}

func localizedActiveCategoryCountText(_ count: Int) -> String {
    switch AppLanguage.current {
    case .english:
        return "\(count) active \(count == 1 ? "category" : "categories")"
    case .russian:
        return "\(count) \(russianPluralWord(count, one: "активная категория", few: "активные категории", many: "активных категорий"))"
    }
}

func localizedPercentOfTotalText(_ percent: Int) -> String {
    loc("\(percent)% of total", "\(percent)% от общего")
}

func localizedPhotosReadyText(_ count: Int) -> String {
    switch AppLanguage.current {
    case .english:
        return englishCount(count, singular: "photo ready", plural: "photos ready")
    case .russian:
        return "Готово \(count) фото"
    }
}

func localizedNoMerchantText() -> String {
    loc("(no merchant)", "(без названия)")
}

func localizedUnnamedItemText() -> String {
    loc("(unnamed item)", "(без названия)")
}

private let categoryTranslationsRu: [String: String] = [
    "Groceries": "Продукты",
    "Dining": "Ресторан",
    "Fast Food": "Фастфуд",
    "Coffee": "Кофе",
    "Alcohol": "Алкоголь",
    "Rent": "Аренда",
    "Housing": "Жилье",
    "Mortgage": "Ипотека",
    "Utilities": "Коммунальные услуги",
    "Internet": "Интернет",
    "Phone": "Телефон",
    "Transport": "Транспорт",
    "Gas": "Топливо",
    "Parking": "Парковка",
    "Taxi / Uber": "Такси / Uber",
    "Flights": "Авиабилеты",
    "Hotel": "Отель",
    "Travel": "Путешествия",
    "Healthcare": "Здоровье",
    "Pharmacy": "Аптека",
    "Dentist": "Стоматология",
    "Gym": "Спортзал",
    "Sports": "Спорт",
    "Outdoor": "Активный отдых",
    "Electronics": "Электроника",
    "Clothing": "Одежда",
    "Shoes": "Обувь",
    "Accessories": "Аксессуары",
    "Beauty": "Красота",
    "Skincare": "Уход за кожей",
    "Haircare": "Уход за волосами",
    "Shopping": "Покупки",
    "Home & Garden": "Дом и сад",
    "Furniture": "Мебель",
    "Cleaning": "Уборка",
    "Pets": "Питомцы",
    "Kids": "Дети",
    "Baby": "Малыш",
    "Education": "Образование",
    "Books": "Книги",
    "Streaming": "Стриминг",
    "Gaming": "Игры",
    "Entertainment": "Развлечения",
    "Subscriptions": "Подписки",
    "Office": "Офис",
    "Gifts": "Подарки",
    "Charity": "Благотворительность",
    "Insurance": "Страхование",
    "Taxes": "Налоги",
    "Other": "Другое",
]

func localizedCategoryName(_ name: String) -> String {
    switch AppLanguage.current {
    case .english:
        return name
    case .russian:
        return categoryTranslationsRu[name] ?? name
    }
}

func localizedCategoryList(_ names: [String]) -> String {
    names.map(localizedCategoryName).joined(separator: ", ")
}
