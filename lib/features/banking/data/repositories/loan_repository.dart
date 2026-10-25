import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/features/banking/data/models/loan_model.dart';
import 'package:trust_tracker_flutter/features/banking/data/models/loan_payment_model.dart';

class LoanRepository {
  final DatabaseHelper _dbHelper;

  LoanRepository(this._dbHelper);

  Future<int> insertLoan(LoanModel loan) async {
    final db = await _dbHelper.database;
    return await db.insert('bank_loans', loan.toMap());
  }

  Future<void> updateLoan(LoanModel loan) async {
    final db = await _dbHelper.database;
    await db.update(
      'bank_loans',
      loan.toMap(),
      where: 'id = ?',
      whereArgs: [loan.id],
    );
  }

  Future<void> deleteLoan(int loanId) async {
    final db = await _dbHelper.database;
    await db.delete('bank_loans', where: 'id = ?', whereArgs: [loanId]);
    await db.delete('loan_payments', where: 'loanId = ?', whereArgs: [loanId]);
  }

  Future<List<LoanModel>> getAllLoans() async {
    final db = await _dbHelper.database;
    final loanMaps = await db.query('bank_loans', orderBy: 'createdAt DESC');
    
    List<LoanModel> loans = [];
    for (var map in loanMaps) {
      final payments = await getPaymentsForLoan(map['id'] as int);
      loans.add(LoanModel.fromMap(map, payments: payments));
    }
    return loans;
  }

  Future<int> insertPayment(LoanPaymentModel payment) async {
    final db = await _dbHelper.database;
    return await db.insert('loan_payments', payment.toMap());
  }

  Future<void> updatePayment(LoanPaymentModel payment) async {
    final db = await _dbHelper.database;
    await db.update(
      'loan_payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  Future<void> deletePayment(int paymentId) async {
    final db = await _dbHelper.database;
    await db.delete('loan_payments', where: 'id = ?', whereArgs: [paymentId]);
  }

  Future<List<LoanPaymentModel>> getPaymentsForLoan(int loanId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'loan_payments',
      where: 'loanId = ?',
      whereArgs: [loanId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => LoanPaymentModel.fromMap(map)).toList();
  }
}
