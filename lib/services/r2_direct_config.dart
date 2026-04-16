class DirectR2Config {
  const DirectR2Config({
    this.accountId = const String.fromEnvironment(
      'R2_ACCOUNT_ID',
      defaultValue: 'e3ce05fad13962aba36a55373c1ec2e4',
    ),
    this.accessKeyId = const String.fromEnvironment(
      'R2_ACCESS_KEY_ID',
      defaultValue: 'fb850eb40b0a39263367cf24481b6da1',
    ),
    this.secretAccessKey = const String.fromEnvironment(
      'R2_SECRET_ACCESS_KEY',
      defaultValue: '44261c78a24295389aad601dcb1ae0322da3ac1c099ed381a6dbfd3784bb5a47',
    ),
    this.bucket = const String.fromEnvironment(
      'R2_BUCKET_NAME',
      defaultValue: 'dispatch-documents',
    ),
  });

  final String accountId;
  final String accessKeyId;
  final String secretAccessKey;
  final String bucket;

  String get endpointHost => '$accountId.r2.cloudflarestorage.com';

  bool get isConfigured =>
      accountId.trim().isNotEmpty &&
      accessKeyId.trim().isNotEmpty &&
      secretAccessKey.trim().isNotEmpty &&
      bucket.trim().isNotEmpty;
}
