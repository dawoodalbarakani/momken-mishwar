// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Driver App - Mishwar Yemen';

  @override
  String get login => 'Log in';

  @override
  String get register => 'Register as driver';

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get phoneHint => '771234567';

  @override
  String get requestOtp => 'Request OTP';

  @override
  String get otpTitle => 'Verify code';

  @override
  String otpInstruction(String phone) {
    return 'Enter the 6-digit code sent to $phone';
  }

  @override
  String get verify => 'Verify';

  @override
  String get resend => 'Resend';

  @override
  String resendingIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get home => 'Home';

  @override
  String get offers => 'Offers';

  @override
  String get earnings => 'Earnings';

  @override
  String get profile => 'Profile';

  @override
  String get availability => 'Availability';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get goOnline => 'Go online';

  @override
  String get goOffline => 'Go offline';

  @override
  String get availableRides => 'Available rides';

  @override
  String get noAvailableRides => 'No available rides currently';

  @override
  String get accept => 'Accept';

  @override
  String get reject => 'Reject';

  @override
  String get fare => 'Fare';

  @override
  String get distance => 'Distance';

  @override
  String get pickup => 'Pickup';

  @override
  String get destination => 'Destination';

  @override
  String expiresIn(int minutes) {
    return 'Expires in $minutes minutes';
  }

  @override
  String get activeRide => 'You have an active ride';

  @override
  String get noNewOffers => 'No new offers until current ride ends';

  @override
  String get rideTracking => 'Ride tracking';

  @override
  String get status => 'Status';

  @override
  String get assigned => 'Assigned';

  @override
  String get arriving => 'Arriving';

  @override
  String get arrived => 'Arrived';

  @override
  String get inProgress => 'In progress';

  @override
  String get completed => 'Completed';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get verifyAssignment => 'Verify assignment';

  @override
  String get startCodeLabel => 'Start code';

  @override
  String get startRide => 'Start ride';

  @override
  String get completeRide => 'Complete ride';

  @override
  String get cancelRide => 'Cancel ride';

  @override
  String get cancelReason => 'Cancellation reason';

  @override
  String get confirmCancel => 'Confirm cancellation';

  @override
  String get documents => 'Documents and verification';

  @override
  String get nationalId => 'National ID';

  @override
  String get license => 'Driver license';

  @override
  String get vehicleRegistration => 'Vehicle registration';

  @override
  String get plate => 'Plate photo';

  @override
  String get insurance => 'Insurance';

  @override
  String get verificationPending => 'Pending';

  @override
  String get verificationApproved => 'Approved';

  @override
  String get verificationRejected => 'Rejected';

  @override
  String get verificationSuspended => 'Suspended';

  @override
  String get submitDocuments => 'Submit for review';

  @override
  String get noInternet => 'No internet connection';

  @override
  String get errorGeneric => 'An error occurred';

  @override
  String get logout => 'Log out';

  @override
  String get totalFare => 'Total fare';

  @override
  String get platformCommission => 'Platform commission';

  @override
  String get netPayable => 'Net payable to driver';

  @override
  String get cashCollected => 'Cash collected';

  @override
  String get platformReceivables => 'Platform receivables';

  @override
  String get completedRides => 'Completed rides';

  @override
  String get payoutRequest => 'Payout request / financial dispute';

  @override
  String get amount => 'Requested amount';

  @override
  String get sendPayoutRequest => 'Send request';

  @override
  String get dataAge => 'Data age: ';

  @override
  String get live => 'Live';

  @override
  String get stale => 'Stale/unreliable';

  @override
  String get appName => 'Mishwar Yemen';

  @override
  String get loginSubtitle =>
      'Enter your Yemeni phone number to request a verification code.';

  @override
  String invalidYemeniPhone(String example) {
    return 'Enter a valid Yemeni phone number (e.g. $example)';
  }

  @override
  String get requestOtpFailed => 'Failed to request the code';

  @override
  String get createDriverAccount => 'Create a new driver account';

  @override
  String get demoModeFilled =>
      'Demo mode: phone number and OTP are pre-filled automatically';
}
