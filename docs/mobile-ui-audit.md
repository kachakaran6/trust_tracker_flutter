# TrustTracker Mobile UI Audit & Design System Specification

## 1. Overview & Objectives
TrustTracker's mobile presentation is being refactored from an inconsistent UI featuring mixed iconography (Material icons, filled variants, and occasional emoji), gradient cards, and glow shadows into a calm, clean, sleek, and professional fintech interface.

This audit adheres to the following hard constraints:
- **Zero changes to business logic**, data models, API contracts, SMS parsing/detection, auth, or sync.
- **Iconography**: Exclusively `LucideIcons` (clean stroke outline icons). Material icons, filled variants, and emoji icons are removed.
- **Visual Aesthetic**: Pure, disciplined mobile UI without "AI-generated" tropes (no decorative gradients, no neon glow shadows, no multi-color icon bubbles, no decorative blobs).
- **Design Tokens**: All dimensions, colors, text styles, and borders come from centralized design system tokens.
- **Accessibility & Responsiveness**: Scalable across screen widths from 320dp to tablet resolutions, with dynamic type support up to 200% font scale, in both Light and Dark themes.

---

## 2. UI Audit & Inconsistencies Inventory

### 2.1 Iconography
- **Material Icons**: Previously used widely (`Icons.dashboard_outlined`, `Icons.receipt_long_outlined`, `Icons.handshake_outlined`, `Icons.event_repeat_outlined`, `Icons.settings_outlined`, etc.).
- **Filled Variants**: Mixed outline and filled variants (`Icons.dashboard_rounded`, `Icons.favorite_rounded`).
- **Remediation**: Migrate all icons to `LucideIcons` (`LucideIcons.layoutDashboard`, `LucideIcons.receipt`, `LucideIcons.handshake`, `LucideIcons.calendarRepeat`, `LucideIcons.settings`, `LucideIcons.plus`, `LucideIcons.arrowUpRight`, `LucideIcons.arrowDownLeft`, etc.).

### 2.2 Gradients & Shadows
- **`AppGradients`**: Contained linear gradients (`primary`, `card`, `success`, `error`, `warning`, `info`, `darkSurface`) applied to cards and buttons.
- **`AppShadows`**: Contained `AppShadows.glow` and heavy colored shadows (`AppShadows.primary(primaryColor.withOpacity(0.3))`).
- **Remediation**: Deprecate gradients in favor of calm solid surfaces with subtle border dividers and restrained, neutral elevations. Remove all colored glow shadows.

### 2.3 Component Hierarchy & Layout
- **Cards**: Shift from heavy glowing containers to calm 1px bordered cards (`surface` + `outlineVariant`).
- **Headers & AppBars**: Consistent title hierarchy, back navigation, and actions using standard tokenized typography and spacing.
- **Floating Action Button**: Solid, focused primary button without neon bloom.
- **Navigation Shell**: Streamlined `LiquidGlassBottomNavBar` using crisp Lucide icons and neutral translucent glass.

---

## 3. Observations (Potential Non-UI / Logic Findings)
*Note: As per hard constraints, these observations are documented here for the product/engineering backlog and are not modified in code during this UI task.*

1. **SMS Approval Duplication Guard**: SMS detection triggers in-app reviews. Certain bank SMS formats with non-standard reference IDs may require periodic pattern updates in `test_all_patterns.dart`.
2. **Currency Precision**: Minor rounding displays for currencies with 0 decimal places (e.g. JPY) rely on `currency_detector.dart`. Ensure international formatting checks remain pure.
3. **Biometric Sticky Auth**: Cancelled prompts now safely reset authentication state without hanging, as verified in `qa_regression_test.dart`.

---

## 4. Design System Tokens Specification
- **Color Tokens**:
  - Light Background: `#F8FAFC`, Light Surface: `#FFFFFF`, Light Border: `#E2E8F0`
  - Dark Background: `#0B0F17` (Deep Obsidian), Dark Surface: `#131926`, Dark Border: `#1E293B`
  - Text Primary: Light `#0F172A`, Dark `#F8FAFC`
  - Text Secondary: Light `#475569`, Dark `#94A3B8`
  - Text Tertiary / Muted: Light `#64748B`, Dark `#64748B`
  - Financial Accents: Success `#10B981` / `#34D399`, Error `#EF4444` / `#F87171`, Warning `#F59E0B` / `#FBBF24`, Info `#3B82F6` / `#60A5FA`
- **Spacing Scale**: `xs: 4`, `sm: 8`, `md: 12`, `lg: 16`, `xl: 20`, `xxl: 24`, `xxxl: 32`
- **Border Radii**: `sm: 8`, `md: 12`, `lg: 16`, `xl: 20`, `full: 9999`
- **Typography**: Manrope for display/headings, Inter for UI body & captions.

---

