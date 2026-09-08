// mobile/ios/Watch App/Models/ComboModels.swift
import Foundation

struct ComboTrick: Codable, Identifiable {
    let type: String // "trick" | "combo"
    let trickId: String?
    let name: String?
    let abbreviation: String?
    let position: Int
    let strongFoot: Bool
    let noTouch: Bool
    let isTransition: Bool
    let subComboId: String?
    let subComboName: String?

    var id: Int { position }
}

struct Combo: Codable, Identifiable {
    let id: String
    let ownerId: String
    let ownerUserName: String?
    let name: String?
    let totalDifficulty: Double
    let trickCount: Int
    let visibility: String?
    let displayText: String
    let tricks: [ComboTrick]?
    let isFavourited: Bool
    let isCompleted: Bool

    /// Matches `comboDisplayName()` (web) / `ComboItem.displayName` (phone) —
    /// combo names are optional, fall back to the abbreviation sequence.
    var displayName: String {
        (name?.isEmpty == false) ? name! : displayText
    }
}

struct PagedResult<T: Codable>: Codable {
    let items: [T]
    let totalCount: Int
    let page: Int
    let pageSize: Int
}
