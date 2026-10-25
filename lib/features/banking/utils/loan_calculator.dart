import 'package:trust_tracker_flutter/features/banking/data/models/loan_model.dart';

class LoanCalculator {
  static LoanAmortizationSummary calculateSummary(LoanModel loan) {
    double totalPaid = 0;
    int completedEmis = 0;
    int delayedCount = 0;
    int missedCount = 0;

    if (loan.payments != null) {
      for (var p in loan.payments!) {
        totalPaid += p.amount;
        if (p.status == 'delayed') delayedCount++;
        if (p.status == 'skipped' || p.status == 'missed') missedCount++;
      }
      completedEmis = loan.payments!.length;
    }

    double emi = loan.emiAmount;
    double principal = loan.amount;
    double r = loan.interestRate / 12 / 100;
    int n = loan.tenureMonths;

    double totalPayable = emi * n;
    
    // Safety check for 0% interest
    if (r == 0) {
      double principalPaid = (principal / n) * completedEmis;
      if (principalPaid > principal) principalPaid = principal;
      return LoanAmortizationSummary(
        totalPayable: totalPayable,
        totalPaid: totalPaid,
        remainingAmount: totalPayable - totalPaid,
        principalPaid: principalPaid,
        remainingPrincipal: principal - principalPaid,
        interestPaid: 0,
        interestRemaining: 0,
        completedEmis: completedEmis,
        remainingEmis: n - completedEmis > 0 ? n - completedEmis : 0,
        delayedPayments: delayedCount,
        missedPayments: missedCount,
      );
    }

    double remainingPrincipal = principal;
    double interestPaid = 0;
    double principalPaid = 0;

    for (int i = 0; i < completedEmis; i++) {
      double interestForMonth = remainingPrincipal * r;
      double principalForMonth = emi - interestForMonth;
      
      // Handle last EMI edge case
      if (principalForMonth > remainingPrincipal) {
        principalForMonth = remainingPrincipal;
      }
      
      interestPaid += interestForMonth;
      principalPaid += principalForMonth;
      remainingPrincipal -= principalForMonth;
      if (remainingPrincipal < 0) remainingPrincipal = 0;
    }

    double totalInterest = totalPayable - principal;
    double interestRemaining = totalInterest - interestPaid;
    if (interestRemaining < 0) interestRemaining = 0;

    return LoanAmortizationSummary(
      totalPayable: totalPayable,
      totalPaid: totalPaid,
      remainingAmount: (totalPayable - totalPaid) > 0 ? (totalPayable - totalPaid) : 0,
      principalPaid: principalPaid,
      remainingPrincipal: remainingPrincipal,
      interestPaid: interestPaid,
      interestRemaining: interestRemaining,
      completedEmis: completedEmis,
      remainingEmis: n - completedEmis > 0 ? n - completedEmis : 0,
      delayedPayments: delayedCount,
      missedPayments: missedCount,
    );
  }

  static int calculateHealthScore(LoanAmortizationSummary summary) {
    int score = 100;
    score -= (summary.delayedPayments * 5);
    score -= (summary.missedPayments * 15);
    if (score < 0) score = 0;
    return score;
  }
}

class LoanAmortizationSummary {
  final double totalPayable;
  final double totalPaid;
  final double remainingAmount;
  final double principalPaid;
  final double remainingPrincipal;
  final double interestPaid;
  final double interestRemaining;
  final int completedEmis;
  final int remainingEmis;
  final int delayedPayments;
  final int missedPayments;

  LoanAmortizationSummary({
    required this.totalPayable,
    required this.totalPaid,
    required this.remainingAmount,
    required this.principalPaid,
    required this.remainingPrincipal,
    required this.interestPaid,
    required this.interestRemaining,
    required this.completedEmis,
    required this.remainingEmis,
    required this.delayedPayments,
    required this.missedPayments,
  });
}
