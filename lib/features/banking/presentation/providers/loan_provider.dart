import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trust_tracker_flutter/core/database/database_helper.dart';
import 'package:trust_tracker_flutter/features/banking/data/models/loan_model.dart';
import 'package:trust_tracker_flutter/features/banking/data/models/loan_payment_model.dart';
import 'package:trust_tracker_flutter/features/banking/data/repositories/loan_repository.dart';
import 'package:trust_tracker_flutter/features/transactions/data/models/transaction_model.dart';
import 'package:trust_tracker_flutter/features/transactions/data/repositories/transaction_repository.dart';
import 'package:trust_tracker_flutter/features/categories/data/repositories/category_repository.dart';
import 'package:trust_tracker_flutter/features/categories/data/models/category_model.dart';
final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  return LoanRepository(DatabaseHelper.instance);
});

final loanProvider = StateNotifierProvider<LoanNotifier, AsyncValue<List<LoanModel>>>((ref) {
  final repository = ref.watch(loanRepositoryProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  final categoryRepo = ref.watch(categoryRepositoryProvider);
  return LoanNotifier(repository, transactionRepo, categoryRepo);
});

class LoanNotifier extends StateNotifier<AsyncValue<List<LoanModel>>> {
  final LoanRepository _repository;
  final TransactionRepository _transactionRepo;
  final CategoryRepository _categoryRepo;

  LoanNotifier(this._repository, this._transactionRepo, this._categoryRepo) : super(const AsyncValue.loading()) {
    loadLoans();
  }

  Future<void> loadLoans() async {
    state = const AsyncValue.loading();
    try {
      final loans = await _repository.getAllLoans();
      state = AsyncValue.data(loans);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addLoan(LoanModel loan) async {
    await _repository.insertLoan(loan);
    await loadLoans();
  }

  Future<void> updateLoan(LoanModel loan) async {
    await _repository.updateLoan(loan);
    await loadLoans();
  }

  Future<void> deleteLoan(int id) async {
    await _repository.deleteLoan(id);
    await loadLoans();
  }

  Future<void> addPayment(LoanPaymentModel payment) async {
    await _repository.insertPayment(payment);
    
    // Auto-record expense logic
    final loans = state.value ?? [];
    try {
      final loan = loans.firstWhere((l) => l.id == payment.loanId);
      if (loan.autoRecordExpense) {
        // Find EMI Payments category
        final categories = await _categoryRepo.getAll();
        final emiCategory = categories.firstWhere(
          (c) => c.name == 'EMI Payments',
          orElse: () => CategoryModel.create(
            name: 'EMI Payments',
            type: CategoryType.expense,
            colorHex: '#EF4444',
            iconName: '💸',
            isDefault: true,
          ),
        );

        int catId = emiCategory.id ?? 0;
        if (catId == 0) {
          catId = await _categoryRepo.add(emiCategory);
        }

        final transaction = TransactionModel.create(
          amount: payment.amount,
          date: payment.date,
          type: TransactionType.expense,
          categoryId: catId,
          description: '${loan.name} EMI',
          note: payment.notes ?? 'Auto-generated from Banking Management',
        );

        await _transactionRepo.addTransaction(transaction);
      }
    } catch (e) {
      // Loan not found or error adding transaction
    }
    
    await loadLoans();
  }

  Future<void> updatePayment(LoanPaymentModel payment) async {
    await _repository.updatePayment(payment);
    await loadLoans();
  }

  Future<void> deletePayment(int paymentId) async {
    await _repository.deletePayment(paymentId);
    await loadLoans();
  }
}
