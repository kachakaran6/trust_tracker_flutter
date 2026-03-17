import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/export_transaction_row.dart';

class ExcelGenerator {
  static Future<File> generate({
    required List<ExportTransactionRow> rows,
    required String currency,
  }) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Transactions'];

    // Header styling
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1D4ED8'), // Blue 700
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final dateTimeStyle = CellStyle(
      numberFormat: NumFormat.custom(formatCode: 'dd mmm yyyy hh:mm AM/PM'),
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );

    final amountStyle = CellStyle(
      numberFormat: NumFormat.standard_4,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    // Headers
    const headers = [
      'Date & Time',
      'Transaction',
      'Category',
      'Type',
      'Notes',
      'Amount',
    ];
    for (var i = 0; i < headers.length; i++) {
      final cell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    sheet.setColumnWidth(0, 24);
    sheet.setColumnWidth(1, 22);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 14);
    sheet.setColumnWidth(4, 28);
    sheet.setColumnWidth(5, 14);

    // Data rows
    for (var i = 0; i < rows.length; i++) {
      final exportRow = rows[i];
      final row = i + 1;

      final dateTimeCell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
      dateTimeCell.value = DateTimeCellValue(
        year: exportRow.timestamp.year,
        month: exportRow.timestamp.month,
        day: exportRow.timestamp.day,
        hour: exportRow.timestamp.hour,
        minute: exportRow.timestamp.minute,
        second: exportRow.timestamp.second,
      );
      dateTimeCell.cellStyle = dateTimeStyle;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = TextCellValue(exportRow.title);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = TextCellValue(exportRow.category);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = TextCellValue(exportRow.typeLabel);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = TextCellValue(exportRow.notes);

      final amountCell =
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row));
      amountCell.value = DoubleCellValue(exportRow.signedAmount);
      amountCell.cellStyle = amountStyle;
    }

    // Summary data
    double totalIncome = 0;
    double totalExpense = 0;
    for (final row in rows) {
      if (row.isIncome) {
        totalIncome += row.amount;
      } else {
        totalExpense += row.amount;
      }
    }

    final summaryLabelStyle = CellStyle(bold: true);
    final summaryAmountStyle = CellStyle(
      bold: true,
      numberFormat: NumFormat.standard_4,
      horizontalAlign: HorizontalAlign.Right,
    );

    final summaryRow = rows.length + 3;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: summaryRow))
        .value = TextCellValue('Total Income ($currency)');
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: summaryRow))
        .cellStyle = summaryLabelStyle;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: summaryRow))
        .value = DoubleCellValue(totalIncome);
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: summaryRow))
        .cellStyle = summaryAmountStyle;

    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: 4, rowIndex: summaryRow + 1))
        .value = TextCellValue('Total Expense ($currency)');
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: 4, rowIndex: summaryRow + 1))
        .cellStyle = summaryLabelStyle;
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: 5, rowIndex: summaryRow + 1))
        .value = DoubleCellValue(totalExpense);
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: 5, rowIndex: summaryRow + 1))
        .cellStyle = summaryAmountStyle;

    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: 4, rowIndex: summaryRow + 2))
        .value = TextCellValue('Net Balance ($currency)');
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: 4, rowIndex: summaryRow + 2))
        .cellStyle = summaryLabelStyle;
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: 5, rowIndex: summaryRow + 2))
        .value = DoubleCellValue(totalIncome - totalExpense);
    sheet
        .cell(CellIndex.indexByColumnRow(
            columnIndex: 5, rowIndex: summaryRow + 2))
        .cellStyle = summaryAmountStyle;

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/trust_tracker_spread_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    final bytes = excel.save();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }
    return file;
  }
}
