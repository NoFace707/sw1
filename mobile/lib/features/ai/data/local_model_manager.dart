import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../domain/expert_evaluator.dart';

class LocalModelManifest {
  const LocalModelManifest({
    required this.id,
    required this.version,
    required this.source,
    required this.license,
    required this.fileName,
    required this.downloadUrl,
    required this.byteSize,
    required this.sha256Hash,
    required this.contextTokens,
    required this.chatTemplate,
    required this.minimumRamBytes,
    required this.minimumStorageBytes,
    required this.architectures,
    required this.manifestChecksum,
  });

  final String id;
  final String version;
  final String source;
  final String license;
  final String fileName;
  final Uri downloadUrl;
  final int byteSize;
  final String sha256Hash;
  final int contextTokens;
  final String chatTemplate;
  final int minimumRamBytes;
  final int minimumStorageBytes;
  final List<String> architectures;
  final String manifestChecksum;

  factory LocalModelManifest.verified(Map<String, dynamic> payload) {
    final unsigned = Map<String, dynamic>.from(payload)
      ..remove('manifest_checksum');
    final actual = crypto.sha256
        .convert(utf8.encode(canonicalJson(unsigned)))
        .toString();
    final profile = _map(payload['minimum_profile']);
    final manifest = LocalModelManifest(
      id: '${payload['id'] ?? ''}',
      version: '${payload['version'] ?? ''}',
      source: '${payload['source'] ?? ''}',
      license: '${payload['license'] ?? ''}',
      fileName: '${payload['file_name'] ?? ''}',
      downloadUrl: Uri.parse('${payload['download_url'] ?? ''}'),
      byteSize: (payload['byte_size'] as num?)?.toInt() ?? 0,
      sha256Hash: '${payload['sha256'] ?? ''}',
      contextTokens: (payload['context_tokens'] as num?)?.toInt() ?? 0,
      chatTemplate: '${payload['chat_template'] ?? ''}',
      minimumRamBytes: (profile['ram_bytes'] as num?)?.toInt() ?? 0,
      minimumStorageBytes:
          (profile['free_storage_bytes'] as num?)?.toInt() ?? 0,
      architectures: (profile['architecture'] as List? ?? const [])
          .map((item) => '$item')
          .toList(growable: false),
      manifestChecksum: '${payload['manifest_checksum'] ?? ''}',
    );
    if (manifest.id.isEmpty ||
        manifest.version.isEmpty ||
        manifest.fileName.contains(RegExp(r'[/\\]')) ||
        manifest.downloadUrl.scheme != 'https' ||
        manifest.byteSize <= 0 ||
        manifest.sha256Hash.length != 64 ||
        manifest.manifestChecksum != actual) {
      throw const FormatException('El manifiesto del modelo fue alterado.');
    }
    return manifest;
  }
}

class DeviceResourceProfile {
  const DeviceResourceProfile({
    required this.architecture,
    required this.ramBytes,
    required this.freeStorageBytes,
  });
  final String architecture;
  final int ramBytes;
  final int freeStorageBytes;

  List<String> incompatibilities(LocalModelManifest manifest) => [
    if (!manifest.architectures.contains(architecture))
      'Arquitectura no compatible: $architecture.',
    if (ramBytes < manifest.minimumRamBytes)
      'Memoria insuficiente para cargar el modelo.',
    if (freeStorageBytes < manifest.minimumStorageBytes)
      'Espacio libre insuficiente para descargar y verificar el modelo.',
  ];
}

enum LocalModelDownloadState {
  idle,
  downloading,
  paused,
  verifying,
  ready,
  failed,
}

class LocalModelProgress {
  const LocalModelProgress({
    required this.state,
    required this.downloadedBytes,
    required this.totalBytes,
    this.message,
  });
  final LocalModelDownloadState state;
  final int downloadedBytes;
  final int totalBytes;
  final String? message;
  double get fraction => totalBytes <= 0 ? 0 : downloadedBytes / totalBytes;
}

class LocalModelManager {
  LocalModelManager({
    required this.userId,
    http.Client? client,
    Future<Directory> Function()? directoryProvider,
  }) : _client = client ?? http.Client(),
       _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final String userId;
  final http.Client _client;
  final Future<Directory> Function() _directoryProvider;
  final _progress = StreamController<LocalModelProgress>.broadcast();
  bool _pauseRequested = false;
  bool _closed = false;
  Future<File?>? _activeDownload;

  Stream<LocalModelProgress> get progress => _progress.stream;

