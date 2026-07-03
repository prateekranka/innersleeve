import SwiftUI

struct AttachmentInspectionOverlay: View {
    var attachment: PackageAttachment
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 18) {
                AttachmentObjectView(kind: attachment.kind, seed: attachment.placementSeed)
                    .scaleEffect(1.7)
                    .frame(height: 260)
                    .shadow(color: .black.opacity(0.6), radius: 28, y: 16)

                VStack(spacing: 6) {
                    Text(attachment.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.offWhite)
                        .multilineTextAlignment(.center)
                    Text("\(attachment.kind.displayName) · \(attachment.condition.displayName)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.amberDisplay)
                    if !attachment.notes.isEmpty {
                        Text(attachment.notes)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.offWhite.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.glass)
            }
            .padding(.horizontal, 30)
        }
    }
}
