import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/network/api_client.dart';
import '../domain/mobile_ai.dart';

abstract class MobileVoiceTranscriber {
  Future<void> start();
  Future<String> stopAndTranscribe(String projectId);
  Future<void> cancel();
  Future<void> dispose();
}

abstract class MobileAudioCapture {
  Future<bool> hasPermission();
  Future<void> start(String path);
  Future<String?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class RecordAudioCapture implements MobileAudioCapture {
  RecordAudioCapture([AudioRecorder? recorder])
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(
    const RecordConfig(encoder: AudioEncoder.aacLc),
    path: path,
  );

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();
}

class WhisperVoiceTranscriber implements MobileVoiceTranscriber {
  WhisperVoiceTranscriber({
    required this.accessTokenProvider,
    required this.online,
    this.accessTokenRefresher,
    this.requestTimeout = const Duration(seconds: 90),
    ApiClient? apiClient,
    MobileAudioCapture? recorder,
    Future<Directory> Function()? temporaryDirectoryProvider,
  }) : _apiClient = apiClient ?? ApiClient(),
       _recorder = recorder ?? RecordAudioCapture(),
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory;

  final Future<String?> Function() accessTokenProvider;
  final Future<String?> Function()? accessTokenRefresher;
  final Future<bool> Function() online;
  final Duration requestTimeout;
  final ApiClient _apiClient;
  final MobileAudioCapture _recorder;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  String? _recordingPath;

  @override
  Future<void> start() async {
    if (!await online()) {
      throw const MobileAiException(
        'El dictado por voz necesita conexión.',
        code: 'offline',
      );
    }
    if (!await _recorder.hasPermission()) {
      throw const MobileAiException(
        'Debes permitir el micrófono para dictar.',
        code: 'microphone_denied',
      );
    }
    final directory = await _temporaryDirectoryProvider();
    final path =
        '${directory.path}${Platform.pathSeparator}'
        'uml-voice-${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(path);
    _recordingPath = path;
  }

  @override
  Future<String> stopAndTranscribe(String projectId) async {
    final stoppedPath = await _recorder.stop();
    final path = stoppedPath ?? _recordingPath;
    _recordingPath = null;
    if (path == null || path.isEmpty) {
      throw const MobileAiException(
        'No se capturó audio. Intenta nuevamente.',
        code: 'empty_audio',
      );
    }
    final file = File(path);
    try {
      if (!await file.exists() || await file.length() == 0) {
        throw const MobileAiException(
          'No se capturó audio. Intenta nuevamente.',
          code: 'empty_audio',
        );
      }
      var token = (await accessTokenProvider()) ?? '';
      if (token.isEmpty) {
        throw const MobileAiException(
          'La sesión remota no está disponible.',
          code: 'unauthenticated',
        );
      }
      final bytes = await file.readAsBytes();
      Future<http.Response> send(String accessToken) =>
          _apiClient.postMultipart(
            '/api/modeling/projects/$projectId/ai/transcriptions/',
            fileField: 'audio',
            filename: 'instruction.m4a',
            bytes: bytes,
            fileContentType: 'audio/mp4',
            fields: const {'language': 'es'},
            accessToken: accessToken,
            timeout: requestTimeout,
          );
      var response = await send(token);
      if (response.statusCode == 401 && accessTokenRefresher != null) {
        token = (await accessTokenRefresher!.call()) ?? '';
        if (token.isNotEmpty) response = await send(token);
      }
      Map<String, dynamic> payload;
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        payload = decoded is Map
            ? decoded.map((key, value) => MapEntry('$key', value))
            : <String, dynamic>{};
      } catch (_) {
        payload = <String, dynamic>{};
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MobileAiException(
          '${payload['detail'] ?? 'No se pudo transcribir el audio.'}',
          code: '${payload['code'] ?? 'transcription_unavailable'}',
        );
      }
      final text = '${payload['text'] ?? ''}'.trim();
      if (text.isEmpty) {
        throw const MobileAiException(
          'No se detectó texto en el audio.',
          code: 'empty_transcription',
        );
      }
      return text;
    } on TimeoutException {
      throw const MobileAiException(
        'La transcripción tardó demasiado en responder.',
        code: 'timeout',
      );
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> cancel() async {
    final path = _recordingPath;
    _recordingPath = null;
    try {
      await _recorder.cancel();
    } finally {
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
