
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/models/auth_user.dart';
import '../../../../domain/models/document.dart';
import '../view_models/documents_view_model.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(documentsViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('المستندات والاعتماد')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('حالة الاعتماد: ${_label(vm.overallStatus)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: DocumentType.values.map((t) {
                  final doc = vm.documents[t]!;
                  return Card(
                    child: ListTile(
                      title: Text(_typeLabel(t)),
                      subtitle: Text(_statusLabel(doc.status)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (doc.status == VerificationStatus.pending && doc.uploadUrl == null)
                            TextButton(onPressed: () => _upload(context, t), child: const Text('رفع')),
                          if (doc.status == VerificationStatus.rejected)
                            Text(doc.rejectionReason ?? 'مرفوض', style: const TextStyle(color: Colors.red, fontSize: 12)),
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
                onPressed: vm.submitting
                    ? null
                    : () => ref.read(documentsViewModelProvider.notifier).submitDocuments(),
                child: vm.submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('إرسال للمراجعة'),
              ),
            ),
            if (vm.error != null) ...[
              const SizedBox(height: 8),
              Text(vm.error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }

  void _upload(BuildContext context, DocumentType type) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('يتم فتح منتقي الملفات (يحتاج حزمة file_picker)')),
    );
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
