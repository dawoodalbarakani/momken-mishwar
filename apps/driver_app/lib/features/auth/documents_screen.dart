library driver_app.features.auth.documents_screen;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_provider.dart';
import 'documents_provider.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(documentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('المستندات والاعتماد')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('حالة الاعتماد: ${_label(state.overallStatus())}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: DocumentType.values.map((t) {
                  final doc = state.documents[t];
                  return Card(
                    child: ListTile(
                      title: Text(_typeLabel(t)),
                      subtitle: Text(_statusLabel(doc.status)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (doc.status == VerificationStatus.pending && doc.uploadUrl == null)
                            TextButton(onPressed: () => _upload(ref, context, t), child: const Text('رفع')),
                          if (doc.status == VerificationStatus.rejected) Text(doc.rejectionReason ?? 'مرفوض', style: const TextStyle(color: Colors.red, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: state.submitting ? null : () => ref.read(documentsProvider.notifier).submitDocuments(),
                child: state.submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('إرسال للمراجعة'),
              ),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(state.error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }

  void _upload(WidgetRef ref, BuildContext context, DocumentType type) {
    // Placeholder: real implementation opens a file picker and uploads to the signed URL.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('يتم فتح منتقي الملفات (يحتاج حزمة file_picker)')),
    );
    ref.read(documentsProvider.notifier).uploadDocument(type, '');
  }

  String _label(VerificationStatus? s) {
    switch (s) {
      case VerificationStatus.approved:
        return 'معتمد';
      case VerificationStatus.pending:
        return 'قيد المراجعة';
      case VerificationStatus.rejected:
        return 'مرفوض';
      case VerificationStatus.suspended:
        return 'موقوف';
      default:
        return 'غير معروف';
    }
  }

  String _statusLabel(VerificationStatus s) {
    switch (s) {
      case VerificationStatus.approved:
        return 'معتمد';
      case VerificationStatus.pending:
        return 'قيد المراجعة';
      case VerificationStatus.rejected:
        return 'مرفوض';
      case VerificationStatus.suspended:
        return 'موقوف';
    }
  }

  String _typeLabel(DocumentType t) {
    switch (t) {
      case DocumentType.nationalId:
        return 'البطاقة الشخصية';
      case DocumentType.license:
        return 'رخصة القيادة';
      case DocumentType.vehicleRegistration:
        return 'تسجيل المركبة';
      case DocumentType.plate:
        return 'صورة اللوحة';
      case DocumentType.insurance:
        return 'التأمين';
    }
  }
}
