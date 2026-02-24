import SwiftUI
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

struct ProductResultScreen: View {
    let product: Product

    @Environment(\.modelContext) private var modelContext

    @State private var animateScore = false
    @State private var animateCards = false
    @State private var alternatives: [Product] = []
    @State private var isLoadingAlternatives = false
    @State private var selectedAlternative: Product?
    @State private var addedToGroceryList = false
    @State private var productInsight: ProductInsight?
    @State private var isLoadingInsight = false
    private let llamaService = LlamaAdvisorService.shared

    private var gradeColor: Color { product.healthScore.grade.color }

    private var foundationModelsAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Score header
                scoreHeader

                // Content cards
                VStack(spacing: 14) {
                    nutritionCard
                        .slideUp(delay: 0.05, animate: animateCards)

                    if let nova = product.novaGroup {
                        novaCard(group: nova)
                            .slideUp(delay: 0.12, animate: animateCards)
                    }

                    scoreBreakdownCard
                        .slideUp(delay: 0.19, animate: animateCards)

                    aiInsightCard
                        .slideUp(delay: 0.24, animate: animateCards)

                    if !product.additives.isEmpty {
                        additivesCard
                            .slideUp(delay: 0.26, animate: animateCards)
                    }

                    if !product.allergens.isEmpty {
                        allergensCard
                            .slideUp(delay: 0.30, animate: animateCards)
                    }

                    if let ingredients = product.ingredients, !ingredients.isEmpty {
                        ingredientsCard(ingredients)
                            .slideUp(delay: 0.34, animate: animateCards)
                    }

                    if product.healthScore.grade != .a {
                        alternativesCard
                            .slideUp(delay: 0.40, animate: animateCards)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    guard !addedToGroceryList else { return }
                    let item = GroceryItem(from: product)
                    modelContext.insert(item)
                    try? modelContext.save()
                    addedToGroceryList = true
                } label: {
                    Image(systemName: addedToGroceryList ? "cart.fill.badge.plus" : "cart.badge.plus")
                        .foregroundStyle(addedToGroceryList ? .green : .primary)
                        .animation(.spring(response: 0.3), value: addedToGroceryList)
                }
            }
        }
        .onChange(of: llamaService.isModelLoaded) { _, isLoaded in
            // When the llama model finishes loading (post-download),
            // upgrade from rule-based to on-device LLM insight automatically.
            guard isLoaded, productInsight?.source == .ruleBased else { return }
            Task {
                if let upgraded = await LlamaAdvisorService.shared.getInsight(for: product) {
                    await MainActor.run { productInsight = upgraded }
                }
            }
        }
        .sheet(item: $selectedAlternative) { alt in
            NavigationStack {
                ProductResultScreen(product: alt)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { selectedAlternative = nil }
                                .fontWeight(.semibold)
                        }
                    }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.75).delay(0.2)) {
                animateScore = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                animateCards = true
            }
            isLoadingAlternatives = true
            isLoadingInsight = true
            Task {
                let results = await OpenFoodFactsService.shared.searchAlternatives(for: product)
                await MainActor.run {
                    alternatives = results
                    isLoadingAlternatives = false
                }
            }
            Task {
                let insight = await AIAdvisorService.shared.getProductInsight(for: product)
                await MainActor.run {
                    productInsight = insight
                    isLoadingInsight = false
                }
            }
        }
    }

    // MARK: - Score Header
    private var scoreHeader: some View {
        VStack(spacing: 0) {
            // Solid accent stripe — clearly visible grade color
            Rectangle()
                .fill(gradeColor)
                .frame(height: 4)

            VStack(spacing: 16) {
                // Product info
                HStack(spacing: 14) {
                    AsyncImage(url: product.imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 76, height: 76)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color(.systemGray5), lineWidth: 1)
                                )
                        case .failure:
                            productImagePlaceholder()
                        case .empty:
                            ProgressView()
                                .frame(width: 76, height: 76)
                        @unknown default:
                            productImagePlaceholder()
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.displayName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        if !product.brand.isEmpty {
                            Text(product.brand)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        if let quantity = product.quantity, !quantity.isEmpty {
                            Text(quantity)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)

                // Score gauge with reactive accent ring
                ZStack {
                    // Subtle colored glow
                    Circle()
                        .fill(gradeColor.opacity(animateScore ? 0.08 : 0))
                        .frame(width: 200, height: 200)
                        .blur(radius: 20)

                    ScoreGaugeView(
                        score: product.healthScore.score,
                        grade: product.healthScore.grade,
                        animate: animateScore
                    )
                    .frame(width: 180, height: 180)
                }
                .padding(.vertical, 4)

                // Grade pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(gradeColor)
                        .frame(width: 8, height: 8)

                    Text(product.healthScore.grade.label)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(gradeColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(gradeColor.opacity(0.1))
                )
                .padding(.bottom, 12)
            }

            Divider()
        }
        .background(Color.white)
    }

    // MARK: - Nutrition Card
    private var nutritionCard: some View {
        SectionCard(title: "Nutrition Facts", icon: "chart.bar.fill", accentColor: .blue) {
            VStack(spacing: 0) {
                Text("Per 100g")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.bottom, 8)

                ForEach(Array(product.nutrition.displayRows.enumerated()), id: \.offset) { index, row in
                    NutrientRowView(
                        name: row.name,
                        value: row.value,
                        level: row.level
                    )

                    if index < product.nutrition.displayRows.count - 1 {
                        Divider()
                            .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - NOVA Card
    private func novaCard(group: Int) -> some View {
        SectionCard(title: "Processing Level", icon: "gearshape.2.fill", accentColor: novaColor(group)) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(novaColor(group).opacity(0.12))
                        .frame(width: 52, height: 52)

                    Text("\(group)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(novaColor(group))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(novaLabel(group))
                        .font(.system(size: 14, weight: .semibold))

                    Text(novaDescription(group))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Score Breakdown Card
    private var scoreBreakdownCard: some View {
        SectionCard(title: "Score Breakdown", icon: "list.bullet.clipboard.fill", accentColor: gradeColor) {
            VStack(spacing: 8) {
                if !product.healthScore.positives.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.green)
                            .font(.system(size: 13))
                        Text("POSITIVES")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.green)
                            .tracking(0.5)
                        Spacer()
                    }

                    ForEach(product.healthScore.positives) { factor in
                        factorRow(factor, isPositive: true)
                    }
                }

                if !product.healthScore.negatives.isEmpty {
                    if !product.healthScore.positives.isEmpty {
                        Divider().padding(.vertical, 4)
                    }

                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 13))
                        Text("NEGATIVES")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.red)
                            .tracking(0.5)
                        Spacer()
                    }

                    ForEach(product.healthScore.negatives) { factor in
                        factorRow(factor, isPositive: false)
                    }
                }
            }
        }
    }

    private func factorRow(_ factor: ScoreFactor, isPositive: Bool) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(isPositive ? Color.green.opacity(0.5) : Color.red.opacity(0.5))
                .frame(width: 3, height: 24)

            Text(factor.name)
                .font(.system(size: 14, weight: .medium))

            Spacer()

            Text(factor.detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text(isPositive ? "+\(factor.impact)" : "\(factor.impact)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(isPositive ? .green : .red)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill((isPositive ? Color.green : Color.red).opacity(0.08))
                )
        }
    }

    // MARK: - Additives Card
    private var additivesCard: some View {
        SectionCard(title: "Additives (\(product.additives.count))", icon: "exclamationmark.triangle.fill", accentColor: .orange) {
            FlowLayout(spacing: 8) {
                ForEach(product.additives, id: \.self) { additive in
                    Text(additive)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.08))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.orange.opacity(0.15), lineWidth: 1)
                                )
                        )
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Allergens Card
    private var allergensCard: some View {
        SectionCard(title: "Allergens", icon: "exclamationmark.triangle.fill", accentColor: .red) {
            FlowLayout(spacing: 8) {
                ForEach(product.allergens, id: \.self) { allergen in
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                        Text(allergen)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.08))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.red.opacity(0.15), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Ingredients Card
    private func ingredientsCard(_ text: String) -> some View {
        SectionCard(title: "Ingredients", icon: "leaf.fill", accentColor: .green) {
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
    }

    // MARK: - Alternatives Card
    private var alternativesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header (matches SectionCard style)
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.heart.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.green.opacity(0.1))
                    )
                Text("Healthier Alternatives")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if isLoadingAlternatives {
                HStack(spacing: 10) {
                    ProgressView().scaleEffect(0.85)
                    Text("Finding US market options…")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            } else if alternatives.isEmpty {
                Text("No better US alternatives found in this category.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(alternatives) { alt in
                            AlternativeProductCard(product: alt)
                                .onTapGesture { selectedAlternative = alt }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.07), radius: 12, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(.systemGray5).opacity(0.8), lineWidth: 0.5)
        )
    }

    // MARK: - AI Insight Card

    private var aiInsightCard: some View {
        SectionCard(title: "AI Insight", icon: "sparkles", accentColor: .purple) {
            VStack(alignment: .leading, spacing: 12) {

                // 1. Loading spinner (initial fetch)
                if isLoadingInsight {
                    HStack(spacing: 10) {
                        ProgressView().scaleEffect(0.85)
                        Text("Analysing product…")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)

                // 2. Insight content
                } else if let insight = productInsight {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(insight.summary)
                            .font(.system(size: 14))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.yellow)
                                .padding(.top, 1)
                            Text(insight.tip)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: insight.badgeIcon)
                                .font(.system(size: 9))
                            Text(insight.badgeLabel)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(.purple.opacity(0.7))
                    }

                    // 3. Generating spinner — model is loaded and running inference
                    if insight.source == .ruleBased && llamaService.isModelLoaded && llamaService.isGeneratingInsight {
                        Divider()
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.75)
                            Text("Generating AI insight… this may take a minute")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                    // 4. Download / error prompt — model not yet ready
                    } else if insight.source == .ruleBased && !foundationModelsAvailable && !llamaService.isGeneratingInsight {
                        Divider()
                        llamaDownloadSection
                    }
                }
            }
        }
    }

    // MARK: - Llama Download Section

    @ViewBuilder
    private var llamaDownloadSection: some View {
        if llamaService.isDownloading {
            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Downloading AI Model…")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.purple)
                    Spacer()
                    Text("\(Int(llamaService.downloadProgress * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.purple)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.purple.opacity(0.12))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.purple)
                            .frame(width: geo.size.width * llamaService.downloadProgress, height: 6)
                            .animation(.linear(duration: 0.3), value: llamaService.downloadProgress)
                    }
                }
                .frame(height: 6)
                Text("~986 MB · Keep the app open")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

        } else if llamaService.loadFailed {
            // Model file couldn't be loaded (corrupt download or low memory)
            VStack(alignment: .leading, spacing: 6) {
                Text("Failed to load AI model.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red)
                Text("The file may be corrupted. Delete and re-download.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

        } else if llamaService.isModelDownloaded && !llamaService.isModelLoaded {
            // Model downloaded, loading into memory
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.75)
                Text("Loading AI model into memory…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

        } else if !llamaService.isModelDownloaded {
            // Offer download
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12))
                        .foregroundStyle(.purple)
                    Text("Enhance with On-Device AI")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.purple)
                }
                Text("Download a 1 GB model once for smarter, personalised insights on every scan — fully offline, no API needed.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let err = llamaService.downloadError {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await LlamaAdvisorService.shared.downloadModel() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Download · ~1 GB")
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.purple))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers
    private func novaColor(_ group: Int) -> Color {
        switch group {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        case 4: return .red
        default: return .gray
        }
    }

    private func novaLabel(_ group: Int) -> String {
        switch group {
        case 1: return "Unprocessed or minimally processed"
        case 2: return "Processed culinary ingredients"
        case 3: return "Processed foods"
        case 4: return "Ultra-processed products"
        default: return "Unknown processing level"
        }
    }

    private func novaDescription(_ group: Int) -> String {
        switch group {
        case 1: return "Fresh or minimally processed whole foods like fruits, vegetables, grains, and meat."
        case 2: return "Ingredients extracted from foods, like oils, butter, sugar, and salt."
        case 3: return "Foods made by combining group 1 and 2 ingredients, like canned foods and cheeses."
        case 4: return "Industrial formulations with additives like hydrogenated oils, modified starches, and flavor enhancers."
        default: return "Processing level unknown."
        }
    }
}