## 5. Execution Roadmap & Completion Status
1. **Design System & Theme Token Standardization (`lib/core/theme/`)**: [DONE]
   - Replaced all glowing saturated shadows in `app_shadows.dart` with neutral, calm elevation tokens.
   - Flattened all gradients in `app_gradients.dart` to uniform monochromatic stops (zero visual gradient).
   - Standardized `app_dimensions.dart` (4pt/8pt scale, border radii, icon sizes, 44pt touch targets).
   - Cleaned `app_colors.dart` and `app_theme.dart` (Light Slate 50-900 / Dark Obsidian neutral palette, solid cards with 1px border, 0 elevation).
2. **Core Navigation & App Shell Overhaul (`lib/core/router/`, `lib/core/widgets/`)**: [DONE]
   - `liquid_glass_bottom_nav_bar.dart`: 100% `LucideIcons` (`layoutDashboard`, `receipt`, `handshake`, `repeat`, `settings`, `plus`), neutral translucent glass.
   - `app_router.dart`: Solid primary surface FAB, Lucide exit and quick action icons.
   - `custom_dropdown_field.dart`: `LucideIcons.chevronsUpDown`.
3. **Dashboard Screen (`lib/features/dashboard/`)**: [DONE]
   - 100% `LucideIcons`, removed gradient hero card, replaced particle shimmer with clean entrance animation.
4. **Transactions & Debt Screens (`lib/features/transactions/`)**: [DONE]
   - `transactions_page.dart`: 100% Lucide, solid total banners.
   - `add_transaction_page.dart`: 100% Lucide, calm neutral elevation.
   - `debt_manager_page.dart` & `person_debt_detail_page.dart`: Zero gradients, zero Material icons, solid avatars and settle dialogs.
   - All modal sheets (`add_debt_bottom_sheet.dart`, `debt_export_pdf_sheet.dart`, `export_bottom_sheet.dart`, `filter_bottom_sheet.dart`, `quick_add_bottom_sheet.dart`, `category_dropdown_field.dart`): 100% Lucide, zero gradients.
5. **Budget Screen (`lib/features/budget/`)**: [DONE]
   - `budget_page.dart`: Replaced gradient monthly overview card with calm solid surface (`primaryContainer` / `errorContainer`), 100% Lucide icons.
6. **Subscriptions Screen (`lib/features/subscriptions/`)**: [DONE]
   - `add_subscription_page.dart`: 100% Lucide templates and form icons.
   - `subscription_dashboard_page.dart`: Replaced gradient spending card with solid `primaryContainer`, 100% Lucide icons.
   - `subscription_card.dart`: 100% Lucide brand icons, clean stroke actions.
7. **Banking Feature (`lib/features/banking/`)**: [DONE]
   - `banking_dashboard_page.dart`, `loan_calculator_page.dart`, `loan_detail_page.dart`: Replaced gradient hero cards with solid containers, 100% Lucide icons.
   - `add_loan_page.dart`, `emi_calendar_page.dart`: 100% Lucide icons.
8. **Analytics Screen (`lib/features/analytics/`)**: [DONE]
   - `analytics_page.dart` & `summary_detail_page.dart`: Replaced gradient savings card and chart fills with solid surfaces, 100% Lucide icons.
9. **Settings & Security Screens (`lib/features/settings/`, `lib/features/security/`)**: [DONE]
   - `settings_page.dart`, `our_apps_section.dart`, `avatar_selection_modal.dart`: 100% Lucide icons.
   - `lock_screen_page.dart`, `set_pin_page.dart`: Clean numeric keypad with Lucide delete and biometric glyphs.
10. **Onboarding & SMS Detection (`lib/features/onboarding/`, `lib/features/sms_detection/`)**: [DONE]
    - `whats_new_splash_page.dart`: Removed all linear gradients and glow shadows, 100% Lucide icons.
    - `onboarding_page.dart`, `quick_features_intro_page.dart`: 100% Lucide icons.
    - `sms_activity_page.dart`, `sms_review_page.dart`, and SMS review widgets: 100% Lucide icons.
11. **Safe Area & Status Bar Padding Handling**: [DONE]
    - Configured transparent status bar and automatic brightness in `AppBarTheme` (`SystemUiOverlayStyle`).
    - Added `useSafeArea: true` to all `showModalBottomSheet` instances across the app (`whats_new_splash_page.dart`, `app_router.dart`, `transactions_page.dart`, `debt_manager_page.dart`, `person_debt_detail_page.dart`, `analytics_page.dart`, `debt_export_pdf_sheet.dart`, `quick_add_bottom_sheet.dart`, `categories_page.dart`, `sms_activity_page.dart`, `sms_review_sheet.dart`, `sms_sync_history_sheet.dart`) to completely prevent any status bar / notch / camera cutout collisions.
12. **Version & Build Configuration**: [DONE]
    - Aligned patch number with build number in `pubspec.yaml`: `1.2.48+48`.
13. **Verification & Tests**: [DONE]
    - `liquid_glass_bottom_nav_bar_test.dart`: 5/5 passed (100%).
    - `qa_regression_test.dart`: 16/16 passed (100%).
    - Full repository test suite: 105/105 passed (100%).
    - Codebase verification: 0 `LinearGradient` in screens, 0 non-Lucide icons in widgets.
