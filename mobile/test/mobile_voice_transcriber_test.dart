import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/ai/data/mobile_voice_transcriber.dart';
import 'package:mobile/features/ai/domain/mobile_ai.dart';

class _FakeCapture implements MobileAudioCapture {
  _FakeCapture({this.permission = true});

  final bool permission;
  String? path;
  bool disposed = false;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<void> start(String value) async {
    path = value;
    await File(value).writeAsBytes([1, 2, 3, 4]);
  }

  @override
  Future<String?> stop() async => path;

  @override
  Future<void> cancel() async {
    final value = path;
    if (value != null && await File(value).exists()) {
      await File(value).delete();
    }
  }

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  test('sube audio, renueva sesión y elimina el archivo temporal', () async {
    final directory = await Directory.systemTemp.createTemp('uml-voice-test-');
    final capture = _FakeCapture();
    var token = 'expired';
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(
        request.url.path,
        '/api/modeling/projects/project-1/ai/transcriptions/',
      );
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      expect(request.body, contains('filename="instruction.m4a"'));
      expect(request.body.toLowerCase(), contains('content-type: audio/mp4'));
      if (request.headers['authorization'] != 'Bearer fresh') {
        return http.Response('{"detail":"Token vencido"}', 401);
      }
      return http.Response(
        '{"text":"crea una clase Cliente","model":"whisper-1"}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final transcriber = WhisperVoiceTranscriber(
      accessTokenProvider: () async => token,
      accessTokenRefresher: () async {
        token = 'fresh';
        return token;
      },
      online: () async => true,
      apiClient: ApiClient(baseUrl: 'http://test', client: client),
      recorder: capture,
      temporaryDirectoryProvider: () async => directory,
    );

    await transcriber.start();
    final recordedPath = capture.path!;
    expect(await File(recordedPath).exists(), isTrue);
    final text = await transcriber.stopAndTranscribe('project-1');

    expect(text, 'crea una clase Cliente');
    expect(calls, 2);
    expect(await File(recordedPath).exists(), isFalse);
    await transcriber.dispose();
    expect(capture.disposed, isTrue);
    await directory.delete(recursive: true);
  });

  test('rechaza offline o permiso denegado antes de crear audio', () async {
    final offline = WhisperVoiceTranscriber(
      accessTokenProvider: () async => 'token',
      online: () async => false,
      recorder: _FakeCapture(),
    );
    await expectLater(
      offline.start(),
      throwsA(
        isA<MobileAiException>().having(
          (error) => error.code,
          'code',
          'offline',
        ),
      ),
    );
    await offline.dispose();

    final denied = WhisperVoiceTranscriber(
      accessTokenProvider: () async => 'token',
      online: () async => true,
      recorder: _FakeCapture(permission: false),
    );
    await expectLater(
      denied.start(),
      throwsA(
        isA<MobileAiException>().having(
          (error) => error.code,
          'code',
          'microphone_denied',
        ),
      ),
    );
    await denied.dispose();
  });
}
