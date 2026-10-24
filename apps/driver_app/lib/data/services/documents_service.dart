
import '../../domain/models/document.dart';
import 'dio_client.dart';

class DocumentsService {
  DocumentsService(this._client);

  final DioClient _client;

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

  Future<Map<String, dynamic>> getUploadLink(DocumentType type) async =>
      await _client.post<Map<String, dynamic>>(
        '/documents/upload-link',
        data: {'document_type': _typeName(type)},
      );

  Future<Map<String, dynamic>> submitDocuments(Map<String, dynamic> payload) async =>
      await _client.post<Map<String, dynamic>>('/documents/submit', data: payload);
}
