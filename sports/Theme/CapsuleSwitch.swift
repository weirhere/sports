import SwiftUI

/// The grouped-capsule segmented control: the box score's team switch,
/// generalised once a third screen wanted one (the Career tab's Seasons /
/// Teams, 2026-10-03). It sits under a tab row on every screen that uses
/// it, and a second tab row there would read as one confused control.
struct CapsuleSwitch<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let active = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .font(.chipEmphasis)
                        .lineLimit(1)
                        .foregroundStyle(active ? Color.bgPrimary : Color.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(active ? Color.textPrimary : Color.clear))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.bgElevated))
    }
}
