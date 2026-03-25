import Foundation

public struct CategoryRule: Codable, Equatable {
    public var apps: [String]
    public var related: [String]?
    public var urlPatterns: [String]?

    public init(apps: [String], related: [String]? = nil, urlPatterns: [String]? = nil) {
        self.apps = apps
        self.related = related
        self.urlPatterns = urlPatterns
    }
}

public struct CategoryConfig: Codable, Equatable {
    public var categories: [String: CategoryRule]
    public var defaultCategory: String
    public var categoryOrder: [String]?

    public enum CodingKeys: String, CodingKey {
        case categories
        case defaultCategory = "default_category"
        case categoryOrder = "category_order"
    }

    public init(categories: [String: CategoryRule], defaultCategory: String, categoryOrder: [String]? = nil) {
        self.categories = categories
        self.defaultCategory = defaultCategory
        self.categoryOrder = categoryOrder
    }

    /// Category names in the user's preferred order, falling back to alphabetical.
    public var orderedCategoryNames: [String] {
        let allKeys = Set(categories.keys)
        if let order = categoryOrder {
            let ordered = order.filter { allKeys.contains($0) }
            let missing = allKeys.subtracting(ordered).sorted()
            return ordered + missing
        }
        return allKeys.sorted()
    }

    public func category(forBundleId bundleId: String) -> String? {
        for (name, rule) in categories {
            if rule.apps.contains(bundleId) {
                return name
            }
        }
        return nil
    }

    public func isRelated(bundleId: String, toCategory category: String) -> Bool {
        guard let rule = categories[category] else { return false }
        return rule.related?.contains(bundleId) ?? false
    }

    public func resolve(bundleId: String, currentCategory: String?, pageURL: String? = nil) -> String {
        // 1. Check primary app match
        if let primary = category(forBundleId: bundleId) {
            return primary
        }

        // 2. Check URL patterns
        if let url = pageURL {
            for (name, rule) in categories {
                if let patterns = rule.urlPatterns {
                    for pattern in patterns {
                        if url.localizedCaseInsensitiveContains(pattern) {
                            return name
                        }
                    }
                }
            }
        }

        // 3. Check related apps
        if let current = currentCategory, isRelated(bundleId: bundleId, toCategory: current) {
            return current
        }

        // 4. Fall back to default
        return defaultCategory
    }
}
