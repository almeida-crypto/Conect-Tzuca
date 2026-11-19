// En el celular la app ya funciona sin internet: no hace falta nada de esto.

bool offlineSupported() => false;
bool offlineEnabled() => false;
Future<({int saved, int failed})> enableOffline(List<String> extra) async => (saved: 0, failed: 0);
Future<void> disableOffline() async {}
bool canInstallApp() => false;
bool runningInstalled() => false;
Future<bool> installApp() async => false;
