import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/limits.dart';
import '../../core/money.dart';
import '../../domain/restaurant.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

/// Lista de extras con precio del restaurante ("Extra queso" +$10). El dueño los da de alta una vez y
/// el mesero los pone en cada platillo.
class ExtrasScreen extends ConsumerWidget {
  const ExtrasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = ref.watch(storeProvider.select((s) => s.activeExtras));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: GColors.fondo,
        surfaceTintColor: Colors.transparent,
        title: Text('Extras con precio', style: GText.sans(size: 17, weight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Text(
                  'Lo que el cliente pide de más y se cobra aparte: extra queso, doble carne, leche deslactosada. '
                  'El mesero los elige al anotar el platillo y se suman solos a la cuenta.',
                  style: GText.sans(size: 13.5, weight: FontWeight.w400, color: GColors.tintaSuave),
                ),
                const SizedBox(height: 14),
                if (extras.isNotEmpty)
                  GCard(
                    padding: EdgeInsets.zero,
                    // Material transparente: así el toque de cada renglón se ve encima de la tarjeta.
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        children: [
                          for (final (i, e) in extras.indexed) ...[
                            if (i > 0) const Divider(height: 1, color: GColors.linea),
                            ListTile(
                              title: Text(e.name, style: GText.sans(size: 15, weight: FontWeight.w700)),
                              subtitle: Text('+${money(e.priceCents)}', style: GText.figures(size: 13)),
                              onTap: () => showExtraSheet(context, ref, extra: e),
                              trailing: IconButton(
                                tooltip: 'Quitar extra',
                                icon: const Icon(Icons.delete_outline_rounded, color: GColors.tintaTenue),
                                onPressed: () {
                                  ref.read(storeProvider.notifier).removeExtra(e.id);
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(content: Text('Se quitó "${e.name}"')));
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (extras.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('Todavía no hay extras.', textAlign: TextAlign.center, style: GText.muted(size: 14)),
                  ),
                const SizedBox(height: 14),
                GButton(
                  label: 'Agregar extra',
                  icon: Icons.add_rounded,
                  expand: true,
                  onPressed: () => showExtraSheet(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Alta o cambio de un extra: nombre y precio.
Future<void> showExtraSheet(BuildContext context, WidgetRef ref, {Extra? extra}) =>
    showGSheet<void>(context, (_) => _ExtraForm(extra: extra));

class _ExtraForm extends ConsumerStatefulWidget {
  const _ExtraForm({this.extra});

  final Extra? extra;

  @override
  ConsumerState<_ExtraForm> createState() => _ExtraFormState();
}

class _ExtraFormState extends ConsumerState<_ExtraForm> {
  late final _name = TextEditingController(text: widget.extra?.name ?? '');
  late final _price = TextEditingController(text: centsInput(widget.extra?.priceCents));
  String? _nameError;
  String? _priceError;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final price = _price.text.trim().isEmpty ? 0 : parseMoney(_price.text);
    setState(() {
      _nameError = name.isEmpty ? 'Escribe el nombre' : null;
      _priceError = price == null ? (moneyTooBig(_price.text) ?? 'Precio no válido') : null;
    });
    if (_nameError != null || _priceError != null) return;
    ref.read(storeProvider.notifier).saveExtra(id: widget.extra?.id, name: name, priceCents: price!);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(widget.extra == null ? 'Nuevo extra' : 'Cambiar extra'),
        TextField(
          controller: _name,
          autofocus: widget.extra == null,
          inputFormatters: [maxChars(Limits.maxNameLength)],
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Nombre', hintText: 'Extra queso', errorText: _nameError),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [MoneyInputFormatter()],
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            labelText: 'Cuánto cuesta',
            helperText: 'Se suma por cada platillo que lo lleve. 0 si es gratis.',
            prefixText: '+\$ ',
            errorText: _priceError,
          ),
        ),
        const SizedBox(height: 16),
        GButton(label: 'Guardar', icon: Icons.check_rounded, expand: true, onPressed: _save),
      ],
    );
  }
}
