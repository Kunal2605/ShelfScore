import SwiftUI
import SwiftData

struct GroceryListRow: View {
    @Environment(\.modelContext) private var modelContext
    let item: GroceryItem

    private var grade: HealthScore.Grade { HealthScore.Grade.from(score: item.healthScore) }

    var body: some View {
        HStack(spacing: 12) {
            // Toggle button
            Button {
                item.isBought.toggle()
                try? modelContext.save()
            } label: {
                Image(systemName: item.isBought ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(item.isBought ? .green : Color(.systemGray3))
                    .animation(.spring(response: 0.3), value: item.isBought)
            }
            .buttonStyle(.plain)

            // Product image
            AsyncImage(url: item.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                case .failure, .empty:
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "takeoutbag.and.cup.and.straw")
                                .font(.system(size: 18))
                                .foregroundStyle(.quaternary)
                        )
                @unknown default:
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                        .frame(width: 48, height: 48)
                }
            }

            // Name & brand
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(item.isBought ? .secondary : .primary)
                    .strikethrough(item.isBought, color: .secondary)
                    .lineLimit(1)

                if !item.brand.isEmpty {
                    Text(item.brand)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Grade badge — only for real products, not custom items
            if !item.isCustom {
                Text(grade.rawValue)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(item.isBought ? .secondary : grade.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill((item.isBought ? Color.secondary : grade.color).opacity(0.1))
                    )
            }
        }
        .padding(.vertical, 4)
        .animation(.easeInOut(duration: 0.2), value: item.isBought)
    }
}
