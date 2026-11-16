import 'package:flutter_test/flutter_test.dart';
import 'package:gavilan/data/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La lista de negocios de este teléfono.
void main() {
  test('el de siempre es el primero; se agregan, cambian y quitan negocios', () async {
    SharedPreferences.setMockInitialValues({});
    final reg = await ProfileRegistry.open();
    expect(reg.activeKey, ProfileRegistry.firstKey); // un teléfono de antes abre su archivo de siempre
    expect(reg.all, isEmpty);

    await reg.upsert(const DeviceProfile(key: 'gavilan', name: 'Perfumes Ana', businessId: 'b1', role: 'owner'));
    final key = reg.newKey();
    expect(key, startsWith('gavilan_'));
    await reg.upsert(DeviceProfile(key: key, name: 'Tacos El Güero', businessId: 'b2', role: 'waiter'));
    await reg.setActive(key);

    final again = await ProfileRegistry.open(); // al volver a abrir la app
    expect(again.activeKey, key);
    expect(again.all.map((p) => p.name), ['Perfumes Ana', 'Tacos El Güero']);
    expect(again.byBusiness('b2')!.role, 'waiter');

    await again.upsert(again.byBusiness('b1')!.copyWith(name: 'Perfumería Ana'));
    expect(again.all.first.name, 'Perfumería Ana');
    await again.remove('gavilan');
    expect(again.all.map((p) => p.key), [key]);
    expect(again.newKey(), isNot(key));
  });
}
