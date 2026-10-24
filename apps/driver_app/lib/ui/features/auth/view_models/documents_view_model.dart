library driver_app.ui.features.auth.view_models.documents_view_model;

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

  bool _isLoading = false;
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
    final current = _documents[type];
    if (current == null) return false;
    _setDocuments({..._documents, type: current.copyWith(filePath: filePath, status: VerificationStatus.pending)});
    final link = await getUploadLink(type);
    if (link == null) return false;
    final url = link['url']?.toString();
    if (url == null || url.isEmpty) {
      _error = 'رابط رفع غير صالح';
      notifyListeners();
      return false;
    }
    _setDocuments({..._documents, type: current.copyWith(uploadUrl: url, filePath: null, status: VerificationStatus.pending)});
    try {
      // Actual file upload to signed URL would happen here (needs file_picker + http).
      final updated = DriverDocument(
        type: type,
        status: VerificationStatus.pending,
        uploadUrl: url,
        uploadedAt: DateTime.now(),
      );
      _setDocuments({..._documents, type: updated});
      return true;
    } catch (e) {
      _error = 'فشل رفع المستند';
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitDocuments() async {
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      // TODO: call repository submit with collected payload
      _submitting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _submitting = false;
      _error = 'فشل إرسال المستندات للمراجعة';
      notifyListeners();
      return false;
    }
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
