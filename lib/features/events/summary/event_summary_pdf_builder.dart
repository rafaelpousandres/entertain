/// Spec 027 §B/§D — the pure PDF builder for the event summary sheet.
///
/// Takes the fully-resolved [EventSummaryData] + pre-localized
/// [EventSummaryLabels] and returns the document bytes. No provider, network or
/// `BuildContext` access — so it runs in a plain `flutter test` from fixtures.
/// Branding (cream/green/orange palette, the Entertain logo, the app fonts)
/// mirrors the manual so the printed sheet looks like the app.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../catalog/data/diet.dart' show DietBadge;
import 'event_summary_data.dart';

/// The app fonts loaded for the PDF (from `assets/fonts/`). Optional: when null
/// the builder falls back to the PDF standard fonts, which keeps unit tests
/// asset-free. The service loads and passes them so the real document is
/// on-brand.
class EventSummaryFonts {
  const EventSummaryFonts({
    required this.base,
    required this.bold,
    required this.title,
  });
  final pw.Font base;
  final pw.Font bold;
  final pw.Font title;
}

/// Entertain palette, mirrored from the app theme (`AppColors`) + the dietary
/// badge colours (Spec 026 Part C).
class _Palette {
  static final ink = PdfColor.fromInt(0xFF412402);
  static final inkSoft = PdfColor.fromInt(0xFF8A7256);
  static final green = PdfColor.fromInt(0xFF1F6B52);
  static final orange = PdfColor.fromInt(0xFFD85A30);
  static final border = PdfColor.fromInt(0xFFEDE2CC);
  static final veganBg = PdfColor.fromInt(0xFF1F6B52);
  static final vegetarianBg = PdfColor.fromInt(0xFFCFE7DD);
  static final vegetarianFg = PdfColor.fromInt(0xFF1F6B52);
  static final glutenBg = PdfColor.fromInt(0xFFD6603A);
}

/// Builds the summary PDF and returns its bytes.
Future<Uint8List> buildEventSummaryPdf({
  required EventSummaryData data,
  required EventSummaryLabels labels,
  Uint8List? logo,
  EventSummaryFonts? fonts,
}) async {
  final theme = pw.ThemeData.withFont(
    base: fonts?.base,
    bold: fonts?.bold,
  );
  final doc = pw.Document(theme: theme);

  final titleFont = fonts?.title ?? fonts?.bold;
  final boldFont = fonts?.bold;

  pw.TextStyle body({
    double size = 10,
    PdfColor? color,
    bool bold = false,
  }) => pw.TextStyle(
    font: bold ? boldFont : null,
    fontSize: size,
    color: color ?? _Palette.ink,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );

  pw.TextStyle titleStyle(double size, PdfColor color) =>
      pw.TextStyle(font: titleFont, fontSize: size, color: color);

  final widgets = <pw.Widget>[];

  // ── Cover ────────────────────────────────────────────────────────────────
  widgets.add(
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null)
              pw.Container(
                width: 38,
                height: 38,
                margin: const pw.EdgeInsets.only(right: 10),
                child: pw.ClipOval(child: pw.Image(pw.MemoryImage(logo))),
              ),
            pw.Expanded(
              child: pw.Text(labels.slogan, style: body(color: _Palette.inkSoft)),
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text(data.eventTitle, style: titleStyle(24, _Palette.green)),
        pw.SizedBox(height: 12),
        if (data.eventPhoto != null) ...[
          pw.ClipRRect(
            horizontalRadius: 8,
            verticalRadius: 8,
            child: pw.Image(
              pw.MemoryImage(data.eventPhoto!),
              height: 150,
              fit: pw.BoxFit.cover,
            ),
          ),
          pw.SizedBox(height: 12),
        ],
        for (final f in data.headerFields)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 90,
                  child: pw.Text(f.label, style: body(color: _Palette.inkSoft)),
                ),
                pw.Expanded(child: pw.Text(f.value, style: body())),
              ],
            ),
          ),
      ],
    ),
  );

  // ── Convidats ─────────────────────────────────────────────────────────────
  if (data.hasGuests) {
    widgets.add(_sectionHeader(labels.sectionGuests, titleStyle));
    for (final g in data.guestGroups) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('${g.label} · ${g.count}', style: body(bold: true)),
              pw.SizedBox(height: 2),
              pw.Text(g.names.join(', '), style: body(color: _Palette.inkSoft)),
            ],
          ),
        ),
      );
    }
    widgets.add(
      pw.Text('${labels.totalLabel} · ${data.guestsTotal}', style: body(bold: true)),
    );
    if (data.overCapacityNote != null) {
      widgets.add(pw.SizedBox(height: 3));
      widgets.add(
        pw.Text(data.overCapacityNote!, style: body(color: _Palette.orange)),
      );
    }
  }

  // ── Menú ──────────────────────────────────────────────────────────────────
  if (data.hasMenu) {
    widgets.add(_sectionHeader(labels.sectionMenu, titleStyle));
    for (final dish in data.dishes) {
      widgets.add(_dishBlock(dish, labels, body, boldFont));
    }
    if (data.drinks.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 4));
      widgets.add(pw.Text(labels.drinksHeading, style: body(bold: true, size: 12)));
      widgets.add(pw.SizedBox(height: 4));
      for (final drink in data.drinks) {
        widgets.add(_drinkRow(drink, body));
      }
    }
    if (data.totalsLines.isNotEmpty) {
      widgets.add(pw.SizedBox(height: 8));
      for (final line in data.totalsLines) {
        widgets.add(pw.Text(line, style: body(color: _Palette.inkSoft)));
      }
    }
  }

  // ── Compra ────────────────────────────────────────────────────────────────
  if (data.hasShopping) {
    widgets.add(_sectionHeader(labels.sectionPurchase, titleStyle));
    for (final group in data.suppliers) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4, bottom: 4),
          child: pw.Text(group.supplierName, style: body(bold: true, size: 12)),
        ),
      );
      for (final item in group.items) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: pw.Text(item.name, style: body())),
                pw.SizedBox(width: 8),
                pw.Text(item.measure, style: body(color: _Palette.inkSoft)),
              ],
            ),
          ),
        );
      }
    }
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  widgets.add(pw.SizedBox(height: 16));
  widgets.add(pw.Divider(color: _Palette.border, thickness: 0.5));
  widgets.add(
    pw.Text(labels.footer, style: body(size: 8, color: _Palette.inkSoft)),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 40),
      build: (_) => widgets,
    ),
  );

  return doc.save();
}