  Future<File> modelFile(LocalModelManifest manifest) async {
    final root = await _directoryProvider();
    final safeUser = crypto.sha256.convert(utf8.encode(userId)).toString();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}local_ai${Platform.pathSeparator}$safeUser',
    );
    await directory.create(recursive: true);
    return File(
      '${directory.path}${Platform.pathSeparator}${manifest.fileName}',
    );
  }

  Future<bool> isInstalled(LocalModelManifest manifest) async {
    final file = await modelFile(manifest);
    return file.existsSync() &&
        file.lengthSync() == manifest.byteSize &&
        await _hash(file) == manifest.sha256Hash;
  }

  void pause() => _pauseRequested = true;

  Future<File?> download(
    LocalModelManifest manifest, {
    required bool consented,
    required DeviceResourceProfile resources,
  }) {
    final active = _activeDownload;
    if (active != null) return active;
    late final Future<File?> tracked;
    tracked =
        _performDownload(
          manifest,
          consented: consented,
          resources: resources,
        ).whenComplete(() {
          if (identical(_activeDownload, tracked)) _activeDownload = null;
        });
    _activeDownload = tracked;
    return tracked;
  }

  Future<File?> _performDownload(
    LocalModelManifest manifest, {
    required bool consented,
    required DeviceResourceProfile resources,
  }) async {
    if (!consented) throw StateError('La descarga requiere consentimiento.');
    final problems = resources.incompatibilities(manifest);
    if (problems.isNotEmpty) throw StateError(problems.join(' '));
    if (_closed) throw StateError('El gestor de modelo está cerrado.');
    _pauseRequested = false;
    final target = await modelFile(manifest);
    final partial = File('${target.path}.part');
    var offset = partial.existsSync() ? partial.lengthSync() : 0;
    if (offset > manifest.byteSize) {
      await partial.delete();
      offset = 0;
    }
    final request = http.Request('GET', manifest.downloadUrl);
    if (offset > 0) request.headers['Range'] = 'bytes=$offset-';
    final response = await _client.send(request);
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw HttpException('Descarga rechazada (${response.statusCode}).');
    }
    if (offset > 0 && response.statusCode == 200) {
      await partial.writeAsBytes(const [], flush: true);
      offset = 0;
    }
    final sink = partial.openWrite(mode: FileMode.append);
    var downloaded = offset;
    try {
      await for (final chunk in response.stream) {
        if (_pauseRequested) {
          _emit(LocalModelDownloadState.paused, downloaded, manifest.byteSize);
          return null;
        }
        sink.add(chunk);
        downloaded += chunk.length;
        if (downloaded > manifest.byteSize) {
          throw const FormatException('El archivo supera el tamaño declarado.');
        }
        _emit(
          LocalModelDownloadState.downloading,
          downloaded,
          manifest.byteSize,
        );
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    if (downloaded != manifest.byteSize) {
      _emit(
        LocalModelDownloadState.failed,
        downloaded,
        manifest.byteSize,
        'Descarga incompleta; puede reanudarse.',
      );
      return null;
    }
    _emit(LocalModelDownloadState.verifying, downloaded, manifest.byteSize);
    if (await _hash(partial) != manifest.sha256Hash) {
      await partial.delete();
      _emit(
        LocalModelDownloadState.failed,
        0,
        manifest.byteSize,
        'Hash inválido; use Reparar para descargar nuevamente.',
      );
      throw const FormatException('El GGUF no supera la verificación SHA-256.');
    }
    if (target.existsSync()) await target.delete();
    final installed = await partial.rename(target.path);
    _emit(LocalModelDownloadState.ready, manifest.byteSize, manifest.byteSize);
    return installed;
  }

  Future<bool> verify(LocalModelManifest manifest) => isInstalled(manifest);

  Future<File?> repair(
    LocalModelManifest manifest, {
    required bool consented,
    required DeviceResourceProfile resources,
  }) async {
    final active = _activeDownload;
    if (active != null) return active;
    final target = await modelFile(manifest);
    final partial = File('${target.path}.part');
    if (target.existsSync()) await target.delete();
    if (partial.existsSync()) await partial.delete();
    return download(manifest, consented: consented, resources: resources);
  }

  Future<void> delete(LocalModelManifest manifest) async {
    final target = await modelFile(manifest);
    final partial = File('${target.path}.part');
    if (target.existsSync()) await target.delete();
    if (partial.existsSync()) await partial.delete();
    _emit(LocalModelDownloadState.idle, 0, manifest.byteSize);
  }

  Future<int> storedBytes(LocalModelManifest manifest) async {
    final target = await modelFile(manifest);
    final partial = File('${target.path}.part');
    return (target.existsSync() ? target.lengthSync() : 0) +
        (partial.existsSync() ? partial.lengthSync() : 0);
  }

  Future<void> close() async {
    _closed = true;
    _client.close();
    await _progress.close();
  }

  void _emit(
    LocalModelDownloadState state,
    int downloaded,
    int total, [
    String? message,
  ]) {
    if (!_progress.isClosed) {
      _progress.add(
        LocalModelProgress(
          state: state,
          downloadedBytes: downloaded,
          totalBytes: total,
          message: message,
        ),
      );
    }
  }
}

Future<String> _hash(File file) async {
  return (await crypto.sha256.bind(file.openRead()).first).toString();
}

Map<String, dynamic> _map(Object? value) => value is Map
    ? value.map((key, value) => MapEntry('$key', value))
    : const {};
