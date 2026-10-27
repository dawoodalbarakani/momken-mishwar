
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/models/auth_user.dart';
import '../../../../domain/models/document.dart';
import '../../../core/app_theme.dart';
import '../../../core/responsive.dart';
import '../../../core/uber_components.dart';
import '../view_models/documents_view_model.dart';
import '../../../../l10n/app_localizations.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(documentsViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.documents)),
      body: Padding(
        padding: context.responsivePadding,
        child: ContentMaxWidth(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'حالة الاعتماد',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: UberColors.bodyGray),
              ),
              const SizedBox(height: UberSpacing.xs),
              Text(
                _label(vm.overallStatus),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.15, color: UberColors.black),
              ),
              const SizedBox(height: UberSpacing.sm),
              Text(
                'ارفع كل مستند مطلوب ثم أرسل الطلب للمراجعة. لن تستقبل رحلات قبل الاعتماد.',
                style: UberTypography.caption,
              ),
              const SizedBox(height: UberSpacing.xl),
              Expanded(
                child: ListView.separated(
                  itemCount: DocumentType.values.length,
                  separatorBuilder: (_, __) => const SizedBox(height: UberSpacing.sm),
                  itemBuilder: (context, i) {
                    final t = DocumentType.values[i];
                    final doc = vm.documents[t]!;
                    final canUpload = doc.status == VerificationStatus.pending && doc.uploadUrl == null;
                    return UberCard(
                      padding: const EdgeInsets.symmetric(horizontal: UberSpacing.lg, vertical: UberSpacing.md),
                      child: Row(
                        children: [
                          Icon(_icon(t), size: 20, color: UberColors.black),
                          const SizedBox(width: UberSpacing.md),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _typeLabel(t),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: UberColors.black),
                                ),
                                if (doc.status == VerificationStatus.rejected) ...[
                                  const SizedBox(height: UberSpacing.xxs),
                                  Text(
                                    doc.rejectionReason ?? 'مرفوض — أعد الرفع',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: UberColors.danger),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: UberSpacing.sm),
                          if (canUpload)
                            TextButton(onPressed: () => _upload(context, t), child: const Text('رفع'))
                          else
                            UberStatusPill(
                              label: _statusLabel(doc.status),
                              tone: _statusTone(doc.status),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: UberSpacing.lg),
              ElevatedButton(
                onPressed: vm.submitting
                    ? null
                    : () => ref.read(documentsViewModelProvider.notifier).submitDocuments(),
                child: vm.submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: UberColors.white),
                      )
                    : const Text('إرسال للمراجعة'),
              ),
              UberErrorText(vm.error),
            ],
          ),
        ),
      ),
    );
  }

  void _upload(BuildContext context, DocumentType type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.filePickerStubNotice)),
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

  UberStatusTone _statusTone(VerificationStatus s) {
    switch (s) {
      case VerificationStatus.approved:
        return UberStatusTone.active;
      case VerificationStatus.rejected:
        return UberStatusTone.danger;
      case VerificationStatus.pending:
      case VerificationStatus.suspended:
        return UberStatusTone.neutral;
    }
  }

  IconData _icon(DocumentType t) {
    switch (t) {
      case DocumentType.nationalId:
        return Icons.badge_outlined;
      case DocumentType.license:
        return Icons.drive_eta_outlined;
      case DocumentType.vehicleRegistration:
        return Icons.description_outlined;
      case DocumentType.plate:
        return Icons.pin_outlined;
      case DocumentType.insurance:
        return Icons.shield_outlined;
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
