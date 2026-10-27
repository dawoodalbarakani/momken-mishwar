// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'تطبيق السائق - مشوار اليمن';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get register => 'تسجيل سائق جديد';

  @override
  String get phoneLabel => 'رقم الهاتف';

  @override
  String get phoneHint => '771234567';

  @override
  String get requestOtp => 'طلب رمز التحقق';

  @override
  String get otpTitle => 'التحقق من الرمز';

  @override
  String otpInstruction(String phone) {
    return 'أدخل الرمز المكون من 6 أرقام المرسل إلى $phone';
  }

  @override
  String get verify => 'تحقق';

  @override
  String get resend => 'إعادة الإرسال';

  @override
  String resendingIn(int seconds) {
    return 'إعادة الإرسال بعد $seconds ثانية';
  }

  @override
  String get home => 'الرئيسية';

  @override
  String get offers => 'العروض';

  @override
  String get earnings => 'الأرباح';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get availability => 'حالة التوفر';

  @override
  String get online => 'متصل (أونلاين)';

  @override
  String get offline => 'غير متصل (أوفلاين)';

  @override
  String get goOnline => 'الاتصال بالعمل';

  @override
  String get goOffline => 'الانقطاع عن العمل';

  @override
  String get availableRides => 'الرحلات المتاحة';

  @override
  String get noAvailableRides => 'لا توجد رحلات متاحة حالياً';

  @override
  String get accept => 'قبول';

  @override
  String get reject => 'رفض';

  @override
  String get fare => 'الأجرة';

  @override
  String get distance => 'المسافة';

  @override
  String get pickup => 'نقطة الالتقاط';

  @override
  String get destination => 'الوجهة';

  @override
  String expiresIn(int minutes) {
    return 'تنتهي بعد $minutes دقيقة';
  }

  @override
  String get activeRide => 'لديك رحلة نشطة';

  @override
  String get noNewOffers => 'لا يمكن قبول عروض جديدة حتى تنتهي الرحلة الحالية';

  @override
  String get rideTracking => 'تتبع الرحلة';

  @override
  String rideNumber(String rideId) {
    return 'الرحلة $rideId';
  }

  @override
  String get status => 'الحالة';

  @override
  String get assigned => 'مسندة';

  @override
  String get arriving => 'قادم';

  @override
  String get arrived => 'وصل';

  @override
  String get inProgress => 'جارية';

  @override
  String get completed => 'مكتملة';

  @override
  String get cancelled => 'ملغاة';

  @override
  String get verifyAssignment => 'تحقق من إسناد الرحلة';

  @override
  String get startCodeLabel => 'رمز بدء الرحلة';

  @override
  String get startRide => 'بدء الرحلة';

  @override
  String get completeRide => 'إنهاء الرحلة';

  @override
  String get cancelRide => 'إلغاء الرحلة';

  @override
  String get cancelReason => 'سبب الإلغاء';

  @override
  String get confirmCancel => 'تأكيد الإلغاء';

  @override
  String get documents => 'المستندات والاعتماد';

  @override
  String get nationalId => 'البطاقة الشخصية';

  @override
  String get license => 'رخصة القيادة';

  @override
  String get vehicleRegistration => 'تسجيل المركبة';

  @override
  String get plate => 'صورة اللوحة';

  @override
  String get insurance => 'التأمين';

  @override
  String get verificationPending => 'قيد المراجعة';

  @override
  String get verificationApproved => 'معتمد';

  @override
  String get verificationRejected => 'مرفوض';

  @override
  String get verificationSuspended => 'موقوف';

  @override
  String get submitDocuments => 'إرسال للمراجعة';

  @override
  String get noInternet => 'لا يوجد اتصال بالإنترنت';

  @override
  String get errorGeneric => 'حدث خطأ';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get totalFare => 'إجمالي الأجرة';

  @override
  String get platformCommission => 'عمولة المنصة';

  @override
  String get netPayable => 'صافي مستحقات السائق';

  @override
  String get cashCollected => 'النقد المحصل';

  @override
  String get platformReceivables => 'مستحقات المنصة';

  @override
  String get completedRides => 'الرحلات المكتملة';

  @override
  String get payoutRequest => 'طلب تسوية / نزاع مالي';

  @override
  String get amount => 'المبلغ المطلوب';

  @override
  String get sendPayoutRequest => 'إرسال الطلب';

  @override
  String get dataAge => 'عمر البيانات: ';

  @override
  String get live => 'مباشر';

  @override
  String get stale => 'قديم/غير موثوق';

  @override
  String get appName => 'مشوار اليمن';

  @override
  String get loginSubtitle => 'أدخل رقم هاتفك اليمني لطلب رمز التحقق.';

  @override
  String invalidYemeniPhone(String example) {
    return 'أدخل رقم هاتف يمني صحيح (مثال: $example)';
  }

  @override
  String get requestOtpFailed => 'فشل طلب الرمز';

  @override
  String get createDriverAccount => 'إنشاء حساب سائق جديد';

  @override
  String get demoModeFilled =>
      'وضع العرض التجريبي: رقم الهاتف ورمز التحقق معبّآن تلقائياً';

  @override
  String get payoutInvalidAmount => 'أدخل مبلغاً صحيحاً';

  @override
  String get payoutRequestFailed => 'فشل الإرسال';

  @override
  String get payoutRequestSent => 'تم إرسال طلب التسوية للمراجعة';

  @override
  String get filePickerStubNotice =>
      'يتم فتح منتقي الملفات (يحتاج حزمة file_picker)';

  @override
  String get otpIncomplete => 'أدخل الرمز الكامل من 6 أرقام';

  @override
  String get otpInvalid => 'رمز التحقق غير صحيح';

  @override
  String get otpResent => 'أُعيد إرسال الرمز';

  @override
  String get otpResendFailed => 'فشل إعادة الإرسال';

  @override
  String get completeRequiredFields => 'أكمل جميع الحقول المطلوبة';

  @override
  String get registerFailed => 'فشل التسجيل';

  @override
  String get offerAcceptFailed => 'فشل القبول';

  @override
  String get offerAcceptedNotice => 'تم قبول الطلب وتوجيهك للرحلة';

  @override
  String get assignmentVerifyFailed => 'فشل التحقق من الإسناد';

  @override
  String get assignmentVerifiedNotice => 'تم التحقق من إسناد الرحلة';

  @override
  String get rideStartedNotice => 'بدأت الرحلة';

  @override
  String get rideCompleteFailed => 'فشل إنهاء الرحلة';

  @override
  String get rideCompletedNotice => 'تم إنهاء الرحلة';
}
