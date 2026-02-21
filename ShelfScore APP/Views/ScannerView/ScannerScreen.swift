import SwiftUI

struct ScannerScreen: View {
    @State private var scannedBarcode: String?
    @State private var product: Product?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var errorRecovery: String?
    @State private var showResult = false
    @State private var showError = false
    @State private var manualBarcode = ""
    @State private var showManualEntry = false
    @State private var scanLineOffset: CGFloat = -100
    @State private var pulseCorners = false

    var onProductScanned: ((Product) -> Void)?

    var body: some View {
        ZStack {
            // Camera
            BarcodeScannerView { barcode in
                handleBarcode(barcode)
            }
            .ignoresSafeArea()

            // Overlay
            scanOverlay

            // UI chrome
            VStack(spacing: 0) {
                topBar
                Spacer()
                instructionLabel
                    .padding(.bottom, 16)
                bottomButton
                    .padding(.bottom, 50)
            }

            if isLoading {
                LoadingOverlay()
            }
        }
        .sheet(isPresented: $showResult) {
            if let product = product {
                NavigationStack {
                    ProductResultScreen(product: product)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showResult = false
                                }
                                .fontWeight(.semibold)
                            }
                        }
                }
            }
        }
        .alert("Product Not Found", isPresented: $showError) {
            Button("OK") { showError = false }
            Button("Enter Manually") {
                showError = false
                showManualEntry = true
            }
        } message: {
            Text(errorRecovery ?? errorMessage ?? "Something went wrong")
        }
        .sheet(isPresented: $showManualEntry) {
            manualEntrySheet
        }
    }

    // MARK: - Scan Overlay
    private var scanOverlay: some View {
        GeometryReader { geo in
            let frameWidth = min(geo.size.width - 64, 280.0)
            let frameHeight = frameWidth * 0.6
            let centerX = geo.size.width / 2
            let centerY = geo.size.height / 2 - 40
            let frameRect = CGRect(
                x: centerX - frameWidth / 2,
                y: centerY - frameHeight / 2,
                width: frameWidth,
                height: frameHeight
            )

            ZStack {
                // Semi-transparent overlay
                Color.black.opacity(0.45)
                    .ignoresSafeArea()

                // Clear cutout
                RoundedRectangle(cornerRadius: 16)
                    .frame(width: frameWidth, height: frameHeight)
                    .position(x: centerX, y: centerY)
                    .blendMode(.destinationOut)

                // Corner brackets
                scanFrame(rect: frameRect)

                // Scan line
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.green.opacity(0.7), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: frameWidth - 32, height: 2)
                    .shadow(color: .green.opacity(0.4), radius: 6)
                    .position(x: centerX, y: centerY + scanLineOffset)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                        ) {
                            scanLineOffset = 100
                        }
                    }
            }
            .compositingGroup()
        }
    }

    // MARK: - Corner Brackets
    private func scanFrame(rect: CGRect) -> some View {
        let len: CGFloat = 28
        let lw: CGFloat = 3.5
        let cr: CGFloat = 10

        return ZStack {
            // Top-left
            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
                p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cr))
                p.addQuadCurve(to: CGPoint(x: rect.minX + cr, y: rect.minY),
                               control: CGPoint(x: rect.minX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))
            }
            .stroke(Color.white, lineWidth: lw)

            // Top-right
            Path { p in
                p.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.maxX - cr, y: rect.minY))
                p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + cr),
                               control: CGPoint(x: rect.maxX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))
            }
            .stroke(Color.white, lineWidth: lw)

            // Bottom-left
            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: rect.maxY - len))
                p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cr))
                p.addQuadCurve(to: CGPoint(x: rect.minX + cr, y: rect.maxY),
                               control: CGPoint(x: rect.minX, y: rect.maxY))
                p.addLine(to: CGPoint(x: rect.minX + len, y: rect.maxY))
            }
            .stroke(Color.white, lineWidth: lw)

            // Bottom-right
            Path { p in
                p.move(to: CGPoint(x: rect.maxX - len, y: rect.maxY))
                p.addLine(to: CGPoint(x: rect.maxX - cr, y: rect.maxY))
                p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - cr),
                               control: CGPoint(x: rect.maxX, y: rect.maxY))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
            }
            .stroke(Color.white, lineWidth: lw)
        }
        .shadow(color: .white.opacity(pulseCorners ? 0.4 : 0.1), radius: pulseCorners ? 8 : 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseCorners = true
            }
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
                Text("ShelfScore")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text("Scan any product barcode")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.top, 60)
    }

    // MARK: - Instruction Label
    private var instructionLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "viewfinder")
                .font(.system(size: 13))
            Text("Position barcode within the frame")
                .font(.system(size: 14, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.35))
        )
    }

    // MARK: - Bottom Button
    private var bottomButton: some View {
        Button {
            showManualEntry = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .font(.system(size: 14))
                Text("Enter barcode manually")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.15))
            )
        }
    }

    // MARK: - Manual Entry Sheet
    private var manualEntrySheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.08))
                        .frame(width: 72, height: 72)

                    Image(systemName: "barcode")
                        .font(.system(size: 28))
                        .foregroundStyle(.green)
                }

                VStack(spacing: 6) {
                    Text("Enter Barcode")
                        .font(.system(size: 20, weight: .bold, design: .rounded))

                    Text("Type the number below the barcode")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                TextField("e.g. 3017624010701", text: $manualBarcode)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    .keyboardType(.numberPad)
                    .font(.system(size: 17, weight: .medium, design: .monospaced))

                Button {
                    showManualEntry = false
                    if !manualBarcode.isEmpty {
                        handleBarcode(manualBarcode)
                        manualBarcode = ""
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                        Text("Look Up")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(manualBarcode.isEmpty ? Color(.systemGray4) : Color.green)
                    )
                    .foregroundStyle(.white)
                }
                .disabled(manualBarcode.isEmpty)

                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showManualEntry = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Handler
    private func handleBarcode(_ barcode: String) {
        guard !isLoading else { return }
        scannedBarcode = barcode
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let fetchedProduct = try await OpenFoodFactsService.shared.fetchProduct(barcode: barcode)
                await MainActor.run {
                    self.product = fetchedProduct
                    self.isLoading = false
                    self.showResult = true
                    self.onProductScanned?(fetchedProduct)
                }
            } catch let error as ShelfScoreError {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.errorDescription
                    self.errorRecovery = error.recoverySuggestion
                    self.showError = true
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
}
