import SwiftUI

struct RunDoneSheet: View {
    let checkedCount: Int
    let uncheckedCount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("✅")
                .font(.system(size: 42))

            Text("Done shopping?")
                .font(.title3.weight(.heavy))

            Text("This will remove **\(checkedCount) ticked item\(checkedCount == 1 ? "" : "s")** and reset their cadence clocks.\n**\(uncheckedCount) unticked item\(uncheckedCount == 1 ? "" : "s")** will stay in your run.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Button {
                onConfirm()
            } label: {
                Text("Remove ticked items")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.chooAmber)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button {
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(20)
        .padding(.bottom, 20)
    }
}
