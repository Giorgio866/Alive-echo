import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/ingredient_models.dart';
import '../../data/models/temperature_models.dart';
import '../../providers/app_providers.dart';
import '../../services/menu_catalog_import_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/menu_import_review_sheet.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  final _activityCtrl = TextEditingController(text: 'La mia pizzeria');
  final _operatorCtrl = TextEditingController();
  late List<_FridgeDraft> _fridges;
  final List<_CustomIngredientDraft> _customIngredients = [];
  int _page = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fridges = [
      for (var i = 1; i <= 5; i++)
        _FridgeDraft(name: 'Frigo $i', zone: 'frigo', minC: 0, maxC: 4),
      _FridgeDraft(name: 'Congelatore', zone: 'freezer', minC: -25, maxC: -18),
    ];
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _activityCtrl.dispose();
    _operatorCtrl.dispose();
    for (final f in _fridges) {
      f.nameCtrl.dispose();
    }
    for (final c in _customIngredients) {
      c.nameCtrl.dispose();
      c.daysCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < 3) {
      await _pageCtrl.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final activity = _activityCtrl.text.trim().isEmpty ? 'La mia pizzeria' : _activityCtrl.text.trim();
      final operator = _operatorCtrl.text.trim().isEmpty ? 'Operatore' : _operatorCtrl.text.trim();

      final points = _fridges
          .map(
            (f) => TemperaturePoint(
              id: const Uuid().v4(),
              name: f.nameCtrl.text.trim().isEmpty ? f.name : f.nameCtrl.text.trim(),
              zone: f.zone,
              minC: f.minC,
              maxC: f.maxC,
              photoPath: f.photoPath,
            ),
          )
          .toList();

      await ref.read(haccpRepositoryProvider).replaceTemperaturePoints(points);
      // Catalogo: solo ciò che l'utente ha caricato ora
      await ref.read(haccpRepositoryProvider).clearIngredientCatalog();

      for (final c in _customIngredients) {
        final name = c.nameCtrl.text.trim();
        if (name.isEmpty) continue;
        final days = int.tryParse(c.daysCtrl.text.trim()) ?? 3;
        await ref.read(haccpRepositoryProvider).upsertCustomIngredient(
              IngredientCatalogItem(
                id: 'custom-${const Uuid().v4()}',
                name: name,
                category: 'custom',
                recommendedDays: days.clamp(1, 60),
                storageHint: 'In frigo 0-4 °C',
                source: 'custom_photo',
                photoPath: c.photoPath,
              ),
            );
      }

      final current = await ref.read(settingsServiceProvider).load();
      await ref.read(settingsServiceProvider).save(
            current.copyWith(
              activityName: activity,
              defaultOperator: operator,
              onboardingCompleted: true,
            ),
          );

      ref.invalidate(settingsProvider);
      ref.invalidate(temperaturePointsProvider);
      ref.invalidate(latestReadingsProvider);
      ref.invalidate(ingredientCatalogProvider);
      ref.invalidate(dashboardProvider);

      if (mounted) context.go('/');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _capturePhoto() async {
    return ref.read(documentScanServiceProvider).captureFromCamera();
  }

  Future<void> _importMenuFromPhoto({required bool fromCamera}) async {
    setState(() => _saving = true);
    try {
      final scan = ref.read(documentScanServiceProvider);
      final path = fromCamera ? await scan.captureFromCamera() : await scan.pickFromGallery();
      if (path == null) return;
      final result = await ref.read(menuCatalogImportServiceProvider).importFromImagePath(path);
      if (!mounted) return;
      await _applyMenuImport(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import foto fallito: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _importMenuFromPdf() async {
    setState(() => _saving = true);
    try {
      final result = await ref.read(menuCatalogImportServiceProvider).pickAndImportPdf();
      if (result == null || !mounted) return;
      await _applyMenuImport(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import PDF fallito: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _applyMenuImport(MenuImportResult result) async {
    final items = await showMenuImportReviewSheet(
      context: context,
      result: result,
      sourceTag: 'menu_import',
    );
    if (items == null || items.isEmpty || !mounted) return;
    setState(() {
      for (final item in items) {
        final draft = _CustomIngredientDraft()
          ..nameCtrl.text = item.name
          ..daysCtrl.text = '${item.recommendedDays}';
        _customIngredients.add(draft);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${items.length} voci aggiunte dal menu')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text('Setup', style: Theme.of(context).textTheme.headlineSmall),
                  const Spacer(),
                  Text('${_page + 1}/4', style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
            ),
            LinearProgressIndicator(value: (_page + 1) / 4, minHeight: 3),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _welcomePage(),
                  _fridgesPage(),
                  _ingredientsPage(),
                  _donePage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  if (_page > 0)
                    OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => _pageCtrl.previousPage(
                                duration: const Duration(milliseconds: 240),
                                curve: Curves.easeOut,
                              ),
                      child: const Text('Indietro'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving ? null : _next,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_page == 3 ? 'Inizia' : 'Avanti'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomePage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Benvenuto in HACCP Cucina', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'In pochi passi personalizzi locale, frigoriferi e ingredienti. '
          'I dati restano sul telefono.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.slateMuted),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _activityCtrl,
          decoration: const InputDecoration(labelText: 'Nome locale', hintText: 'Blue Eyes Pizzeria'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _operatorCtrl,
          decoration: const InputDecoration(labelText: 'Operatore predefinito', hintText: 'Es. Marco'),
        ),
      ],
    );
  }

  Widget _fridgesPage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('I tuoi impianti del freddo', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Hai 5 frigoriferi e 1 congelatore. Rinominali e aggiungi una foto di fianco a ciascuno.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.slateMuted),
        ),
        const SizedBox(height: 16),
        ..._fridges.asMap().entries.map((e) {
          final i = e.key;
          final f = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.slate.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final path = await _capturePhoto();
                      if (path != null) setState(() => f.photoPath = path);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: f.photoPath != null && !kIsWeb && File(f.photoPath!).existsSync()
                            ? Image.file(File(f.photoPath!), fit: BoxFit.cover)
                            : ColoredBox(
                                color: AppColors.tealSoft,
                                child: Icon(
                                  f.zone == 'freezer' ? Icons.ac_unit : Icons.kitchen_outlined,
                                  color: AppColors.tealDark,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: f.nameCtrl,
                          decoration: InputDecoration(
                            labelText: i < 5 ? 'Nome frigo ${i + 1}' : 'Nome congelatore',
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () async {
                              final path = await _capturePhoto();
                              if (path != null) setState(() => f.photoPath = path);
                            },
                            icon: const Icon(Icons.photo_camera_outlined, size: 18),
                            label: Text(f.photoPath == null ? 'Aggiungi foto' : 'Cambia foto'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _ingredientsPage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Il tuo catalogo ingredienti', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Importa il menu con una foto o un PDF, oppure aggiungi i preparati uno per uno. '
          'Poi controlla i giorni di scadenza.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.slateMuted),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : () => _importMenuFromPhoto(fromCamera: true),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Importa da foto menu'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _saving ? null : () => _importMenuFromPhoto(fromCamera: false),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Importa da foto in galleria'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _saving ? null : _importMenuFromPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Importa da PDF menu'),
        ),
        const SizedBox(height: 16),
        if (_customIngredients.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.amberSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Suggerimento: fotografa il menu della pizzeria oppure carica il PDF. '
              'Poi seleziona solo i prodotti che usi in cucina.',
            ),
          ),
        ..._customIngredients.asMap().entries.map((e) {
          final c = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.slate.withValues(alpha: 0.08)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final path = await _capturePhoto();
                      if (path != null) setState(() => c.photoPath = path);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: c.photoPath != null && !kIsWeb && File(c.photoPath!).existsSync()
                            ? Image.file(File(c.photoPath!), fit: BoxFit.cover)
                            : const ColoredBox(
                                color: AppColors.tealSoft,
                                child: Icon(Icons.add_a_photo_outlined, color: AppColors.tealDark),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: c.nameCtrl,
                          decoration: const InputDecoration(labelText: 'Nome preparato / ingrediente'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: c.daysCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Giorni di scadenza (dopo prep./apertura)',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        c.nameCtrl.dispose();
                        c.daysCtrl.dispose();
                        _customIngredients.removeAt(e.key);
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          );
        }),
        FilledButton.icon(
          onPressed: () async {
            final path = await _capturePhoto();
            setState(() {
              _customIngredients.add(
                _CustomIngredientDraft(photoPath: path)..daysCtrl.text = '3',
              );
            });
          },
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Aggiungi ingrediente da foto'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _customIngredients.add(_CustomIngredientDraft()..daysCtrl.text = '3');
            });
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Aggiungi solo con nome'),
        ),
        TextButton(
          onPressed: () async {
            // Opzionale: solo se l'utente lo chiede esplicitamente
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Catalogo di esempio?'),
                content: const Text(
                  'Puoi importare un catalogo di esempio (menu pizzeria) e poi modificarlo. '
                  'Non e obbligatorio: meglio caricare i tuoi prodotti.',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Importa esempio')),
                ],
              ),
            );
            if (ok == true) {
              await ref.read(haccpRepositoryProvider).importOptionalBlueEyesCatalog();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Esempio importato: potrai modificarlo dopo')),
                );
              }
            }
          },
          child: const Text('Hai fretta? Importa catalogo di esempio'),
        ),
      ],
    );
  }

  Widget _donePage() {
    final n = _customIngredients.where((c) => c.nameCtrl.text.trim().isNotEmpty).length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Tutto pronto', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          '• ${_fridges.length} punti temperatura (5 frigo + congelatore)\n'
          '• $n ingredienti nel TUO catalogo\n'
          '• Temperature anche da foto del termometro\n'
          '• Notifiche scadenza e export PDF',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.tealSoft.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            'Potrai aggiungere altri ingredienti e aggiornare foto frigo in qualsiasi momento.',
          ),
        ),
      ],
    );
  }
}

class _FridgeDraft {
  _FridgeDraft({
    required this.name,
    required this.zone,
    required this.minC,
    required this.maxC,
  }) : nameCtrl = TextEditingController(text: name);

  final String name;
  final String zone;
  final double minC;
  final double maxC;
  final TextEditingController nameCtrl;
  String? photoPath;
}

class _CustomIngredientDraft {
  _CustomIngredientDraft({this.photoPath});

  final nameCtrl = TextEditingController();
  final daysCtrl = TextEditingController();
  String? photoPath;
}
