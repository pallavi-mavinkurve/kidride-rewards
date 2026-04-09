import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.headline)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(AppTheme.navy.opacity(0.8))

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.navy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(accent.opacity(0.28), lineWidth: 1.2)
                )
        )
        .shadow(color: AppTheme.navy.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}
