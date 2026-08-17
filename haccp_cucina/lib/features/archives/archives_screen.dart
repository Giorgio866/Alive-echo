import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class ArchivesScreen extends ConsumerStatefulWidget {
  const ArchivesScreen({super.key});

  @override
  ConsumerState<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _ArchivesScreenState extends ConsumerState<ArchivesScreen> {
  List<File> _files = [];
  String? _lastPath;
  String? _lastMonth;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final service = ref.read(monthlyArchiveServiceProvider);
    final files = await service.listArchives();
    final lastPath = await service.lastArchivePath();
    final lastMonth = await service.lastArchiveMonthKey();
    if (!mounted) return;
    setState(() {
      _files = files;
      _lastPath = lastPath;
      _lastMonth = lastMonth;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archivi mensili'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            final result = await ref.read(monthlyArchiveServiceProvider).saveFullArchive(
                  ref.read(haccpRepositoryProvider),
                );
            messenger.showSnackBar(
              SnackBar(content: Text('Archivio salvato:\n${result.pdfPath}')),
            );
            await _reload();
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text('$e')));
          }
        },
        icon: const Icon(Icons.save_alt),
        label: const Text('Salva archivio ora'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.tealSoft.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Ogni nuovo mese l\'app salva automaticamente PDF + JSON sul telefono '
                    '(cartella HACCP_Archivi) e solo dopo cancella i dati piu vecchi di 30 giorni.\n\n'
                    'Ultimo mese registrato: ${_lastMonth ?? '-'}\n'
                    '${_lastPath != null ? 'Ultimo PDF: $_lastPath' : ''}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 16),
                if (_files.isEmpty)
                  const EmptyState(
                    icon: Icons.folder_open,
                    title: 'Nessun archivio ancora',
                    message: 'Al cambio mese verra creato in automatico, oppure usa "Salva archivio ora".',
                  )
                else
                  ..._files.map((f) {
                    final name = p.basename(f.path);
                    final isPdf = name.endsWith('.pdf');
                    final modified = f.statSync().modified;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(isPdf ? Icons.picture_as_pdf : Icons.data_object),
                      title: Text(name),
                      subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(modified)),
                      trailing: IconButton(
                        icon: const Icon(Icons.ios_share),
                        onPressed: () async {
                          await SharePlus.instance.share(
                            ShareParams(files: [XFile(f.path)], text: 'Archivio HACCP'),
                          );
                        },
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
