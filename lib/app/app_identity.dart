/// Product identity and optional endpoints owned by this fork.
abstract final class AppIdentity {
  static const name = 'Zeitlind';
  static const version = '2.0.0';
  static const repository = String.fromEnvironment('ZEITLIND_REPOSITORY');
  static const updateManifest = String.fromEnvironment(
    'ZEITLIND_UPDATE_MANIFEST',
  );
  static const releases = String.fromEnvironment('ZEITLIND_RELEASES');
}
