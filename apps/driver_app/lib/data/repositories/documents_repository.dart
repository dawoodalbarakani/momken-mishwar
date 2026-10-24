
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/document.dart';
import '../services/documents_service.dart' show DocumentsService;
import '../services/dio_client.dart';

class DocumentsRepository {
  DocumentsRepository({required DocumentsService documentsService}) : _documentsService = documentsService;

  final DocumentsService _documentsService;

  Future<Map<String, dynamic>> getUploadLink(DocumentType type) async =>
      await _documentsService.getUploadLink(type);

  Future<bool> submitDocuments() async {
    try {
      return true;
    } catch (_) {
      return false;
    }
  }
}

final documentsRepositoryProvider = Provider(
  (ref) => DocumentsRepository(documentsService: DocumentsService(ref.read(dioClientProvider))),
);
