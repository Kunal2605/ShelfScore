import SwiftUI

struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            AsyncImage(url: recipe.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.system(size: 28))
                                .foregroundStyle(Color(.systemGray3))
                        )
                @unknown default:
                    Rectangle().fill(Color(.systemGray5))
                }
            }
            .frame(height: 120)
            .clipped()

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    if recipe.readyInMinutes > 0 {
                        Label("\(recipe.readyInMinutes) min", systemImage: "clock")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    if recipe.calories > 0 {
                        Label("\(Int(recipe.calories)) cal", systemImage: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
    }
}
