import SwiftUI

/// A purely presentational row used in both the Search tab and the Grocery add sheet.
/// The caller decides what happens on tap — this view has no action of its own.
struct SearchResultRow: View {
    let product: Product

    private var grade: HealthScore.Grade { product.healthScore.grade }

    var body: some View {
        HStack(spacing: 12) {
            // Product thumbnail
            AsyncImage(url: product.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                case .failure, .empty:
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 18))
                                .foregroundStyle(.tertiary)
                        )
                @unknown default:
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                        .frame(width: 52, height: 52)
                }
            }

            // Name & brand
            VStack(alignment: .leading, spacing: 3) {
                Text(product.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if !product.brand.isEmpty {
                    Text(product.brand)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Score badge
            VStack(spacing: 1) {
                Text(grade.rawValue)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(grade.color)
                Text("\(product.healthScore.score)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(grade.color.opacity(0.75))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(grade.color.opacity(0.1))
            )
        }
        .padding(.vertical, 4)
    }
}
