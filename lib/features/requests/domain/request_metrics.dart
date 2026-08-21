import 'package:opshub/features/requests/domain/entities/request_entity.dart';

/// The three honest counts behind the Requests strip — Pending / Approved /
/// Rejected — which double as status filters. No trend engine, no averages, no
/// "top type" (owner ruling: a Request is a simple approval, not a ticketing
/// platform). Pure over a snapshot of the role-scoped list, so it recomputes
/// instantly with the stream.
class RequestMetrics {
  final int pending;
  final int approved;
  final int rejected;
  final int total;

  const RequestMetrics({
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.total,
  });

  factory RequestMetrics.from(List<RequestEntity> requests) {
    var pending = 0, approved = 0, rejected = 0;
    for (final r in requests) {
      if (r.status.isPending) {
        pending++;
      } else if (r.status.isApproved) {
        approved++;
      } else if (r.status.isRejected) {
        rejected++;
      }
    }
    return RequestMetrics(
      pending: pending,
      approved: approved,
      rejected: rejected,
      total: requests.length,
    );
  }
}
