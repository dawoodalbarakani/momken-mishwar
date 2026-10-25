
import 'package:driver_app/domain/models/auth_user.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/documents_repository.dart';
import '../../../../domain/models/document.dart';

class DocumentsViewModel extends ChangeNotifier {
  DocumentsViewModel({
    required DocumentsRepository documentsRepository,
    required AuthRepository authRepository,
  })  : _documentsRepository = documentsRepository,
        _authRepository = authRepository {
    _initDefaults();
  }

  final DocumentsRepository _documentsRepository;
  final AuthRepository _authRepository;

  Map<DocumentType, DriverDocument> _documents = const {};
  Map<DocumentType, DriverDocument> get documents => _documents;

  final bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _submitting = false;
  bool get submitting => _submitting;

  String? _error;
  String? get error => _error;

  VerificationStatus? get overallStatus {
    final statuses = _documents.values.map((d) => d.status).toSet();
    if (statuses.contains(VerificationStatus.rejected)) return VerificationStatus.rejected;
    if (statuses.contains(VerificationStatus.suspended)) return VerificationStatus.suspended;
    if (statuses.contains(VerificationStatus.pending) || statuses.isEmpty) return VerificationStatus.pending;
    return VerificationStatus.approved;
  }

  void _initDefaults() {
    final docs = <DocumentType, DriverDocument>{};
    for (final t in DocumentType.values) {
      docs[t] = DriverDocument(type: t, status: VerificationStatus.pending);
    }
    _documents = docs;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getUploadLink(DocumentType type) async {
    try {
      return await _documentsRepository.getUploadLink(type);
    } catch (e) {
      _error = 'تعذر الحصول على رابط الرفع';
      notifyListeners();
      return null;
    }
  }

  Future<bool> uploadDocument(DocumentType type, String filePath) async {
    // Do not mark a document as uploaded until bytes have actually been sent
    // to the signed URL and the upload has been confirmed by the storage service.
    _error = 'رفع الملفات غير متاح بعد؛ لم يتم رفع المستند';
    notifyListeners();
    return false;
  }

  Future<bool> submitDocuments() async {
    // The submit endpoint must not be reported as successful until the uploaded
    // document references are sent to the backend and it confirms submission.
    _submitting = false;
    _error = 'إرسال المستندات غير متاح بعد؛ لم يتم إرسال أي مستند للمراجعة';
    notifyListeners();
    return false;
  }

  Future<void> refreshStatus() async {
    try {
      final user = await _authRepository.loadMe();
      final st = user?.verificationStatus ?? VerificationStatus.pending;
      final updated = <DocumentType, DriverDocument>{};
      for (final entry in _documents.entries) {
        updated[entry.key] = entry.value.copyWith(status: st);
      }
      _setDocuments(updated, error: null);
    } catch (e) {
      _error = 'تعذر تحديث حالة الاعتماد';
      notifyListeners();
    }
  }

  void _setDocuments(Map<DocumentType, DriverDocument> docs, {String? error}) {
    _documents = docs;
    if (error != null) _error = error;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }
}

final documentsViewModelProvider = ChangeNotifierProvider(
  (ref) => DocumentsViewModel(
    documentsRepository: ref.read(documentsRepositoryProvider),
    authRepository: ref.read(authRepositoryProvider),
  ),
);
