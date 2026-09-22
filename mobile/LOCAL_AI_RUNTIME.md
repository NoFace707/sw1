# Runtime de IA local

- `llama_cpp_dart`: `0.9.0-dev.10` (fijado sin rango semántico).
- `llama.cpp`: tag `b10182`, commit `afeebe103bd99cda8f5dfaefcabadf890db7fda7`.
- ABI objetivo: Android `arm64-v8a` desde API 26 (Android 8.0) e iOS `arm64`.
- Modelo: Qwen2.5-Coder-1.5B-Instruct GGUF `Q4_K_M`.

El adaptador `LlamaCppRuntime` ejecuta el motor en el isolate administrado por
`LlamaEngine`, aplica la plantilla de chat embebida de Qwen mediante
`EngineChat`, restringe la generación con una gramática JSON, permite una sola
inferencia desde `LocalLlamaEngine` y libera la sesión al terminar o cancelar.

La dependencia Dart no incluye por sí sola los binarios nativos en esta versión.
Android incorpora el AAR CPU oficial de la misma release en
`android/app/libs/llama-cpp-dart.aar`, verificado con SHA-256:

`51b5f4624e10296e362725a056ed0e3609c71f00ce4575ce28b28f8ec9aafcf7`

Los binarios deben mantenerse compilados exactamente contra la revisión indicada:

- Android: el AAR aporta `libllama.so`, `libggml*.so` y `libmtmd.so` para
  `arm64-v8a`; Gradle limita esta variante al ABI compatible.
- iOS: debe incorporar `llama.xcframework` como `Embed & Sign`; la comprobación
  de símbolos mantiene la IA local desactivada mientras el framework no esté
  presente.

La tarea de aceptación física permanece pendiente hasta ejecutar una inferencia
mínima con el GGUF real en ambos dispositivos y registrar memoria, latencia,
batería y temperatura.