// MARK: - Section Card (Clean White)
struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    let accentColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(accentColor.opacity(0.1))
                    )

                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.07), radius: 12, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(.systemGray5).opacity(0.8), lineWidth: 0.5)
        )
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        computeLayout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

// MARK: - Alternative Product Card
struct AlternativeProductCard: View {
    let product: Product

    private var gradeColor: Color { product.healthScore.grade.color }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Grade accent stripe
            Rectangle()
                .fill(gradeColor)
                .frame(height: 3)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))

            // Product image
            AsyncImage(url: product.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 148, height: 118)
                        .clipped()
                case .failure, .empty:
                    ZStack {
                        Color(.systemGray6)
                        Image(systemName: "photo")
                            .font(.system(size: 30))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(width: 148, height: 118)
                @unknown default:
                    Color(.systemGray6).frame(width: 148, height: 118)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(product.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !product.brand.isEmpty {
                    Text(product.brand)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                // Inline score badge
                HStack(spacing: 6) {
                    VStack(spacing: 1) {
                        Text(product.healthScore.grade.rawValue)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(gradeColor)
                        Text("\(product.healthScore.score)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(gradeColor.opacity(0.8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(gradeColor.opacity(0.1))
                    )
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .frame(width: 148)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color(.systemGray5).opacity(0.8), lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}
