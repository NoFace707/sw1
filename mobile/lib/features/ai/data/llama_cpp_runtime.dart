import 'dart:io';

import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import 'local_llama_engine.dart';

/// Thin adapter that keeps llama_cpp_dart types out of presentation code.
/// The package and llama.cpp revision are pinned in pubspec.lock and
/// LOCAL_AI_RUNTIME.md. Each platform must expose the matching native symbols.
class LlamaCppRuntime implements LocalModelRuntime {
  LlamaCppRuntime._(this._engine, this._chat, this.maxTokens);

  final LlamaEngine _engine;
  final EngineChat _chat;
  final int maxTokens;
  bool _closed = false;

  static Future<LlamaCppRuntime> create({
    required String modelPath,
    required int contextTokens,
    int maxTokens = 1024,
    String androidLibraryPath = 'libllama.so',
  }) async {
    try {
      final model = ModelParams(path: modelPath, gpuLayers: 0);
      final context = ContextParams(
        nCtx: contextTokens,
        nBatch: 256,
        nUbatch: 256,
      );
      final engine = Platform.isIOS
          ? await LlamaEngine.spawnFromProcess(
              modelParams: model,
              contextParams: context,
            )
          : await LlamaEngine.spawn(
              libraryPath: androidLibraryPath,
              modelParams: model,
              contextParams: context,
            );
      return LlamaCppRuntime._(engine, await engine.createChat(), maxTokens);
    } catch (error) {
      final message = '$error';
      if (message.contains('libllama.so') ||
          message.contains('dynamic library')) {
        throw StateError(
          'El runtime nativo de IA local no está incluido en esta instalación. '
          'Reinstala la versión Android arm64 más reciente de la aplicación.',
        );
      }
      rethrow;
    }
  }

  @override
  Stream<String> generate(LocalAiPrompt prompt) async* {
    _chat.addSystem(prompt.system);
    _chat.addUser(prompt.user);
    await for (final event in _chat.generate(
      maxTokens: maxTokens,
      sampler: const SamplerParams(
        temperature: 0.1,
        topP: 0.9,
        grammar: GrammarConfig(grammar: _jsonGrammar),
      ),
    )) {
      switch (event) {
        case TokenEvent():
          yield event.text;
        case DoneEvent():
          if (event.trailingText.isNotEmpty) yield event.trailingText;
        case ShiftEvent():
          break;
      }
    }
  }

  @override
  Future<void> cancel() => close();

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _chat.dispose();
    await _engine.dispose();
  }
}

// Gramática JSON genérica de llama.cpp. Evita que el modelo anteponga texto,
// Markdown o tokens conversacionales que rompan el contrato de propuestas.
const _jsonGrammar = r'''
root   ::= object
value  ::= object | array | string | number | ("true" | "false" | "null") ws
object ::= "{" ws (string ":" ws value ("," ws string ":" ws value)*)? "}" ws
array  ::= "[" ws (value ("," ws value)*)? "]" ws
string ::= "\"" ([^"\\\x7F\x00-\x1F] | "\\" (["\\/bfnrt] | "u" [0-9a-fA-F]{4}))* "\"" ws
number ::= ("-"? ([0-9] | [1-9] [0-9]*) ("." [0-9]+)? ([eE] [-+]? [0-9]+)?) ws
ws     ::= ([ \t\n] ws)?
''';
