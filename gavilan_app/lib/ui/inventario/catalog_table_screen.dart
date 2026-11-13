import '../../core/limits.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../domain/models.dart';
import '../../domain/plan.dart';
import '../../domain/profit.dart';
import '../../state/app_state.dart';
import '../../state/store.dart';
import '../../theme/colors.dart';
import '../../theme/theme.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/product_icons.dart';

/// Columnas de la tabla, en el orden en que se ven (y en el que se pega desde Excel).
enum CatalogColumn {
  name('Producto'),
  barcode('Código de barras'),
  price('Precio de venta'),
  cost('Costo de compra'),
  stock('Existencia'),
  min('Mínimo');

  const CatalogColumn(this.label);
  final String label;

  bool get numeric => index >= CatalogColumn.price.index;
}

/// Convierte lo que se pega desde Excel (celdas separadas por tabuladores y renglones por saltos)
/// en una cuadrícula de textos.
List<List<String>> parsePastedGrid(String text) {
  final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
  return [for (final l in lines) l.split('\t').map((c) => c.trim()).toList()];
}

/// El catálogo como hoja de cálculo, para la computadora: cambiar muchos precios o existencias de una vez,
/// o dar de alta productos pegándolos desde Excel.
class CatalogTableScreen extends ConsumerStatefulWidget {
  const CatalogTableScreen({super.key});

  @override
  ConsumerState<CatalogTableScreen> createState() => _CatalogTableScreenState();
}

class _Row {
  _Row({required this.id, required this.isNew, required this.iconId, required this.tracked, required this.original})
    : controllers = {for (final c in CatalogColumn.values) c: TextEditingController(text: original[c])},
      focus = {for (final c in CatalogColumn.values) c: FocusNode()};

  factory _Row.of(Product p) => _Row(
    id: p.id,
    isNew: false,
    iconId: p.iconId,
    tracked: p.trackStock,
    original: {
      CatalogColumn.name: p.name,
      CatalogColumn.barcode: p.barcode ?? '',
      CatalogColumn.price: centsInput(p.priceCents),
      CatalogColumn.cost: centsInput(p.costCents),
      CatalogColumn.stock: p.trackStock ? qtyLabel(p.stock) : '',
      CatalogColumn.min: p.minStock == null ? '' : qtyLabel(p.minStock!),
    },
  );

  factory _Row.blank() => _Row(
    id: newId(),
    isNew: true,
    iconId: 'otro',
    tracked: false,
    original: {for (final c in CatalogColumn.values) c: ''},
  );

  final String id;
  final bool isNew;
  final String iconId;
  final bool tracked;
  final Map<CatalogColumn, String> original;
  final Map<CatalogColumn, TextEditingController> controllers;
  final Map<CatalogColumn, FocusNode> focus;

  String text(CatalogColumn c) => controllers[c]!.text.trim();
  bool changed(CatalogColumn c) => text(c) != original[c]!.trim();
  bool get blank => CatalogColumn.values.every((c) => text(c).isEmpty);
  bool get dirty => isNew ? !blank : CatalogColumn.values.any(changed);

  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    for (final f in focus.values) {
      f.dispose();
    }
  }
}

class _CatalogTableScreenState extends ConsumerState<CatalogTableScreen> {
  List<_Row> _rows = [];
  final _search = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  /// Ctrl+S guarda. Se escucha aquí y no con atajos normales porque en el navegador la celda con el cursor
  /// se queda con esa tecla.
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || !mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    final keyboard = HardwareKeyboard.instance;
    if (e.logicalKey == LogicalKeyboardKey.keyS && (keyboard.isControlPressed || keyboard.isMetaPressed)) {
      if (_dirtyCount > 0) _save();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    for (final r in _rows) {
      r.dispose();
    }
    _search.dispose();
    super.dispose();
  }

  void _load() {
    for (final r in _rows) {
      r.dispose();
    }
    final products = [...ref.read(storeProvider).activeProducts]..sort((a, b) => a.name.compareTo(b.name));
    _rows = [for (final p in products) _Row.of(p)];
  }

