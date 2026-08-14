import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/document_models.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  static const _categories = {
    'ddt': 'DDT / bolla',
    'certificato': 'Certificato / analisi',
    'formazione': 'Formazione staff',
    'altro': 'Altro',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Documenti scansionati')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _scanFlow(context, ref),
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Scansiona'),
      ),
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Errore: $e')),
        data: (docs) {
          if (docs.isEmpty) {
            return EmptyState(
              icon: Icons.document_scanner_outlined,
              title: 'Archivio vuoto',
              message: 'Scansiona DDT, certificati fornitore e moduli formazione con la fotocamera.',
              cta: FilledButton.icon(
                onPressed: () => _scanFlow(context, ref),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Avvia scansione'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _preview(context, doc),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.slate.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: _thumb(doc.filePath),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doc.title, style: Theme.of(context).textTheme.titleMedium),
                            Text(
                              '${_categories[doc.category] ?? doc.category}'
                              ' · ${DateFormat('dd/MM/yyyy HH:mm').format(doc.scannedAt)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.slateMuted,
                                  ),
                            ),
                            if (doc.supplier != null && doc.supplier!.isNotEmpty)
                              Text('Fornitore: ${doc.supplier}'),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          await ref.read(haccpRepositoryProvider).deleteDocument(doc.id);
                          ref.invalidate(documentsProvider);
                          ref.invalidate(dashboardProvider);
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _thumb(String path) {
    if (kIsWeb) {
      return Container(
        color: AppColors.tealSoft,
        child: const Icon(Icons.description_outlined, color: AppColors.tealDark),
      );
    }
    final file = File(path);
    if (!file.existsSync()) {
      return Container(
        color: AppColors.tealSoft,
        child: const Icon(Icons.broken_image_outlined, color: AppColors.tealDark),
      );
    }
    return Image.file(file, fit: BoxFit.cover);
  }

  Future<void> _preview(BuildContext context, DocumentRecord doc) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(doc.title, style: Theme.of(ctx).textTheme.titleLarge),
            ),
            if (!kIsWeb && File(doc.filePath).existsSync())
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: Image.file(File(doc.filePath), fit: BoxFit.contain),
              )
            else
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Anteprima non disponibile su questa piattaforma.'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi')),
          ],
        ),
      ),
    );
  }

  Future<void> _scanFlow(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Scatta con fotocamera'),
              subtitle: const Text('Ideale per DDT e bolle consegna'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Scegli dalla galleria'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final scanner = ref.read(documentScanServiceProvider);
    final path = source == 'camera' ? await scanner.captureFromCamera() : await scanner.pickFromGallery();
    if (path == null || !context.mounted) return;

    final titleCtrl = TextEditingController();
    final supplierCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var category = 'ddt';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Dettagli documento', style: Theme.of(ctx).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Titolo'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: category,
                    items: _categories.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setLocal(() => category = v);
                    },
                    decoration: const InputDecoration(labelText: 'Categoria'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: supplierCtrl,
                    decoration: const InputDecoration(labelText: 'Fornitore (opzionale)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'Note'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      final title = titleCtrl.text.trim().isEmpty
                          ? 'Documento ${DateFormat('dd/MM HH:mm').format(DateTime.now())}'
                          : titleCtrl.text.trim();
                      await ref.read(haccpRepositoryProvider).addDocument(
                            DocumentRecord(
                              id: const Uuid().v4(),
                              title: title,
                              category: category,
                              filePath: path,
                              scannedAt: DateTime.now(),
                              supplier:
                                  supplierCtrl.text.trim().isEmpty ? null : supplierCtrl.text.trim(),
                              notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                            ),
                          );
                      ref.invalidate(documentsProvider);
                      ref.invalidate(dashboardProvider);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Documento archiviato')),
                        );
                      }
                    },
                    child: const Text('Salva nel registro'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
