# Trust Tracker – Smart Expense Tracker

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=flat&logo=dart&logoColor=white)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Trust Tracker** is a professional, offline-first personal finance management application built with Flutter. It combines a premium user experience with robust performance to help users take full control of their financial health. Designed with privacy and security at its core, Trust Tracker keeps all your data strictly on your device while providing world-class analytics and reporting.

---

## 🌟 Key Features

### 💰 Financial Management
- **Effortless Tracking**: Record income and expenses with precise categorization.
- **Budgeting**: Set monthly budgets for different categories and monitor your progress with real-time progress bars.
- **Smart Categories**: Manage dozens of categories with custom icons, emojis, and thematic color palettes.

### 📊 World-Class Analytics
- **Overview Dashboard**: Instant visibility into your monthly balance, income, and spending velocity.
- **Spending Intelligence**: Analyze daily spending patterns, weekday distributions, and time-of-day habits.
- **Category Breakdowns**: Interactive pie charts for a deep dive into where your money goes.
- **Trend Analysis**: Multi-month comparison of income vs. expenses and savings rate trajectory.

### 🔒 Privacy & Security
- **Secure PIN Lock**: Mandatory PIN authentication for sensitive financial data.
- **Biometric Authentication**: Seamless access via Fingerprint or FaceID using industry-standard protocols.
- **Offline Storage**: Your data never leaves your device. Powered by Isar's local-first NoSQL architecture.

### 🌍 Internationalization
- **Multi-language Support**: Experience the app in **English**, **Hindi (हिंदी)**, or **Gujarati (ગુજરાતી)**.
- **Localized Experience**: Proper currency formatting and date-time localization for all supported regions.

### 📄 Reporting & Sharing
- **PDF Reports**: Generate professional monthly or yearly spending summaries in PDF format.
- **Excel Export**: Export your transaction data to Microsoft Excel (.xlsx) for advanced spreadsheet analysis.

---

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (v3.0+)
- **State Management**: [Riverpod](https://riverpod.dev) (Reactive, compile-safe state)
- **Database**: [Isar](https://isar.dev) (High-performance, offline-first NoSQL)
- **Navigation**: [GoRouter](https://pub.dev/packages/go_router) (Declarative routing)
- **Visualization**: [FL Chart](https://pub.dev/packages/fl_chart) (Interactive data rendering)
- **Security**: [Local Auth](https://pub.dev/packages/local_auth) & [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)
- **Reporting**: [PDF](https://pub.dev/packages/pdf) & [Excel](https://pub.dev/packages/excel)

---

## 📂 Project Structure

```text
lib/
├── core/               # Global services (Auth, Storage, Theme, Router)
├── features/           # Domain-driven feature modules
│   ├── analytics/      # Charts, dashboards, and spending intelligence
│   ├── budget/         # Budget tracking and management
│   ├── transactions/   # CRUD logic for income/expense data
│   └── categories/     # Category definitions and customization
├── l10n/               # Multi-language localization (ARB files)
├── generated/          # Auto-generated Isar schemas and l10n code
└── main.dart           # Application entry point & service initialization
```

---

## 🚀 Installation & Setup

### Prerequisites
- Flutter SDK installed (run `flutter doctor` to verify)
- Android Studio or VS Code with Flutter extension
- An emulator or physical device

### Steps
1. **Clone the project:**
   ```bash
   git clone https://github.com/kachakaran6/trust_tracker_flutter.git
   cd trust_tracker_flutter
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Generate required code:**
   Isar schemas and localization require code generation:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

---

## 💡 Usage

1.  **Dashboard**: See your current month's liquidity and top spending categories at a glance.
2.  **Transactions**: Tap the '+' button to add a new transaction. Categorize it to populate your analytics.
3.  **Analytics**: Swipe between different modes (Overview, Spending, Categories, Trends) to uncover financial habits.
4.  **Export**: Head to Settings to generate detailed reports in PDF or Excel format.

---

## 🛡️ Security Implementation

- **Data Encryption**: Sensitive settings are stored using `flutter_secure_storage`.
- **Local Authentication**: Uses `local_auth` to integrate with system-level biometric hardware.
- **Auto-Lock**: The application automatically locks when minimized to background, ensuring your data remains private even if the device is shared.

---

## 📌 Roadmap

- [ ] **Cloud Sync**: Optional encrypted backup to Google Drive or iCloud.
- [ ] **Investment Tracking**: Support for portfolio management and stock tracking.
- [ ] **Smart AI Insights**: AI-powered spending recommendations and anomaly detection.
- [ ] **Dark Mode Transitions**: More granular control over aesthetic themes.

---

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## ⚖️ License

Distributed under the MIT License. See `LICENSE` for more information.

---

## ✉️ Contact

**Karan Kacha** - [kachakaran06@gmail.com](mailto:kachakaran06@gmail.com)

Project Link: [https://github.com/kachakaran6/trust_tracker_flutter](https://github.com/kachakaran6/trust_tracker_flutter)