  List<_Row> get _visible {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return [
      for (final r in _rows)
        if (r.isNew ||
            r.text(CatalogColumn.name).toLowerCase().contains(q) ||
            r.original[CatalogColumn.name]!.toLowerCase().contains(q) ||
            r.text(CatalogColumn.barcode).contains(q))
          r,
    ];
  }

  int get _dirtyCount => _rows.where((r) => r.dirty).length;

  /// Lo que está mal en una celda, o null si está bien.
  String? _error(_Row r, CatalogColumn c, Map<String, int> codes) {
    if (r.isNew && r.blank) return null;
    final t = r.text(c);
    switch (c) {
      case CatalogColumn.name:
        if (t.length > Limits.maxNameLength) return 'Máximo ${Limits.maxNameLength} letras';
        return t.isEmpty ? 'Escribe el nombre' : null;
      case CatalogColumn.barcode:
        if (t.isEmpty) return null;
        if (t.length > Limits.maxBarcodeLength) return 'Código demasiado largo';
        if ((codes[t] ?? 0) > 1) return 'Este código está repetido';
        final other = ref.read(storeProvider).productByBarcode(t);
        if (other != null && other.id != r.id && !_rows.any((x) => x.id == other.id)) {
          return 'Ya lo usa "${other.name}"';
        }
        return null;
      case CatalogColumn.price:
        final v = parseMoney(t);
        return (v == null || v == 0) ? (moneyTooBig(t) ?? 'Escribe el precio') : null;
      case CatalogColumn.cost:
        return t.isEmpty || parseMoney(t) != null ? null : (moneyTooBig(t) ?? 'Costo no válido');
      case CatalogColumn.stock:
        if (t.isEmpty) return r.tracked ? 'Escribe la existencia' : null;
        return parseQty(t, allowNegative: true) == null ? 'Entre -99,999 y 99,999' : null;
      case CatalogColumn.min:
        if (t.isEmpty) return null;
        return parseQty(t) == null ? 'Entre 0 y 99,999' : null;
    }
  }

  Map<String, int> _codeCounts() {
    final counts = <String, int>{};
    for (final r in _rows) {
      final code = r.text(CatalogColumn.barcode);
      if (code.isNotEmpty) counts[code] = (counts[code] ?? 0) + 1;
    }
    return counts;
  }

  int _errorCount(Map<String, int> codes) {
    var n = 0;
    for (final r in _rows) {
      if (!r.dirty) continue;
      for (final c in CatalogColumn.values) {
        if (_error(r, c, codes) != null) n++;
      }
    }
    return n;
  }

