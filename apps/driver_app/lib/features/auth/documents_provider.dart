library driver_app.features.auth.documents_provider;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/secure_storage.dart';

enum DocumentType { nationalId, license, vehicleRegistration, plate, insurance }

enum VerificationStatus { pending, approved, rejected, suspended }

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
  const DocumentsState({this.documents = const {}, this.isLoading = false, this.error, this.submitting = false});
  final Map<DocumentType, DriverDocument> documents;
  final bool isLoading;
  final String? error;
  final bool submitting;

  DocumentsState copyWith({Map<DocumentType, DriverDocument>? documents, bool? isLoading, String? error, bool? submitting}) {
    return DocumentsState(
      documents: documents ?? this.documents,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      submitting: submitting ?? this.submitting,
    );
  }

  VerificationStatus? overallStatus() {
    final statuses = documents.values.map((d) => d.status).toSet();
    if (statuses.contains(VerificationStatus.rejected)) return VerificationStatus.rejected;
    if (statuses.contains(VerificationStatus.suspended)) return VerificationStatus.suspended;
    if (statuses.contains(VerificationStatus.pending) || statuses.isEmpty) return VerificationStatus.pending;
    return VerificationStatus.approved;
  }
}

class DocumentsNotifier extends StateNotifier<DocumentsState> {
  DocumentsNotifier(this._client) : super(const DocumentsState()) {
    _initDefault();
  }

  final DioClient _client;

  void _initDefault() {
    final docs = <DocumentType, DriverDocument>{};
    for (final t in DocumentType.values) {
      docs[t] = DriverDocument(type: t, status: VerificationStatus.pending);
    }
    state = state.copyWith(documents: docs);
  }

  Future<Map<String, dynamic>?> getUploadLink(DocumentType type) async {
    try {
      final data = await _client.post<Map<String, dynamic>>('/documents/upload-link', data: {'document_type': _typeName(type)});
      return data;
    } catch (e) {
      state = state.copyWith(error: 'تعذر الحصول على رابط الرفع');
      return null;
    }
  }

  Future<bool> uploadDocument(DocumentType type, String filePath) async {
    final current = state.documents[type];
    if (current == null) return false;
    state = state.copyWith(documents: {...state.documents, type: current.copyWith(filePath: filePath, status: VerificationStatus.pending)});
    final link = await getUploadLink(type);
    if (link == null) return false;
    final url = link['url']?.toString();
    if (url == null || url.isEmpty) {
      state = state.copyWith(error: 'رابط رفع غير صالح');
      return false;
    }
    state = state.copyWith(documents: {...state.documents, type: current.copyWith(uploadUrl: url, filePath: null, status: VerificationStatus.pending)});
    try {
      await _client.put(url, data: {'file': filePath});
      final updated = DriverDocument(type: type, status: VerificationStatus.pending, uploadUrl: url, uploadedAt: DateTime.now());
      state = state.copyWith(documents: {...state.documents, type: updated});
      return true;
    } catch (e) {
      state = state.copyWith(error: 'فشل رفع المستند');
      return false;
    }
  }

  Future<bool> submitDocuments() async {
    state = state.copyWith(submitting: true, error: null);
    try {
      final payload = <String, dynamic>{};
      for (final entry in state.documents.entries) {
        payload[_typeName(entry.key)] = entry.value.uploadedAt != null;
      }
      await _client.post('/documents/submit', data: payload);
      state = state.copyWith(submitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(submitting: false, error: 'فشل إرسال المستندات للمراجعة');
      return false;
    }
  }

  Future<void> refreshStatus() async {
    try {
      final data = await _client.get<Map<String, dynamic>>('/drivers/me');
      final st = _parseStatus(data?['verification_status']);
      final updated = <DocumentType, DriverDocument>{};
      for (final entry in state.documents.entries) {
        updated[entry.key] = entry.value.copyWith(status: st);
      }
      state = state.copyWith(documents: updated, error: null);
    } catch (e) {
      state = state.copyWith(error: 'تعذر تحديث حالة الاعتماد');
    }
  }

  VerificationStatus _parseStatus(dynamic v) {
    switch (v?.toString().toLowerCase()) {
      case 'approved':
        return VerificationStatus.approved;
      case 'rejected':
        return VerificationStatus.rejected;
      case 'suspended':
        return VerificationStatus.suspended;
      default:
        return VerificationStatus.pending;
    }
  }

  String _typeName(DocumentType t) {
    switch (t) {
      case DocumentType.nationalId:
        return 'national_id';
      case DocumentType.license:
        return 'license';
      case DocumentType.vehicleRegistration:
        return 'vehicle_registration';
      case DocumentType.plate:
        return 'plate';
      case DocumentType.insurance:
        return 'insurance';
    }
  }
}

final documentsProvider = StateNotifierProvider<DocumentsNotifier, DocumentsState>((ref) {
  return DocumentsNotifier(DioClient(SecureStorage.instance));
});
