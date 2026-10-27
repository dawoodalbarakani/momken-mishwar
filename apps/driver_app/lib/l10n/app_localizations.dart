import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق السائق - مشوار اليمن'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get login;

  /// No description provided for @register.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل سائق جديد'**
  String get register;

  /// No description provided for @phoneLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phoneLabel;

  /// No description provided for @phoneHint.
  ///
  /// In ar, this message translates to:
  /// **'771234567'**
  String get phoneHint;

  /// No description provided for @requestOtp.
  ///
  /// In ar, this message translates to:
  /// **'طلب رمز التحقق'**
  String get requestOtp;

  /// No description provided for @otpTitle.
  ///
  /// In ar, this message translates to:
  /// **'التحقق من الرمز'**
  String get otpTitle;

  /// OTP prompt naming the phone number the code was sent to
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز المكون من 6 أرقام المرسل إلى {phone}'**
  String otpInstruction(String phone);

  /// No description provided for @verify.
  ///
  /// In ar, this message translates to:
  /// **'تحقق'**
  String get verify;

  /// No description provided for @resend.
  ///
  /// In ar, this message translates to:
  /// **'إعادة الإرسال'**
  String get resend;

  /// Resend cooldown countdown, in seconds
  ///
  /// In ar, this message translates to:
  /// **'إعادة الإرسال بعد {seconds} ثانية'**
  String resendingIn(int seconds);

  /// No description provided for @home.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get home;

  /// No description provided for @offers.
  ///
  /// In ar, this message translates to:
  /// **'العروض'**
  String get offers;

  /// No description provided for @earnings.
  ///
  /// In ar, this message translates to:
  /// **'الأرباح'**
  String get earnings;

  /// No description provided for @profile.
  ///
  /// In ar, this message translates to:
  /// **'الملف الشخصي'**
  String get profile;

  /// No description provided for @availability.
  ///
  /// In ar, this message translates to:
  /// **'حالة التوفر'**
  String get availability;

  /// No description provided for @online.
  ///
  /// In ar, this message translates to:
  /// **'متصل (أونلاين)'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In ar, this message translates to:
  /// **'غير متصل (أوفلاين)'**
  String get offline;

  /// No description provided for @goOnline.
  ///
  /// In ar, this message translates to:
  /// **'الاتصال بالعمل'**
  String get goOnline;

  /// No description provided for @goOffline.
  ///
  /// In ar, this message translates to:
  /// **'الانقطاع عن العمل'**
  String get goOffline;

  /// No description provided for @availableRides.
  ///
  /// In ar, this message translates to:
  /// **'الرحلات المتاحة'**
  String get availableRides;

  /// No description provided for @noAvailableRides.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رحلات متاحة حالياً'**
  String get noAvailableRides;

  /// No description provided for @accept.
  ///
  /// In ar, this message translates to:
  /// **'قبول'**
  String get accept;

  /// No description provided for @reject.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get reject;

  /// No description provided for @fare.
  ///
  /// In ar, this message translates to:
  /// **'الأجرة'**
  String get fare;

  /// No description provided for @distance.
  ///
  /// In ar, this message translates to:
  /// **'المسافة'**
  String get distance;

  /// No description provided for @pickup.
  ///
  /// In ar, this message translates to:
  /// **'نقطة الالتقاط'**
  String get pickup;

  /// No description provided for @destination.
  ///
  /// In ar, this message translates to:
  /// **'الوجهة'**
  String get destination;

  /// Offer expiry countdown, in whole minutes
  ///
  /// In ar, this message translates to:
  /// **'تنتهي بعد {minutes} دقيقة'**
  String expiresIn(int minutes);

  /// No description provided for @activeRide.
  ///
  /// In ar, this message translates to:
  /// **'لديك رحلة نشطة'**
  String get activeRide;

  /// No description provided for @noNewOffers.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن قبول عروض جديدة حتى تنتهي الرحلة الحالية'**
  String get noNewOffers;

  /// No description provided for @rideTracking.
  ///
  /// In ar, this message translates to:
  /// **'تتبع الرحلة'**
  String get rideTracking;

  /// Header title identifying the specific ride being tracked
  ///
  /// In ar, this message translates to:
  /// **'الرحلة {rideId}'**
  String rideNumber(String rideId);

  /// No description provided for @status.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get status;

  /// No description provided for @assigned.
  ///
  /// In ar, this message translates to:
  /// **'مسندة'**
  String get assigned;

  /// No description provided for @arriving.
  ///
  /// In ar, this message translates to:
  /// **'قادم'**
  String get arriving;

  /// No description provided for @arrived.
  ///
  /// In ar, this message translates to:
  /// **'وصل'**
  String get arrived;

  /// No description provided for @inProgress.
  ///
  /// In ar, this message translates to:
  /// **'جارية'**
  String get inProgress;

  /// No description provided for @completed.
  ///
  /// In ar, this message translates to:
  /// **'مكتملة'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغاة'**
  String get cancelled;

  /// No description provided for @verifyAssignment.
  ///
  /// In ar, this message translates to:
  /// **'تحقق من إسناد الرحلة'**
  String get verifyAssignment;

  /// No description provided for @startCodeLabel.
  ///
  /// In ar, this message translates to:
  /// **'رمز بدء الرحلة'**
  String get startCodeLabel;

  /// No description provided for @startRide.
  ///
  /// In ar, this message translates to:
  /// **'بدء الرحلة'**
  String get startRide;

  /// No description provided for @completeRide.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء الرحلة'**
  String get completeRide;

  /// No description provided for @cancelRide.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الرحلة'**
  String get cancelRide;

  /// No description provided for @cancelReason.
  ///
  /// In ar, this message translates to:
  /// **'سبب الإلغاء'**
  String get cancelReason;

  /// No description provided for @confirmCancel.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الإلغاء'**
  String get confirmCancel;

  /// No description provided for @documents.
  ///
  /// In ar, this message translates to:
  /// **'المستندات والاعتماد'**
  String get documents;

  /// No description provided for @nationalId.
  ///
  /// In ar, this message translates to:
  /// **'البطاقة الشخصية'**
  String get nationalId;

  /// No description provided for @license.
  ///
  /// In ar, this message translates to:
  /// **'رخصة القيادة'**
  String get license;

  /// No description provided for @vehicleRegistration.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل المركبة'**
  String get vehicleRegistration;

  /// No description provided for @plate.
  ///
  /// In ar, this message translates to:
  /// **'صورة اللوحة'**
  String get plate;

  /// No description provided for @insurance.
  ///
  /// In ar, this message translates to:
  /// **'التأمين'**
  String get insurance;

  /// No description provided for @verificationPending.
  ///
  /// In ar, this message translates to:
  /// **'قيد المراجعة'**
  String get verificationPending;

  /// No description provided for @verificationApproved.
  ///
  /// In ar, this message translates to:
  /// **'معتمد'**
  String get verificationApproved;

  /// No description provided for @verificationRejected.
  ///
  /// In ar, this message translates to:
  /// **'مرفوض'**
  String get verificationRejected;

  /// No description provided for @verificationSuspended.
  ///
  /// In ar, this message translates to:
  /// **'موقوف'**
  String get verificationSuspended;

  /// No description provided for @submitDocuments.
  ///
  /// In ar, this message translates to:
  /// **'إرسال للمراجعة'**
  String get submitDocuments;

  /// No description provided for @noInternet.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد اتصال بالإنترنت'**
  String get noInternet;

  /// No description provided for @errorGeneric.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ'**
  String get errorGeneric;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @totalFare.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الأجرة'**
  String get totalFare;

  /// No description provided for @platformCommission.
  ///
  /// In ar, this message translates to:
  /// **'عمولة المنصة'**
  String get platformCommission;

  /// No description provided for @netPayable.
  ///
  /// In ar, this message translates to:
  /// **'صافي مستحقات السائق'**
  String get netPayable;

  /// No description provided for @cashCollected.
  ///
  /// In ar, this message translates to:
  /// **'النقد المحصل'**
  String get cashCollected;

  /// No description provided for @platformReceivables.
  ///
  /// In ar, this message translates to:
  /// **'مستحقات المنصة'**
  String get platformReceivables;

  /// No description provided for @completedRides.
  ///
  /// In ar, this message translates to:
  /// **'الرحلات المكتملة'**
  String get completedRides;

  /// No description provided for @payoutRequest.
  ///
  /// In ar, this message translates to:
  /// **'طلب تسوية / نزاع مالي'**
  String get payoutRequest;

  /// No description provided for @amount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المطلوب'**
  String get amount;

  /// No description provided for @sendPayoutRequest.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الطلب'**
  String get sendPayoutRequest;

  /// No description provided for @dataAge.
  ///
  /// In ar, this message translates to:
  /// **'عمر البيانات: '**
  String get dataAge;

  /// No description provided for @live.
  ///
  /// In ar, this message translates to:
  /// **'مباشر'**
  String get live;

  /// No description provided for @stale.
  ///
  /// In ar, this message translates to:
  /// **'قديم/غير موثوق'**
  String get stale;

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'مشوار اليمن'**
  String get appName;

  /// No description provided for @loginSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم هاتفك اليمني لطلب رمز التحقق.'**
  String get loginSubtitle;

  /// Shown when the entered number is too short to be a Yemeni phone number
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم هاتف يمني صحيح (مثال: {example})'**
  String invalidYemeniPhone(String example);

  /// No description provided for @requestOtpFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل طلب الرمز'**
  String get requestOtpFailed;

  /// No description provided for @createDriverAccount.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب سائق جديد'**
  String get createDriverAccount;

  /// No description provided for @demoModeFilled.
  ///
  /// In ar, this message translates to:
  /// **'وضع العرض التجريبي: رقم الهاتف ورمز التحقق معبّآن تلقائياً'**
  String get demoModeFilled;

  /// No description provided for @payoutInvalidAmount.
  ///
  /// In ar, this message translates to:
  /// **'أدخل مبلغاً صحيحاً'**
  String get payoutInvalidAmount;

  /// No description provided for @payoutRequestFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل الإرسال'**
  String get payoutRequestFailed;

  /// No description provided for @payoutRequestSent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال طلب التسوية للمراجعة'**
  String get payoutRequestSent;

  /// No description provided for @filePickerStubNotice.
  ///
  /// In ar, this message translates to:
  /// **'يتم فتح منتقي الملفات (يحتاج حزمة file_picker)'**
  String get filePickerStubNotice;

  /// No description provided for @otpIncomplete.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز الكامل من 6 أرقام'**
  String get otpIncomplete;

  /// No description provided for @otpInvalid.
  ///
  /// In ar, this message translates to:
  /// **'رمز التحقق غير صحيح'**
  String get otpInvalid;

  /// No description provided for @otpResent.
  ///
  /// In ar, this message translates to:
  /// **'أُعيد إرسال الرمز'**
  String get otpResent;

  /// No description provided for @otpResendFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل إعادة الإرسال'**
  String get otpResendFailed;

  /// No description provided for @completeRequiredFields.
  ///
  /// In ar, this message translates to:
  /// **'أكمل جميع الحقول المطلوبة'**
  String get completeRequiredFields;

  /// No description provided for @registerFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل التسجيل'**
  String get registerFailed;

  /// No description provided for @offerAcceptFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل القبول'**
  String get offerAcceptFailed;

  /// No description provided for @offerAcceptedNotice.
  ///
  /// In ar, this message translates to:
  /// **'تم قبول الطلب وتوجيهك للرحلة'**
  String get offerAcceptedNotice;

  /// No description provided for @assignmentVerifyFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل التحقق من الإسناد'**
  String get assignmentVerifyFailed;

  /// No description provided for @assignmentVerifiedNotice.
  ///
  /// In ar, this message translates to:
  /// **'تم التحقق من إسناد الرحلة'**
  String get assignmentVerifiedNotice;

  /// No description provided for @rideStartedNotice.
  ///
  /// In ar, this message translates to:
  /// **'بدأت الرحلة'**
  String get rideStartedNotice;

  /// No description provided for @rideCompleteFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل إنهاء الرحلة'**
  String get rideCompleteFailed;

  /// No description provided for @rideCompletedNotice.
  ///
  /// In ar, this message translates to:
  /// **'تم إنهاء الرحلة'**
  String get rideCompletedNotice;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
