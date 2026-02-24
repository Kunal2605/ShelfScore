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
- **📶 Offline Caching** — Previously scanned products available with full nutrition data even without internet
- **🛒 Grocery List** — Add products by barcode/search or type custom items; track what you've bought
- **🍽️ Recipe Browser** — Browse popular recipes or search by name; view macros and add ingredients directly to your grocery list
- **🧠 On-Device AI Insights** — Optional ~1 GB model runs fully offline on your device; generates personalised explanations and shopping tips for every product scan
- **🎬 Animated Splash Screen** — Premium branded launch animation

---

## 🏗️ Architecture

```
ShelfScore APP/
├── ShelfScore_APPApp.swift          # App entry point + splash → main transition
├── Secrets.swift                    # API keys — gitignored, never committed (see Setup)
├── Models/
│   ├── Product.swift                # Domain model + API response mapping
│   ├── Recipe.swift                 # Recipe + ingredient models + Spoonacular response types
│   ├── NutritionFacts.swift         # Nutrition data with nutrient-level ratings
│   ├── HealthScore.swift            # Score model with A–E grading
│   ├── GroceryItem.swift            # SwiftData model for grocery list items
│   └── CachedProduct.swift          # SwiftData model for offline product cache
├── Services/
│   ├── OpenFoodFactsService.swift   # API client with cache-aware fetching
│   ├── SpoonacularService.swift     # Recipe API client (search, popular, detail)
│   ├── AIAdvisorService.swift       # Orchestrates AI insight priority (Apple Intelligence → llama.cpp → rule-based)
│   ├── LlamaAdvisorService.swift    # On-device LLM via llama.cpp (LLM.swift); manages download + inference
│   └── HealthScoreCalculator.swift  # Nutri-Score 2023 based scoring algorithm
├── Views/
│   ├── SplashScreen.swift           # Animated launch screen
│   ├── ScannerView/
│   │   ├── ScannerScreen.swift      # Main scanner UI with overlay
│   │   └── BarcodeScannerView.swift # AVFoundation camera integration
│   ├── SearchView/
│   │   ├── SearchScreen.swift       # Product search by name
│   │   └── SearchResultRow.swift    # Individual search result row
│   ├── RecipesView/
│   │   ├── RecipeListScreen.swift   # Recipe browser with search + popular grid
│   │   ├── RecipeDetailScreen.swift # Recipe detail: macros, ingredients, add to list
│   │   ├── RecipeCard.swift         # Recipe grid card component
│   │   └── RecipeIngredientRow.swift# Ingredient row with individual add button
│   ├── GroceryListView/
│   │   ├── GroceryListScreen.swift  # Grocery list with Need to Buy / Bought sections
│   │   ├── GroceryListRow.swift     # Individual grocery item row
│   │   └── GrocerySearchSheet.swift # Search & add sheet with Quick Add support
│   ├── ProductView/
│   │   ├── ProductResultScreen.swift# Product detail with score gauge
│   │   ├── ScoreGaugeView.swift     # Animated circular score gauge
│   │   └── NutrientRowView.swift    # Individual nutrient display row
│   ├── HistoryView/
│   │   └── HistoryScreen.swift      # Scan history list
│   └── Components/
│       ├── LoadingOverlay.swift     # Animated loading spinner
│       └── ScoreBadge.swift         # Compact score badge
└── Utilities/
    └── Extensions.swift             # Color, View, and Date helpers
```

---

## 🧠 On-Device AI Insights

Every product scan shows an **AI Insight card** with a personalised explanation of the health score and one actionable shopping tip. The feature uses a three-tier priority system so it always works — even without internet or Apple Intelligence:

| Priority | Source | Requirement |
|---|---|---|
| 1 | **Apple Intelligence** | iOS 26+, Apple Intelligence enabled |
| 2 | **On-Device LLM** (llama.cpp) | One-time ~1 GB model download |
| 3 | **Rule-Based** | Always available, no download needed |