  void _addRow() {
    final row = _Row.blank();
    setState(() {
      _rows.add(row);
      _q = '';
      _search.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) row.focus[CatalogColumn.name]!.requestFocus();
    });
  }

  void _removeRow(_Row r) {
    setState(() => _rows.remove(r));
    r.dispose();
  }

  /// Enter baja a la misma columna del renglón de abajo.
  void _down(_Row r, CatalogColumn c) {
    final visible = _visible;
    final i = visible.indexOf(r);
    if (i >= 0 && i + 1 < visible.length) visible[i + 1].focus[c]!.requestFocus();
  }

  /// Pega una cuadrícula copiada de Excel a partir de la celda [r]/[c]; agrega renglones si faltan.
  void _paste(_Row r, CatalogColumn c, String text) {
    final grid = parsePastedGrid(text);
    if (grid.isEmpty) return;
    var visible = _visible;
    var i = visible.indexOf(r);
    setState(() {
      for (final line in grid) {
        if (i >= visible.length) {
          _rows.add(_Row.blank());
          visible = _visible;
        }
        final target = visible[i];
        for (var k = 0; k < line.length; k++) {
          final col = c.index + k;
          if (col >= CatalogColumn.values.length) break;
          final ctrl = target.controllers[CatalogColumn.values[col]]!;
          ctrl.value = TextEditingValue(
            text: line[k],
            selection: TextSelection.collapsed(offset: line[k].length),
          );
        }
        i++;
      }
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Se pegaron ${grid.length} ${grid.length == 1 ? 'renglón' : 'renglones'}')),
      );
  }

  Future<void> _save() async {
    final codes = _codeCounts();
    if (_errorCount(codes) > 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Corrige las celdas en rojo antes de guardar')));
      return;
    }
    final store = ref.read(storeProvider);
    final notifier = ref.read(storeProvider.notifier);
    final dirty = _rows.where((r) => r.dirty).toList();
    final newRows = dirty.where((r) => r.isNew).toList();

    // Los productos nuevos respetan el límite del plan.
    final max = ref.read(planProvider).limits.maxProducts;
    if (newRows.isNotEmpty && max != null && store.activeProducts.length + newRows.length > max) {
      final plan = ref.read(planProvider);
      await showUpgradeSheet(
        context,
        reason:
            'Tu plan ${plan.label} permite hasta $max productos y con estos serían '
            '${store.activeProducts.length + newRows.length}. Quita algunos renglones nuevos o cambia de plan.',
        needed: plan == Plan.semilla ? Plan.emprendedor : Plan.negocio,
      );
      return;
    }

    for (final r in dirty) {
      final name = r.text(CatalogColumn.name);
      final price = parseMoney(r.text(CatalogColumn.price))!;
      final costText = r.text(CatalogColumn.cost);
      final cost = costText.isEmpty ? 0 : parseMoney(costText)!;
      final code = r.text(CatalogColumn.barcode);
      final stockText = r.text(CatalogColumn.stock);
      final stock = stockText.isEmpty ? null : parseQty(stockText, allowNegative: true);
      final minText = r.text(CatalogColumn.min);
      final min = minText.isEmpty ? null : parseQty(minText);

      if (r.isNew) {
        notifier.saveProduct(
          Product(
            id: r.id,
            name: name,
            priceCents: price,
            costCents: cost,
            barcode: code.isEmpty ? null : code,
            trackStock: stock != null,
            stock: stock ?? 0,
            minStock: min,
          ),
        );
        continue;
      }
      // Partimos del producto como está ahora: pudo venderse algo mientras se editaba.
      final current = ref.read(storeProvider).productById(r.id);
      if (current == null) continue;
      final fieldsChanged = [
        CatalogColumn.name,
        CatalogColumn.barcode,
        CatalogColumn.price,
        CatalogColumn.cost,
        CatalogColumn.min,
      ].any(r.changed);
      final startTracking = !current.trackStock && stock != null;
      if (fieldsChanged || startTracking) {
        notifier.saveProduct(
          current.copyWith(
            name: name,
            priceCents: price,
            costCents: cost,
            barcode: code.isEmpty ? null : code,
            clearBarcode: code.isEmpty,
            minStock: min,
            clearMinStock: min == null,
            trackStock: current.trackStock || startTracking,
          ),
        );
      }
      // La existencia que se escribe es la que hay (un conteo): se guarda como ajuste.
      if (r.changed(CatalogColumn.stock) && stock != null) {
        notifier.addStock(r.id, stock - current.stock, adjustment: true);
      }
    }

    if (!mounted) return;
    setState(_load);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Se guardaron ${dirty.length} ${dirty.length == 1 ? 'producto' : 'productos'}')),
      );
  }

  Future<bool> _confirmDiscard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: Text('Tienes $_dirtyCount ${_dirtyCount == 1 ? 'cambio' : 'cambios'} sin guardar.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Seguir editando')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Salir sin guardar',
              style: GText.sans(size: 14, weight: FontWeight.w700, color: GColors.rojo),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final codes = _codeCounts();
    final dirty = _dirtyCount;
    final errors = _errorCount(codes);
    final visible = _visible;

    return PopScope(
      canPop: dirty == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: GColors.fondo,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 4,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Editar en tabla', style: GText.sans(size: 17, weight: FontWeight.w800)),
              Text('Tab avanza · Enter baja · puedes pegar celdas desde Excel', style: GText.muted(size: 12)),
            ],
          ),
          actions: [
            if (errors > 0)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  '$errors ${errors == 1 ? 'celda por corregir' : 'celdas por corregir'}',
                  style: GText.sans(size: 13, weight: FontWeight.w700, color: GColors.rojo),
                ),
              ),
            if (dirty > 0)
              TextButton(
                onPressed: () async {
                  if (await _confirmDiscard() && mounted) setState(_load);
                },
                child: Text(
                  'Descartar',
                  style: GText.sans(size: 14, weight: FontWeight.w700, color: GColors.tintaSuave),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              child: GButton(
                label: dirty == 0 ? 'Sin cambios' : 'Guardar $dirty',
                icon: Icons.check_rounded,
                kind: GButtonKind.money,
                onPressed: dirty == 0 ? null : _save,
              ),
            ),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _q = v),
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre o código',
                      prefixIcon: Icon(Icons.search_rounded, size: 22),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: GShape.card(),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        const _HeaderRow(),
                        Expanded(
                          child: ListView.builder(
                            itemCount: visible.length + 1,
                            itemExtent: 46,
                            itemBuilder: (context, i) {
                              if (i == visible.length) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: TextButton.icon(
                                      onPressed: _addRow,
                                      icon: const Icon(Icons.add_rounded, size: 18, color: GColors.marca),
                                      label: Text(
                                        'Agregar renglón',
                                        style: GText.sans(size: 13.5, weight: FontWeight.w700, color: GColors.marca),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final r = visible[i];
                              return _TableRow(
                                key: ObjectKey(r),
                                row: r,
                                striped: i.isOdd,
                                errorOf: (c) => _error(r, c, codes),
                                onChanged: () => setState(() {}),
                                onDown: (c) => _down(r, c),
                                onPaste: (c, text) => _paste(r, c, text),
                                onRemove: r.isNew ? () => _removeRow(r) : null,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _iconWidth = 44.0;
const _removeWidth = 40.0;
const _marginWidth = 92.0;
double _colWidth(CatalogColumn c) => switch (c) {
  CatalogColumn.name => 0, // ocupa lo que sobra
  CatalogColumn.barcode => 170,
  CatalogColumn.price || CatalogColumn.cost || CatalogColumn.stock => 112,
  CatalogColumn.min => 96,
};

Widget _sized(CatalogColumn c, Widget child) =>
    c == CatalogColumn.name ? Expanded(child: child) : SizedBox(width: _colWidth(c), child: child);

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: const BoxDecoration(
        color: GColors.hundido,
        border: Border(bottom: BorderSide(color: GColors.linea)),
      ),
      child: Row(
        children: [
          const SizedBox(width: _iconWidth),
          for (final c in CatalogColumn.values)
            _sized(
              c,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  c.label.toUpperCase(),
                  maxLines: 2,
                  textAlign: c.numeric ? TextAlign.right : TextAlign.left,
                  style: GText.label().copyWith(height: 1.15),
                ),
              ),
            ),
          SizedBox(
            width: _marginWidth,
            child: Tooltip(
              message: 'De cada peso que paga el cliente, cuánto te queda',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('MARGEN', textAlign: TextAlign.right, style: GText.label()),
              ),
            ),
          ),
          const SizedBox(width: _removeWidth),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    super.key,
    required this.row,
    required this.striped,
    required this.errorOf,
    required this.onChanged,
    required this.onDown,
    required this.onPaste,
    this.onRemove,
  });

  final _Row row;
  final bool striped;
  final String? Function(CatalogColumn) errorOf;
  final VoidCallback onChanged;
  final void Function(CatalogColumn) onDown;
  final void Function(CatalogColumn, String) onPaste;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: striped ? const Color(0xFFFAF9F7) : GColors.superficie,
        border: const Border(bottom: BorderSide(color: GColors.linea)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _iconWidth,
            child: Center(
              child: row.isNew
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: GColors.marcaSuave, borderRadius: BorderRadius.circular(99)),
                      child: Text(
                        'Nuevo',
                        style: GText.sans(size: 9.5, weight: FontWeight.w800, color: GColors.marca),
                      ),
                    )
                  : ProductBadge(row.iconId, size: 28),
            ),
          ),
          for (final c in CatalogColumn.values) _sized(c, _cell(c)),
          SizedBox(width: _marginWidth, child: _margin()),
          SizedBox(
            width: _removeWidth,
            child: onRemove == null
                ? null
                : IconButton(
                    tooltip: 'Quitar renglón',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 18, color: GColors.tintaTenue),
                    onPressed: onRemove,
                  ),
          ),
        ],
      ),
    );
  }

  /// Margen calculado de lo que está escrito en precio y costo.
  Widget _margin() {
    final price = parseMoney(row.text(CatalogColumn.price));
    final cost = parseMoney(row.text(CatalogColumn.cost));
    final m = (price == null || cost == null) ? null : marginPct(priceCents: price, costCents: cost);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        m == null ? '—' : '${(m * 100).round()}%',
        textAlign: TextAlign.right,
        style: m == null
            ? GText.muted(size: 13)
            : GText.figures(size: 13.5, weight: FontWeight.w700, color: marginColor(m)),
      ),
    );
  }

  Widget _cell(CatalogColumn c) {
    final error = errorOf(c);
    final changed = row.isNew ? row.text(c).isNotEmpty : row.changed(c);
    final none = InputBorder.none;
    return Tooltip(
      message: error ?? '',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        decoration: BoxDecoration(
          color: error != null
              ? GColors.rojoSuave
              : changed
              ? GColors.izamalSuave
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: error != null ? Border.all(color: GColors.rojo) : null,
        ),
        child: TextField(
          controller: row.controllers[c],
          focusNode: row.focus[c],
          textAlign: c.numeric ? TextAlign.right : TextAlign.left,
          // Varias líneas solo para recibir los saltos de lo que se pega desde Excel; Enter nunca escribe uno.
          keyboardType: TextInputType.multiline,
          minLines: 1,
          maxLines: null,
          style: c.numeric ? GText.figures(size: 13.5) : GText.sans(size: 13.5),
          inputFormatters: [
            _PasteCatcher(onPaste: (text) => onPaste(c, text), onEnter: () => onDown(c)),
            ...switch (c) {
              CatalogColumn.name => [maxChars(Limits.maxNameLength)],
              CatalogColumn.barcode => [maxChars(Limits.maxBarcodeLength)],
              CatalogColumn.price || CatalogColumn.cost => const [MoneyInputFormatter()],
              CatalogColumn.stock => const [QtyInputFormatter(allowNegative: true)],
              CatalogColumn.min => const [QtyInputFormatter()],
            },
          ],
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            hintText: c == CatalogColumn.stock && !row.tracked ? '—' : null,
            border: none,
            enabledBorder: none,
            errorBorder: none,
            disabledBorder: none,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: GColors.cenote, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          ),
        ),
      ),
    );
  }
}

