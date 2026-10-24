
import 'auth_user.dart';

enum DocumentType { nationalId, license, vehicleRegistration, plate, insurance }

class DriverDocument {
  const DriverDocument({
    required this.type,
    required this.status,
    this.uploadUrl,
    this.filePath,
    this.uploadedAt,
    this.rejectionReason,
  });

  final DocumentType type;
  final VerificationStatus status;
  final String? uploadUrl;
  final String? filePath;
  final DateTime? uploadedAt;
  final String? rejectionReason;

  DriverDocument copyWith({
    DocumentType? type,
    VerificationStatus? status,
    String? uploadUrl,
    String? filePath,
    DateTime? uploadedAt,
    String? rejectionReason,
    bool clearUploadedAt = false,
  }) {
    return DriverDocument(
      type: type ?? this.type,
      status: status ?? this.status,
      uploadUrl: uploadUrl ?? this.uploadUrl,
      filePath: filePath ?? this.filePath,
      uploadedAt: clearUploadedAt ? null : (uploadedAt ?? this.uploadedAt),
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}

class DocumentsState {
  const DocumentsState({
    this.documents = const {},
    this.isLoading = false,
    this.error,
    this.submitting = false,
  });

  final Map<DocumentType, DriverDocument> documents;
  final bool isLoading;
  final String? error;
  final bool submitting;

  VerificationStatus? overallStatus() {
    final statuses = documents.values.map((d) => d.status).toSet();
    if (statuses.contains(VerificationStatus.rejected)) return VerificationStatus.rejected;
    if (statuses.contains(VerificationStatus.suspended)) return VerificationStatus.suspended;
    if (statuses.contains(VerificationStatus.pending) || statuses.isEmpty) return VerificationStatus.pending;
    return VerificationStatus.approved;
  }
}
