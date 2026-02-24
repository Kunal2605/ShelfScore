import Foundation
import LLM   // Add via SPM: https://github.com/eastriverlee/LLM.swift

// MARK: - LlamaAdvisorService
// Manages a local GGUF model for on-device AI insights.
// The model (~986MB) is downloaded once to the app's Documents directory.

@Observable
final class LlamaAdvisorService {
    static let shared = LlamaAdvisorService()

    // MARK: - Model Configuration
    // Qwen2.5-1.5B-Instruct Q4_K_M — ~986MB, ~50 tok/s on iPhone 15 Pro
    // Uses ChatML template, good instruction-following for nutrition advice.
    private static let modelFileName = "Qwen2.5-1.5B-Instruct-Q4_K_M.gguf"
    private static let modelRemoteURL = URL(string:
        "https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf"
    )!

    private static let systemPrompt = """
        You are a concise nutrition advisor in a grocery health app. \
        Users scan barcodes and get a 0-100 health score. \
        Explain the score in 1-2 sentences, mentioning the key nutritional factors. \
        Then give ONE specific actionable shopping tip (under 12 words). \
        Respond with exactly 2 lines — no preamble, no headers:
        [Your explanation]
        Tip: [Your shopping tip]
        """

    // MARK: - Observable State (SwiftUI tracks these automatically)
    var isModelDownloaded: Bool = false
    var isModelLoaded: Bool = false
    var loadFailed: Bool = false          // true if LLM(from:) returned nil
    var isDownloading: Bool = false
    var isGeneratingInsight: Bool = false // true while respond(to:) is running
    var downloadProgress: Double = 0     // 0.0 – 1.0
    var downloadError: String?

    private var bot: LLM?

    private var modelFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Self.modelFileName)
    }

    private init() {
        isModelDownloaded = FileManager.default.fileExists(atPath: modelFileURL.path)
        if isModelDownloaded {
            Task { await self.loadModel() }
        }
    }

    // MARK: - Load Model
    // LLM(from:) is synchronous and blocks for ~5-10s on a 1GB model.
    // Run it on a background queue via withCheckedContinuation to keep the UI responsive.

    func loadModel() async {
        guard !isModelLoaded, isModelDownloaded else { return }
        let url = modelFileURL
        let systemPrompt = Self.systemPrompt

        let model: LLM? = await withCheckedContinuation { (continuation: CheckedContinuation<LLM?, Never>) in
            DispatchQueue.global(qos: .utility).async {
                guard let llm = LLM(from: url, template: .chatML(systemPrompt)) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: llm)
            }
        }

        guard let model else {
            loadFailed = true   // LLM init failed — file unreadable or out of memory
            return
        }
        bot = model
        isModelLoaded = true
    }

    // MARK: - Generate Insight

    func getInsight(for product: Product) async -> ProductInsight? {
        guard let bot = bot else { return nil }
        isGeneratingInsight = true
        defer { isGeneratingInsight = false }

        let prompt = buildPrompt(for: product)

        // respond(to:) streams tokens into bot.output and suspends until done.
        // Can take 10-60s depending on device. isGeneratingInsight lets the UI show a spinner.
        await bot.respond(to: prompt)

        let raw = bot.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        return parseInsight(from: raw)
    }

    private func buildPrompt(for product: Product) -> String {
        let negatives = product.healthScore.negatives.prefix(2)
            .map { "\($0.name): \($0.detail)" }.joined(separator: "; ")
        return """
        Product: \(product.displayName)\(product.brand.isEmpty ? "" : " by \(product.brand)")
        Score: \(product.healthScore.score)/100 (Grade \(product.healthScore.grade.rawValue))
        Per 100g — Cal: \(Int(product.nutrition.calories))kcal | \
        Sugar: \(f1(product.nutrition.sugars))g | \
        Sat.Fat: \(f1(product.nutrition.saturatedFat))g | \
        Salt: \(f2(product.nutrition.salt))g | \
        Fiber: \(f1(product.nutrition.fiber))g | \
        Protein: \(f1(product.nutrition.proteins))g
        \(negatives.isEmpty ? "" : "Key issues: \(negatives)")
        """
    }

    private func parseInsight(from raw: String) -> ProductInsight {
        let lines = raw.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let summary = lines.first ?? raw
        var tip = (lines.count > 1 ? lines[1] : "")
            .replacingOccurrences(of: "Tip: ", with: "")
            .replacingOccurrences(of: "tip: ", with: "")
        if tip.isEmpty {
            tip = "Compare similar products in this category for a healthier option."
        }
        return ProductInsight(summary: summary, tip: tip, source: .onDeviceLLM)
    }

    private func f1(_ v: Double) -> String { String(format: "%.1f", v) }
    private func f2(_ v: Double) -> String { String(format: "%.2f", v) }

    // MARK: - Download Model

    func downloadModel() async {
        guard !isModelDownloaded, !isDownloading else { return }
        isDownloading = true
        downloadProgress = 0
        downloadError = nil

        do {
            try await downloadFile(from: Self.modelRemoteURL, to: modelFileURL)
            isModelDownloaded = true
            isDownloading = false
            downloadProgress = 1.0
            await loadModel()
        } catch {
            isDownloading = false
            downloadError = "Download failed. Check your connection and try again."
        }
    }

    func cancelDownload() {
        // Cancellation is handled by deallocating the URLSession in DownloadDelegate
        isDownloading = false
        downloadProgress = 0
    }

    private func downloadFile(from source: URL, to destination: URL) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let delegate = DownloadDelegate(
                onProgress: { [weak self] p in
                    DispatchQueue.main.async { self?.downloadProgress = p }
                },
                onComplete: { tempURL in
                    do {
                        if FileManager.default.fileExists(atPath: destination.path) {
                            try FileManager.default.removeItem(at: destination)
                        }
                        try FileManager.default.moveItem(at: tempURL, to: destination)
                        cont.resume()
                    } catch {
                        cont.resume(throwing: error)
                    }
                },
                onError: { cont.resume(throwing: $0) }
            )
            URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
                .downloadTask(with: source)
                .resume()
        }
    }
}

// MARK: - URLSession Download Delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let onProgress: (Double) -> Void
    let onComplete: (URL) -> Void
    let onError: (Error) -> Void

    init(
        onProgress: @escaping (Double) -> Void,
        onComplete: @escaping (URL) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onProgress = onProgress
        self.onComplete = onComplete
        self.onError = onError
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        onComplete(location)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let error { onError(error) }
    }
}