/// Si lo que entra trae tabuladores o saltos de renglón (se pegó desde Excel), no lo escribe en la celda:
/// lo reparte en la tabla. Un Enter solo baja al renglón de abajo.
class _PasteCatcher extends TextInputFormatter {
  _PasteCatcher({required this.onPaste, required this.onEnter});

  final void Function(String) onPaste;
  final VoidCallback onEnter;

  static final _breaks = RegExp(r'[\t\r\n]');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (!_breaks.hasMatch(text)) return newValue;
    final start = oldValue.selection.isValid ? oldValue.selection.start : oldValue.text.length;
    final end = newValue.selection.isValid ? newValue.selection.end : text.length;
    final inserted = (start <= end && end <= text.length) ? text.substring(start, end) : text;
    if (inserted.trim().isEmpty && inserted.contains('\n')) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onEnter());
      return oldValue;
    }
    final grid = parsePastedGrid(inserted);
    // Una sola celda (con un salto al final, como copia Excel): se escribe normal.
    if (grid.length <= 1 && (grid.isEmpty || grid.single.length == 1)) {
      final clean = text.replaceAll(_breaks, '');
      return TextEditingValue(
        text: clean,
        selection: TextSelection.collapsed(offset: clean.length),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => onPaste(inserted));
    return oldValue;
  }
}
