/// The deterministic document id for one branch's daily sales close.
String salesSubmissionId(String branchId, String businessDateKey) =>
    '${branchId}_$businessDateKey';

/// The deterministic document id for one branch accounting month.
String salesMonthId(String branchId, String monthKey) =>
    '${branchId}_$monthKey';
