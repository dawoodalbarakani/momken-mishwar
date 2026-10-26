
import 'package:driver_app/domain/models/auth_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/documents_repository.dart';
import '../../../../domain/models/document.dart';

class DocumentsNotifier extends Notifier<DocumentsState> {
  @override
  DocumentsState build() {
    final docs = <DocumentType, DriverDocument>{};
    for (final t in DocumentType.values) {
      docs[t] = DriverDocument(type: t, status: VerificationStatus.pending);
    }
    return DocumentsState(documents: docs);
  }

  Future<Map<String, dynamic>?> getUploadLink(DocumentType type) async {
    try {
      return await ref.read(documentsRepositoryProvider).getUploadLink(type);
    } catch (e) {
      state = state.copyWith(error: 'تعذر الحصول على رابط الرفع');
      return null;
    }
  }

  Future<bool> uploadDocument(DocumentType type, String filePath) async {
    // Do not mark a document as uploaded until bytes have actually been sent
    // to the signed URL and the upload has been confirmed by the storage service.
    state = state.copyWith(error: 'رفع الملفات غير متاح بعد؛ لم يتم رفع المستند');
    return false;
  }

  Future<bool> submitDocuments() async {
    // The submit endpoint must not be reported as successful until the uploaded
    // document references are sent to the backend and it confirms submission.
    state = state.copyWith(submitting: false, error: 'إرسال المستندات غير متاح بعد؛ لم يتم إرسال أي مستند للمراجعة');
    return false;
  }

  Future<void> refreshStatus() async {
    try {
      final user = await ref.read(authRepositoryProvider).loadMe();
      final st = user?.verificationStatus ?? VerificationStatus.pending;
      final updated = <DocumentType, DriverDocument>{};
      for (final entry in state.documents.entries) {
        updated[entry.key] = entry.value.copyWith(status: st);
      }
      state = state.copyWith(documents: updated, clearError: true);
    } catch (e) {
      state = state.copyWith(error: 'تعذر تحديث حالة الاعتماد');
    }
  }

  void setError(String? error) {
    state = error == null
        ? state.copyWith(clearError: true)
        : state.copyWith(error: error);
  }
}

final documentsViewModelProvider =
    NotifierProvider<DocumentsNotifier, DocumentsState>(DocumentsNotifier.new);