pw.Widget _sectionHeader(
  String title,
  pw.TextStyle Function(double, PdfColor) titleStyle,
) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title, style: titleStyle(16, _Palette.green)),
      pw.SizedBox(height: 4),
      pw.Divider(color: _Palette.border, thickness: 0.5),
    ],
  ),
);

pw.Widget _dishBlock(
  SummaryDish dish,
  EventSummaryLabels labels,
  pw.TextStyle Function({double size, PdfColor? color, bool bold}) body,
  pw.Font? boldFont,
) {
  final left = pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Flexible(child: pw.Text(dish.name, style: body(bold: true, size: 12))),
          if (dish.badges.isNotEmpty) ...[
            pw.SizedBox(width: 6),
            _badges(dish.badges, labels, boldFont),
          ],
        ],
      ),
      pw.SizedBox(height: 2),
      pw.Text(dish.servingsLine, style: body(color: PdfColor.fromInt(0xFF8A7256))),
      if (dish.supplierLine != null) ...[
        pw.SizedBox(height: 2),
        pw.Text(dish.supplierLine!, style: body(color: PdfColor.fromInt(0xFF8A7256))),
      ],
      if (dish.ingredients.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Text(labels.ingredientsHeading, style: body(bold: true)),
        pw.SizedBox(height: 2),
        for (final ing in dish.ingredients)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 1),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (ing.photo != null) ...[
                  pw.ClipRRect(
                    horizontalRadius: 3,
                    verticalRadius: 3,
                    child: pw.Image(
                      pw.MemoryImage(ing.photo!),
                      width: 18,
                      height: 18,
                      fit: pw.BoxFit.cover,
                    ),
                  ),
                  pw.SizedBox(width: 5),
                ] else
                  pw.Text('•  ', style: body()),
                pw.Expanded(child: pw.Text(ing.text, style: body())),
                if (ing.badges.isNotEmpty) ...[
                  pw.SizedBox(width: 6),
                  _badges(ing.badges, labels, boldFont),
                ],
              ],
            ),
          ),
      ],
      if (dish.preparation != null && dish.preparation!.trim().isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Text(labels.preparationHeading, style: body(bold: true)),
        pw.SizedBox(height: 2),
        pw.Text(dish.preparation!.trim(), style: body()),
      ],
    ],
  );

  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 14),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (dish.photo != null) ...[
          pw.ClipRRect(
            horizontalRadius: 6,
            verticalRadius: 6,
            child: pw.Image(
              pw.MemoryImage(dish.photo!),
              width: 70,
              height: 70,
              fit: pw.BoxFit.cover,
            ),
          ),
          pw.SizedBox(width: 10),
        ],
        pw.Expanded(child: left),
      ],
    ),
  );
}

pw.Widget _drinkRow(
  SummaryDrink drink,
  pw.TextStyle Function({double size, PdfColor? color, bool bold}) body,
) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 6),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      if (drink.photo != null) ...[
        pw.ClipRRect(
          horizontalRadius: 6,
          verticalRadius: 6,
          child: pw.Image(
            pw.MemoryImage(drink.photo!),
            width: 36,
            height: 36,
            fit: pw.BoxFit.cover,
          ),
        ),
        pw.SizedBox(width: 8),
      ],
      pw.Expanded(child: pw.Text(drink.name, style: body())),
      pw.SizedBox(width: 8),
      pw.Text(
        drink.supplierLine == null
            ? drink.quantityLine
            : '${drink.quantityLine}  ·  ${drink.supplierLine}',
        style: body(color: PdfColor.fromInt(0xFF8A7256)),
      ),
    ],
  ),
);

/// The VGN/VGT/SG pills, redrawn as PDF widgets with the Spec 026 colours.
pw.Widget _badges(
  List<DietBadge> badges,
  EventSummaryLabels labels,
  pw.Font? boldFont,
) => pw.Row(
  mainAxisSize: pw.MainAxisSize.min,
  children: [
    for (final b in badges)
      pw.Container(
        margin: const pw.EdgeInsets.only(left: 3),
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: pw.BoxDecoration(
          color: _badgeBg(b),
          borderRadius: pw.BorderRadius.circular(7),
        ),
        child: pw.Text(
          labels.badgeAbbrev(b),
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            color: _badgeFg(b),
          ),
        ),
      ),
  ],
);

PdfColor _badgeBg(DietBadge b) => switch (b) {
  DietBadge.vegan => _Palette.veganBg,
  DietBadge.vegetarian => _Palette.vegetarianBg,
  DietBadge.glutenFree => _Palette.glutenBg,
};

PdfColor _badgeFg(DietBadge b) => switch (b) {
  DietBadge.vegan => PdfColors.white,
  DietBadge.vegetarian => _Palette.vegetarianFg,
  DietBadge.glutenFree => PdfColors.white,
};
