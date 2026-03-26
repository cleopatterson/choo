import SwiftUI

struct ExerciseOnboardingView: View {
    var onComplete: (ExercisePersona) -> Void

    @State private var selected: ExercisePersona?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("How would you describe\nyour exercise routine?")
                .font(.system(.title2, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text("This helps the AI plan your week")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))

            VStack(spacing: 12) {
                ForEach(ExercisePersona.allCases) { persona in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selected = persona
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Text(persona.emoji)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(persona.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(persona.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .lineLimit(2)
                            }

                            Spacer()

                            if selected == persona {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.chooTeal)
                                    .font(.title3)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(selected == persona ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selected == persona ? Color.chooTeal.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            Spacer()

            Button {
                guard let selected else { return }
                ExercisePersona.save(selected)
                onComplete(selected)
            } label: {
                Text("Let's go")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(selected != nil ? Color.chooPurple : Color.white.opacity(0.1))
                    )
                    .foregroundStyle(selected != nil ? .white : .white.opacity(0.3))
            }
            .disabled(selected == nil)
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .chooBackground()
    }
}
