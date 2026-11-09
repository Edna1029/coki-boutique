import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/sale_model.dart';
import '../../core/constants/app_fonts.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';

class PdfReceiptService {
  /// Payment method as printed on the receipt, in the receipt's language.
  static String _paymentLabel(String method, bool isAmharic) {
    switch (method) {
      case 'cash':
        return isAmharic ? 'ጥሬ ገንዘብ' : 'Cash';
      case 'mobile_transfer':
        return 'CBE / Telebirr';
      case 'credit':
        return isAmharic ? 'ብድር' : 'Credit';
      default:
        return method.toUpperCase();
    }
  }

  /// Generates a professional retail PDF receipt for Coki Boutique
  static Future<Uint8List> generateReceiptPdf(
    SaleModel sale, {
    bool isAmharic = false,
  }) async {
    final pdf = pw.Document();

    // Bundled fonts (offline-safe). Amharic receipts use Ethiopic as primary;
    // the other family is a glyph fallback so mixed text renders in both.
    final latin = pw.Font.ttf(await rootBundle.load(AppFonts.latinRegularAsset));
    final latinBold = pw.Font.ttf(await rootBundle.load(AppFonts.latinBoldAsset));
    final ethiopic = pw.Font.ttf(await rootBundle.load(AppFonts.ethiopicRegularAsset));
    final ethiopicBold = pw.Font.ttf(await rootBundle.load(AppFonts.ethiopicBoldAsset));
    final font = isAmharic ? ethiopic : latin;
    final boldFont = isAmharic ? ethiopicBold : latinBold;
    final fallbackFonts = isAmharic ? [latin, latinBold] : [ethiopic, ethiopicBold];

    final storeTitle = isAmharic ? 'ኮኪ ቡቲክ' : 'COKI BOUTIQUE';
    final storeSubtitle = isAmharic
        ? 'የአልባሳት እና ጌጣጌጦች መደብር'
        : 'Clothing & Fashion Accessories';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        theme: pw.ThemeData.withFont(base: font, bold: boldFont, fontFallback: fallbackFonts),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Store Header
              pw.Text(
                storeTitle,
                style: pw.TextStyle(font: boldFont, fontSize: 16),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                storeSubtitle,
                style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700),
              ),
              pw.Text(
                'Bole Medhanialem, Addis Ababa | +251 911 223 344',
                style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // Metadata
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(isAmharic ? 'ደረሰኝ ቁጥር:' : 'Receipt #:', style: pw.TextStyle(font: font, fontSize: 8)),
                  pw.Text(sale.saleId.substring(0, 8).toUpperCase(), style: pw.TextStyle(font: boldFont, fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(isAmharic ? 'ቀን:' : 'Date:', style: pw.TextStyle(font: font, fontSize: 8)),
                  pw.Text(DateFormatter.formatIsoDate(sale.date, isAmharic: isAmharic), style: pw.TextStyle(font: font, fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(isAmharic ? 'ሰራተኛ:' : 'Cashier:', style: pw.TextStyle(font: font, fontSize: 8)),
                  pw.Text(sale.employeeName, style: pw.TextStyle(font: font, fontSize: 8)),
                ],
              ),
              if (sale.customerName != null && sale.customerName!.isNotEmpty)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(isAmharic ? 'ደንበኛ:' : 'Customer:', style: pw.TextStyle(font: font, fontSize: 8)),
                    pw.Text(sale.customerName!, style: pw.TextStyle(font: font, fontSize: 8)),
                  ],
                ),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // Items Table
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text(isAmharic ? 'ዕቃ' : 'Item', style: pw.TextStyle(font: boldFont, fontSize: 8))),
                  pw.Expanded(flex: 1, child: pw.Text(isAmharic ? 'መጠን' : 'Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: boldFont, fontSize: 8))),
                  pw.Expanded(flex: 2, child: pw.Text(isAmharic ? 'ድምር' : 'Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: boldFont, fontSize: 8))),
                ],
              ),
              pw.SizedBox(height: 4),

              ...sale.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(item.productName, style: pw.TextStyle(font: font, fontSize: 8)),
                            if (item.size.isNotEmpty)
                              pw.Text('${isAmharic ? "መጠን:" : "Size:"} ${item.size}', style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700)),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: 8)),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          CurrencyFormatter.format(item.totalAmount, isAmharic: isAmharic),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(font: font, fontSize: 8),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(isAmharic ? 'ንዑስ ድምር:' : 'Subtotal:', style: pw.TextStyle(font: font, fontSize: 8)),
                  pw.Text(CurrencyFormatter.format(sale.subtotal, isAmharic: isAmharic), style: pw.TextStyle(font: font, fontSize: 8)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(isAmharic ? 'ታክስ (15%):' : 'Tax (15%):', style: pw.TextStyle(font: font, fontSize: 8)),
                  pw.Text(CurrencyFormatter.format(sale.taxAmount, isAmharic: isAmharic), style: pw.TextStyle(font: font, fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(isAmharic ? 'ጠቅላላ ክፍያ:' : 'TOTAL:', style: pw.TextStyle(font: boldFont, fontSize: 11)),
                  pw.Text(CurrencyFormatter.format(sale.totalAmount, isAmharic: isAmharic), style: pw.TextStyle(font: boldFont, fontSize: 11)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(isAmharic ? 'የክፍያ ዘዴ:' : 'Payment Method:', style: pw.TextStyle(font: font, fontSize: 8)),
                  pw.Text(_paymentLabel(sale.paymentMethod, isAmharic), style: pw.TextStyle(font: font, fontSize: 8)),
                ],
              ),

              pw.SizedBox(height: 12),
              pw.Text(
                isAmharic ? 'ስለጎበኙን እናመሰግናለን!' : 'Thank you for shopping at Coki Boutique!',
                style: pw.TextStyle(font: font, fontSize: 8, fontStyle: pw.FontStyle.italic),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                isAmharic
                    ? 'በዚህ ደረሰኝ ዕቃዎችን በ7 ቀናት ውስጥ መቀየር ይቻላል።'
                    : 'Items can be exchanged within 7 days with this receipt.',
                style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey600),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Print or share receipt directly
  static Future<void> printReceipt(SaleModel sale, {bool isAmharic = false}) async {
    final pdfBytes = await generateReceiptPdf(sale, isAmharic: isAmharic);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Receipt_${sale.saleId.substring(0, 8)}',
    );
  }
}
