import SwiftUI

struct RecipeIngredientRow: View {
    let ingredient: RecipeIngredient
    let isAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Ingredient image
            AsyncImage(url: ingredient.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                case .failure, .empty:
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "carrot")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(.systemGray3))
                        )
                @unknown default:
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                        .frame(width: 44, height: 44)
                }
            }

            // Ingredient text
            Text(ingredient.original)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            // Add button
            Button {
                guard !isAdded else { return }
                onAdd()
            } label: {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(isAdded ? Color.green : Color.green.opacity(0.75))
            }
            .buttonStyle(.plain)
            .disabled(isAdded)
            .animation(.spring(response: 0.3), value: isAdded)
        }
        .padding(.vertical, 6)
    }
}