**Model:** Qwen2.5-1.5B-Instruct Q4_K_M (~986 MB), served via [LLM.swift](https://github.com/eastriverlee/LLM.swift) (llama.cpp wrapper). Runs fully offline after download — no API key, no server.

**How to enable the LLM:**
1. Scan any product to open the product detail screen
2. In the **AI Insight** card, tap **Download · ~1 GB**
3. Keep the app open while downloading (~986 MB)
4. Once downloaded, the model loads automatically and upgrades the insight from rule-based to on-device AI on every future scan

> **Note:** Inference can take 10–60 seconds depending on your device. A spinner is shown while the model is generating. The rule-based insight is always shown first as an instant fallback.

**Adding LLM.swift via Xcode:**
1. Open `ShelfScore APP.xcodeproj`
2. Go to **File → Add Package Dependencies**
3. Enter: `https://github.com/eastriverlee/LLM.swift`
4. Add the package to the `ShelfScore APP` target

---

## 🍽️ Recipe Feature

The Recipe tab lets you discover recipes, check their macros, and add ingredients to your grocery list in one tap.

**Flow:**
1. Open the **Recipes** tab (fork & knife icon)
2. Browse popular recipes or search by name (e.g. "pasta", "chicken salad")
3. Tap any recipe to see its full detail:
   - **Macro bar** — Calories, Protein, Carbs, Fat at a glance
   - **Cook time & servings**
   - **Full ingredient list** with quantities
4. Tap **+** on any ingredient to add it to your Grocery List, or tap **Add All to Grocery List** to add everything at once
5. Switch to the **Grocery List** tab — the ingredients are ready to shop

Powered by the [Spoonacular API](https://spoonacular.com/food-api) (requires an API key — see Setup below).

---

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

---

## 📶 Offline Caching

ShelfScore uses an **API-first, cache-fallback** strategy so previously scanned products are always available — even without internet.

1. **You scan a barcode** → the app fetches fresh data from Open Food Facts
2. **On success** → the full product is saved to a local `CachedProduct` store via SwiftData
3. **On network failure** → the app checks the local cache for that barcode
4. **If neither works** → an error is shown

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Camera | AVFoundation |
| Persistence | SwiftData |
| Caching | SwiftData (CachedProduct) |
| Product API | Open Food Facts (REST, free) |
| Recipe API | Spoonacular (REST, free tier) |
| On-Device AI | LLM.swift (llama.cpp) + Apple Foundation Models (iOS 26+) |
| AI Model | Qwen2.5-1.5B-Instruct Q4_K_M (~986 MB GGUF) |
| Scoring | Nutri-Score 2023 (adapted) |
| Min Target | iOS 17+ |

---

## 🚀 Getting Started

### 1. Get a Spoonacular API Key

The recipe feature requires a free Spoonacular API key.

1. Go to [spoonacular.com/food-api](https://spoonacular.com/food-api) and click **Get Started**
2. Create a free account — no credit card required
3. Your API key will be shown in the [API Console](https://spoonacular.com/food-api/console)
4. The free tier includes **150 points/day** which is sufficient for normal use

### 2. Add Your API Key

Create the file `ShelfScore APP/Secrets.swift` (this file is gitignored and will never be committed):

```swift
enum Secrets {
    static let spoonacularAPIKey = "your_api_key_here"
}
```

> **Note:** `Secrets.swift` is listed in `.gitignore`. Never commit your API key to a public repository.

### 3. Add LLM.swift Package (for On-Device AI)

The on-device AI feature requires the LLM.swift Swift Package:

1. Open `ShelfScore APP.xcodeproj` in Xcode
2. Go to **File → Add Package Dependencies**
3. Enter the URL: `https://github.com/eastriverlee/LLM.swift`
4. Click **Add Package** and add it to the `ShelfScore APP` target

> **Note:** If you skip this step, the app will still work — the AI Insight card will use the rule-based fallback instead.

### 4. Build & Run

1. Open `ShelfScore APP.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build & Run (`Cmd + R`)
4. Point your camera at any product barcode — or use the Search, Recipes, or Grocery List tabs

> **Note:** Camera barcode scanning requires a physical device. The simulator does not support camera input — use manual barcode entry instead.

---

## 📄 License

This project is for personal/educational use.

---

*Built with ❤️ and SwiftUI*
