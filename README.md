# 🍃 ShelfScore

**Scan any product barcode. Get an instant health score.**

ShelfScore is an iOS app that helps you make healthier grocery choices by scanning product barcodes and calculating a science-backed health score (0–100) based on real nutritional data.

---

## ✨ Features

- **📷 Barcode Scanner** — Scan EAN-13, EAN-8, UPC-E, Code128, and more using your camera
- **⌨️ Manual Entry** — Type in a barcode number if scanning isn't an option
- **🧮 Health Score (0–100)** — Powered by an algorithm based on the [Nutri-Score 2023](https://www.santepubliquefrance.fr) methodology
- **📊 Detailed Breakdown** — See exactly what's helping and hurting each product's score
- **🥗 Nutrition Facts** — Full per-100g nutrition table with color-coded levels (low/moderate/high)
- **⚙️ NOVA Processing Level** — Shows how processed a product is (Groups 1–4)
- **⚠️ Additives & Allergens** — Lists additives and allergen warnings
- **📋 Scan History** — All scanned products saved locally with SwiftData for quick reference

## 🏗️ Architecture

```
ShelfScore APP/
├── ShelfScore_APPApp.swift          # App entry point + root ContentView
├── Models/
│   ├── Product.swift                # Domain model + API response mapping
│   ├── NutritionFacts.swift         # Nutrition data with nutrient-level ratings
│   └── HealthScore.swift            # Score model with A–E grading
├── Services/
│   ├── OpenFoodFactsService.swift   # API client for Open Food Facts
│   └── HealthScoreCalculator.swift  # Nutri-Score 2023 based scoring algorithm
├── Views/
│   ├── ScannerView/
│   │   ├── ScannerScreen.swift      # Main scanner UI with overlay
│   │   └── BarcodeScannerView.swift # AVFoundation camera integration
│   ├── ProductView/
│   │   ├── ProductResultScreen.swift # Product detail with score gauge
│   │   ├── ScoreGaugeView.swift     # Animated circular score gauge
│   │   └── NutrientRowView.swift    # Individual nutrient display row
│   ├── HistoryView/
│   │   └── HistoryScreen.swift      # Scan history list + SwiftData model
│   └── Components/
│       ├── LoadingOverlay.swift     # Animated loading spinner
│       └── ScoreBadge.swift         # Compact score badge
└── Utilities/
    └── Extensions.swift             # Color, View, and Date helpers
```

## 🧮 How the Health Score Works

The score is **calculated locally** from nutrition data fetched via the [Open Food Facts API](https://world.openfoodfacts.org/). It is **not** a pre-computed value from a database.

| Component | Points | Method |
|---|---|---|
| Energy (kcal) | 0–10 negative | 80 kcal increments |
| Sugars (g) | 0–15 negative | 1g increments |
| Saturated Fat (g) | 0–10 negative | 1g increments |
| Salt (g) | 0–20 negative | 0.2g increments |
| Fiber (g) | 0–7 positive | Nutri-Score thresholds |
| Protein (g) | 0–7 positive | 1.6g increments |
| Nutri-Score Grade | 0–3 positive | A=+3, B=+2, C=+1 |
| NOVA Group | ±5 modifier | Group 1=+5, Group 4=−5 |
| Additives | ±4 modifier | Tiered by count |

**Final Score** = `100 − (rawNutriScore × 1.39) + modifiers`, clamped to 0–100.

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Camera | AVFoundation |
| Persistence | SwiftData |
| API | Open Food Facts (REST) |
| Scoring | Nutri-Score 2023 (adapted) |
| Min Target | iOS 17+ |

## 🚀 Getting Started

1. Open `ShelfScore APP.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build & Run (`Cmd + R`)
4. Point your camera at any product barcode — or tap **"Enter barcode manually"**

> **Note:** Camera barcode scanning requires a physical device. The simulator does not support camera input — use manual barcode entry instead.

## 📄 License

This project is for personal/educational use.

---

*Built with ❤️ and SwiftUI*
