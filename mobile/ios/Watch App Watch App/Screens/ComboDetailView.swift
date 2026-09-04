// mobile/ios/Watch App/Screens/ComboDetailView.swift
import SwiftUI

struct ComboDetailView: View {
    let combo: Combo

    var body: some View {
        List {
            ForEach(combo.tricks ?? [], id: \.position) { trick in
                HStack(alignment: .top, spacing: 6) {
                    Text("\(trick.position).")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(rowLabel(for: trick))
                        .font(.system(.footnote, design: .monospaced))
                }
            }
        }
        .navigationTitle(combo.displayName)
    }

    /// Matches the phone's abbreviation-notation convention: sub-combo steps
    /// show their own name in parens, plain tricks show abbreviation plus a
    /// ·wf / ·nt suffix (suppressed for transition tricks, which have
    /// neither a foot nor a no-touch state of their own).
    private func rowLabel(for trick: ComboTrick) -> String {
        if trick.type == "combo" {
            return "(\(trick.subComboName ?? "Combo"))"
        }
        let abbreviation = trick.abbreviation ?? ""
        if trick.isTransition { return abbreviation }
        var suffix = ""
        if trick.noTouch { suffix = "·nt" } else if !trick.strongFoot { suffix = "·wf" }
        return abbreviation + suffix
    }
}
