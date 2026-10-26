import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Helper to load PDF fonts with offline-first support.
///
/// Bundled fonts in assets/fonts/ guarantee that currency symbols like ₹ (Indian Rupee),
/// €, £, ¥, $, and all standard glyphs render correctly without network dependencies.
class PdfFontHelper {
  static pw.Font? _cachedRegular;
  static pw.Font? _cachedBold;

  /// Loads the primary regular font.
  /// First loads bundled Roboto-Regular.ttf from assets.
  /// Falls back to PdfGoogleFonts.robotoRegular() if asset load fails,
  /// then Helvetica as a last resort.
  static Future<pw.Font> loadRegularFont() async {
    if (_cachedRegular != null) return _cachedRegular!;
    try {
      final bytes = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      _cachedRegular = pw.Font.ttf(bytes);
      return _cachedRegular!;
    } catch (_) {
      try {
        _cachedRegular = await PdfGoogleFonts.robotoRegular();
        return _cachedRegular!;
      } catch (_) {
        return pw.Font.helvetica();
      }
    }
  }

  /// Loads the primary bold font.
  /// First loads bundled Roboto-Bold.ttf from assets.
  /// Falls back to PdfGoogleFonts.robotoBold() if asset load fails,
  /// then Helvetica-Bold as a last resort.
  static Future<pw.Font> loadBoldFont() async {
    if (_cachedBold != null) return _cachedBold!;
    try {
      final bytes = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      _cachedBold = pw.Font.ttf(bytes);
      return _cachedBold!;
    } catch (_) {
      try {
        _cachedBold = await PdfGoogleFonts.robotoBold();
        return _cachedBold!;
      } catch (_) {
        return pw.Font.helveticaBold();
      }
    }
  }

  /// Checks if the loaded font is Helvetica (which lacks Unicode / ₹ support).
  static bool isHelvetica(pw.Font font) {
    // Standard Type 1 Helvetica font name in pdf package is 'Helvetica' or 'Helvetica-Bold'
    return font.fontName.toLowerCase().contains('helvetica');
  }

  /// Safely sanitizes currency strings for PDF rendering.
  /// If the active font is Helvetica, replaces '₹' with 'Rs. ' to prevent tofu (☒) boxes.
  static String safeCurrencyText(String text, pw.Font font) {
    if (isHelvetica(font) && text.contains('₹')) {
      return text.replaceAll('₹', 'Rs. ');
    }
    return text;
  }
}
