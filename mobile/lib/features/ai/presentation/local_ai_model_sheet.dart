import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/auth/auth_session_manager.dart';
import '../data/device_resource_probe.dart';
import '../data/local_model_manager.dart';
import '../data/local_model_manifest_repository.dart';

class LocalAiModelSheet extends StatefulWidget {
  const LocalAiModelSheet({
    super.key,
    required this.userId,
    this.manager,
    this.accessTokenProvider,
    this.manifestLoader,
    this.resourceLoader,
  });

  final String userId;
  final LocalModelManager? manager;
  final Future<String?> Function()? accessTokenProvider;
  final Future<LocalModelManifest> Function(String token)? manifestLoader;
  final Future<DeviceResourceProfile> Function()? resourceLoader;

  @override
  State<LocalAiModelSheet> createState() => _LocalAiModelSheetState();
}

class _LocalAiModelSheetState extends State<LocalAiModelSheet> {
  late final LocalModelManager _manager =
      widget.manager ?? LocalModelManager(userId: widget.userId);
  StreamSubscription<LocalModelProgress>? _subscription;
  LocalModelManifest? _manifest;
  DeviceResourceProfile? _resources;
  LocalModelProgress? _progress;
  bool _loading = true;
  bool _checkingInstallation = false;
  bool _operationInProgress = false;
  bool _installed = false;
  bool _consented = false;
  int _storedBytes = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = _manager.progress.listen((progress) {
      if (!mounted) return;
      setState(() => _progress = progress);
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final token =
          await (widget.accessTokenProvider ??
              AuthSessionManager.getAccessToken)();
      if (token == null || token.isEmpty) {
        throw StateError('La sesión no está disponible.');
      }
      final manifest =
          await (widget.manifestLoader?.call(token) ??
              LocalModelManifestRepository().load(token));
      final resources =
          await (widget.resourceLoader?.call() ??
              const DeviceResourceProbe().read());
      final stored = await _manager.storedBytes(manifest);
      if (!mounted) return;
      setState(() {
        _manifest = manifest;
        _resources = resources;
        _storedBytes = stored;
        _loading = false;
        _checkingInstallation = true;
      });
      final installed = await _manager.isInstalled(manifest);
      if (!mounted) return;
      setState(() {
        _installed = installed;
        _checkingInstallation = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _checkingInstallation = false;
        _error = '$error'.replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _download({bool repair = false}) async {
    final manifest = _manifest;
    final resources = _resources;
    if (manifest == null || resources == null) return;
    setState(() {
      _error = null;
      _operationInProgress = true;
    });
    try {
      final File? installedFile;
      if (repair) {
        installedFile = await _manager.repair(
          manifest,
          consented: _consented,
          resources: resources,
        );
      } else {
        installedFile = await _manager.download(
          manifest,
          consented: _consented,
          resources: resources,
        );
      }
      final stored = await _manager.storedBytes(manifest);
      if (mounted) {
        setState(() {
          // download/repair only return a file after size and SHA-256 have
          // already been verified and the .part was atomically installed.
          _installed = installedFile != null;
          _storedBytes = stored;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = '$error'
              .replaceFirst('Bad state: ', '')
              .replaceFirst('FormatException: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _operationInProgress = false);
    }
  }

  Future<void> _delete() async {
    final manifest = _manifest;
    if (manifest == null) return;
    await _manager.delete(manifest);
    if (mounted) {
      setState(() {
        _installed = false;
        _storedBytes = 0;
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    if (widget.manager == null) unawaited(_manager.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manifest = _manifest;
    final resources = _resources;
    final problems = manifest == null || resources == null
        ? const <String>[]
        : resources.incompatibilities(manifest);
    final busy =
        {
          LocalModelDownloadState.downloading,
          LocalModelDownloadState.verifying,
        }.contains(_progress?.state) ||
        _checkingInstallation ||
        _operationInProgress;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 680),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                'IA local en el dispositivo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'El modelo es opcional. Los proyectos permanecen separados y el prompt se procesa en este dispositivo.',
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (manifest != null) ...[
                const Divider(height: 28),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _installed ? Icons.offline_pin : Icons.memory_outlined,
                    color: _installed ? Colors.green : null,
                  ),
                  title: const Text('Qwen2.5-Coder 1.5B · Q4_K_M'),
                  subtitle: Text(
                    '${manifest.license} · ${_bytes(manifest.byteSize)} · contexto ${manifest.contextTokens} tokens\n'
                    'Almacenado: ${_bytes(_storedBytes)}',
                  ),
                ),
                if (resources != null)
                  Text(
                    'Dispositivo: ${resources.architecture} · RAM ${_bytes(resources.ramBytes)} · libre ${_bytes(resources.freeStorageBytes)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (problems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      problems.join('\n'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_checkingInstallation)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('Verificando el modelo instalado…'),
                        ),
                      ],
                    ),
                  ),
                if (!_installed)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _consented,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => _consented = value == true),
                    title: const Text('Acepto descargar el modelo opcional'),
                    subtitle: Text(
                      'Origen: ${manifest.source}\nLicencia: ${manifest.license}',
                    ),
                  ),
                if (_progress != null &&
                    _progress!.state != LocalModelDownloadState.idle) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _progress!.fraction),
                  const SizedBox(height: 6),
                  Text(
                    '${_stateLabel(_progress!.state)} · ${_bytes(_progress!.downloadedBytes)} / ${_bytes(_progress!.totalBytes)}',
                  ),
                ],
                if (_operationInProgress && _progress == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Preparando la descarga…'),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!_installed && !busy)
                      FilledButton.icon(
                        onPressed: _consented && problems.isEmpty
                            ? () => _download()
                            : null,
                        icon: const Icon(Icons.download),
                        label: Text(
                          _storedBytes > 0 ? 'Reanudar' : 'Descargar',
                        ),
                      ),
                    if (busy)
                      OutlinedButton.icon(
                        onPressed: _manager.pause,
                        icon: const Icon(Icons.pause),
                        label: const Text('Pausar'),
                      ),
                    if (_storedBytes > 0 && !_installed && !busy)
                      OutlinedButton.icon(
                        onPressed: _consented && problems.isEmpty
                            ? () => _download(repair: true)
                            : null,
                        icon: const Icon(Icons.build_outlined),
                        label: const Text('Reparar'),
                      ),
                    if (_storedBytes > 0 && !busy)
                      TextButton.icon(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Eliminar modelo'),
                      ),
                  ],
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _bytes(int value) {
  if (value >= 1024 * 1024 * 1024) {
    return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (value >= 1024 * 1024) {
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(value / 1024).toStringAsFixed(1)} KB';
}

String _stateLabel(LocalModelDownloadState state) => switch (state) {
  LocalModelDownloadState.idle => 'Sin descargar',
  LocalModelDownloadState.downloading => 'Descargando',
  LocalModelDownloadState.paused => 'Pausado',
  LocalModelDownloadState.verifying => 'Verificando',
  LocalModelDownloadState.ready => 'Listo',
  LocalModelDownloadState.failed => 'Requiere atención',
};
