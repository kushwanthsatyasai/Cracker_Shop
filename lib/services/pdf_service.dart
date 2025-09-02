import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/bill.dart';

class PDFService {
  // Generate PDF bytes (works on all platforms)
  static Future<Uint8List> generateBillPDFBytes(Bill bill) async {
    final pdf = pw.Document();

    // Create PDF content
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            _buildHeader(),
            pw.SizedBox(height: 20),
            
            // Bill Information
            _buildBillInfo(bill),
            pw.SizedBox(height: 20),
            
            // Customer Information
            _buildCustomerInfo(bill),
            pw.SizedBox(height: 20),
            
            // Items Table
            _buildItemsTable(bill),
            pw.SizedBox(height: 20),
            
            // Totals
            _buildTotals(bill),
            pw.SizedBox(height: 30),
            
            // Footer
            _buildFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Generate PDF file (for mobile platforms only)
  static Future<File?> generateBillPDF(Bill bill) async {
    // Web doesn't support file operations, return null
    if (kIsWeb) {
      return null;
    }

    try {
      final pdfBytes = await generateBillPDFBytes(bill);
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/bill_${bill.billNumber}.pdf');
      await file.writeAsBytes(pdfBytes);
      return file;
    } catch (e) {
      print('Error generating PDF file: $e');
      return null;
    }
  }

  static pw.Widget _buildHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          'VANI FIRE CRACKERS',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Shop No: 1',
          style: pw.TextStyle(
            fontSize: 12,
          ),
        ),
        pw.Text(
          'Your Trusted Fireworks Store',
          style: pw.TextStyle(
            fontSize: 12,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Container(
          height: 2,
          color: PdfColors.orange,
        ),
      ],
    );
  }

  static pw.Widget _buildBillInfo(Bill bill) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'BILL DETAILS',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Bill No: ${bill.billNumber}'),
            pw.Text('Date: ${_formatDate(bill.createdAt)}'),
            pw.Text('Payment: ${(bill.paymentMethod ?? 'cash').toUpperCase()}'),
            if (bill.billerName != null)
              pw.Text('Biller: ${bill.billerName}'),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.orange),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                'TOTAL AMOUNT',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Rs.${bill.totalAmount.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCustomerInfo(Bill bill) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CUSTOMER INFORMATION',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text('Name: ${bill.customerName}'),
              ),
              pw.Expanded(
                child: pw.Text('Mobile: ${bill.customerMobile}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(Bill bill) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PURCHASED ITEMS',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey),
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('S.No', isHeader: true),
                _buildTableCell('Product Name', isHeader: true),
                _buildTableCell('Category', isHeader: true),
                _buildTableCell('Qty', isHeader: true),
                _buildTableCell('Rate', isHeader: true),
                _buildTableCell('Amount', isHeader: true),
              ],
            ),
            // Data rows
            ...bill.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return pw.TableRow(
                children: [
                  _buildTableCell('${index + 1}'),
                  _buildTableCell(item.productName),
                  _buildTableCell(item.category),
                  _buildTableCell('${item.quantity}'),
                  _buildTableCell('Rs.${item.unitPrice.toStringAsFixed(2)}'),
                  _buildTableCell('Rs.${item.totalPrice.toStringAsFixed(2)}'),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  static pw.Widget _buildTotals(Bill bill) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text('Subtotal: '),
              pw.SizedBox(width: 20),
              pw.Text('Rs.${bill.subtotal.toStringAsFixed(2)}'),
            ],
          ),
          pw.SizedBox(height: 5),
          if (bill.subtotal != bill.totalAmount) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Discount: '),
                pw.SizedBox(width: 20),
                pw.Text('Rs.${(bill.subtotal - bill.totalAmount).toStringAsFixed(2)}'),
              ],
            ),
            pw.SizedBox(height: 5),
          ],
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColors.orange,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  'TOTAL: Rs.${bill.totalAmount.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Container(
          height: 1,
          color: PdfColors.grey,
        ),
        pw.SizedBox(height: 15),
        pw.Text(
          'Thank you for choosing Vani Fire Crackers!',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Wishing you a safe and joyful celebration!',
          style: const pw.TextStyle(
            fontSize: 10,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'For any queries, please contact us.',
          style: const pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
