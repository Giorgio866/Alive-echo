import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/models/ingredient_models.dart';
import '../services/menu_catalog_import_service.dart';
import '../theme/app_theme.dart';

/// Mostra i candidati OCR e restituisce gli ingredienti selezionati da salvare.
Future<List<IngredientCatalogItem>?> showMenuImportReviewSheet({
  required BuildContext context,
  required MenuImportResult result,
  String sourceTag = 'menu_import',
}) {
  return showModalBottomSheet<List<IngredientCatalogItem>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _MenuImportReviewSheet(result: result, sourceTag: sourceTag),
  );
}

class _MenuImportReviewSheet extends StatefulWidget {
  const _MenuImportReviewSheet({
    required this.result,
    required this.sourceTag,
  });

  final MenuImportResult result;
  final String sourceTag;

  @override
  State<_MenuImportReviewSheet> createState() => _MenuImportReviewSheetState();
}

class _MenuImportReviewSheetState extends State<_MenuImportReviewSheet> {
  late final List<MenuImportCandidate> _items;
  late final List<TextEditingController> _nameCtrls;
  late final List<TextEditingController> _daysCtrls;

  @override
  void initState() {
    super.initState();
    _items = widget.result.candidates
        .map(
          (c) => MenuImportCandidate(
            name: c.name,
            recommendedDays: c.recommendedDays,
            selected: c.selected,
            category: c.category,
            storageHint: c.storageHint,
            allergens: c.allergens,
            isDish: c.isDish,
          ),
        )
        .toList();
    _nameCtrls = _items.map((c) => TextEditingController(text: c.name)).toList();
    _daysCtrls = _items.map((c) => TextEditingController(text: '${c.recommendedDays}')).toList();
  }

  @override
  void dispose() {
    for (final c in _nameCtrls) {
      c.dispose();
    }
    for (final c in _daysCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleAll(bool value) {
    setState(() {
      for (final i in _items) {
        i.selected = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _items.where((e) => e.selected).length;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Import da ${widget.result.sourceLabel}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                _items.isEmpty
                    ? 'Nessuna voce riconosciuta. Prova una foto piu nitida o un PDF del menu.'
                    : 'Seleziona piatti e ingredienti da aggiungere. I piatti restano in cima, con la ricetta sotto.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.slateMuted),
              ),
            ),
            if (_items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    TextButton(onPressed: () => _toggleAll(true), child: const Text('Tutti')),
                    TextButton(onPressed: () => _toggleAll(false), child: const Text('Nessuno')),
                    const Spacer(),
                    Text('$selectedCount selezionati'),
                  ],
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: Icon(Icons.menu_book_outlined, size: 48, color: AppColors.slateMuted))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return CheckboxListTile(
                          value: item.selected,
                          onChanged: (v) => setState(() => item.selected = v ?? false),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                          title: TextField(
                            controller: _nameCtrls[index],
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Nome',
                              prefixIcon: Icon(
                                item.isDish ? Icons.local_pizza_outlined : Icons.egg_alt_outlined,
                                size: 18,
                              ),
                              prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            ),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.isDish ? 'Piatto' : 'Ingrediente',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppColors.tealDark,
                                    ),
                              ),
                              if (item.isDish &&
                                  item.storageHint.isNotEmpty &&
                                  item.storageHint != 'In frigo 0-4 °C')
                                Text(
                                  item.storageHint,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.slateMuted,
                                      ),
                                ),
                              Row(
                                children: [
                                  const Text('Giorni scad. '),
                                  SizedBox(
                                    width: 56,
                                    child: TextField(
                                      controller: _daysCtrls[index],
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: selectedCount == 0
                    ? null
                    : () {
                        final out = <IngredientCatalogItem>[];
                        for (var i = 0; i < _items.length; i++) {
                          if (!_items[i].selected) continue;
                          final name = _nameCtrls[i].text.trim();
                          if (name.isEmpty) continue;
                          final days = int.tryParse(_daysCtrls[i].text.trim()) ?? _items[i].recommendedDays;
                          out.add(
                            IngredientCatalogItem(
                              id: 'import-${const Uuid().v4()}',
                              name: name,
                              category: _items[i].category,
                              recommendedDays: days.clamp(1, 60),
                              storageHint: _items[i].storageHint,
                              allergens: _items[i].allergens,
                              source: widget.sourceTag,
                            ),
                          );
                        }
                        Navigator.pop(context, out);
                      },
                child: Text('Aggiungi $selectedCount al catalogo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
