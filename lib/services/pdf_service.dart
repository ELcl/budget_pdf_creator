import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/budget_model.dart';
import '../models/client_model.dart';

class PdfService {
  // Genera el documento PDF base
  static Future<pw.Document> generatePdfDocument({
    required Budget budget,
    required Client client,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'COTIZACIÓN',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                  ),
                  pw.Text(
                    'Fecha: ${budget.date}',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.blue800, thickness: 2),
              pw.SizedBox(height: 10),

              // Título del Presupuesto
              pw.Text(
                budget.title,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 15),

              // Datos del Cliente
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Cliente: ${client.name}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Teléfono: ${client.phone}'),
                    pw.SizedBox(height: 4),
                    pw.Text('Dirección: ${client.address}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Tabla de Ítems
              pw.Text(
                'Detalle de Productos / Servicios:',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),

              pw.Table.fromTextArray(
                headers: ['Descripción', 'Cant.', 'P. Unit. (Bs.)', 'Subtotal (Bs.)'],
                data: budget.items.map((item) {
                  return [
                    item.description,
                    item.quantity.toString(),
                    item.unitPrice.toStringAsFixed(2),
                    item.subtotal.toStringAsFixed(2),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                },
              ),
              pw.SizedBox(height: 20),

              // Total General
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.green100,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Text(
                      'TOTAL GENERAL: Bs. ${budget.totalAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  // 1. Vista previa y opción de guardar/imprimir nativa (Botón superior derecho: Descarga)
  static Future<void> saveAndOpenPdf({
    required Budget budget,
    required Client client,
  }) async {
    final pdf = await generatePdfDocument(budget: budget, client: client);
    
    // Genera el nombre limpio y profesional para el archivo
    final safeTitle = budget.title.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
    final fileName = '${safeTitle}_presupuesto.pdf';

    // Lanza el panel nativo de impresión y guardado de PDF del sistema
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: fileName,
    );
  }

  // 2. Compartir de forma general por cualquier plataforma (Botón inferior)
  static Future<void> shareBudgetPdf({
    required Budget budget,
    required Client client,
  }) async {
    final pdf = await generatePdfDocument(budget: budget, client: client);
    final bytes = await pdf.save();

    final output = await getTemporaryDirectory();
    final safeTitle = budget.title.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
    final file = File('${output.path}/${safeTitle}_presupuesto.pdf');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Compartiendo cotización: ${budget.title} - Monto: Bs. ${budget.totalAmount.toStringAsFixed(2)}',
    );
  }
}