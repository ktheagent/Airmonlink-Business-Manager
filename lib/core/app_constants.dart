class AppConstants {
  static const appName = 'Airmonlink Business Manager';
  static const version = '1.0.0+2';
  static const defaultCurrency = 'GHS';
  static const databaseName = 'airmonlink_business_manager.db';

  static const purchaseUrl = 'https://buy.airmonlink.com';
  static const licensingApiUrl = 'https://license.airmonlink.com';
  static const supportUrl = 'https://airmonlink.com/support';
  static const trialDays = 14;

  // Insert the Base64-encoded 32-byte Ed25519 public key
  // from the private Airmonlink licensing server before production.
  static const licensePublicKeyBase64 = '';

  AppConstants._();
}
