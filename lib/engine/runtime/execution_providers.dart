/// ONNX Runtime execution providers the app can ask for. The CPU provider is always
/// there and is the fallback for everything else.
enum InferenceAccelerator {
  /// ONNX Runtime's own CPU kernels (MLAS). The default.
  cpu('CPUExecutionProvider'),

  /// XNNPACK (Android, iOS): fast fp32 / static-int8 CPU kernels.
  xnnpack('XnnpackExecutionProvider'),

  /// Android Neural Networks API (Android 8.1+; GPU / DSP / NPU drivers).
  nnapi('NnapiExecutionProvider'),

  /// Core ML (iOS / macOS; Neural Engine, GPU, CPU).
  coreml('CoreMLExecutionProvider');

  const InferenceAccelerator(this.providerName);

  /// Name in `OrtGetAvailableProviders`.
  final String providerName;

  /// Parses a `--dart-define=ORT_ACCELERATOR=...` value; null for empty / unknown.
  static InferenceAccelerator? parse(String value) {
    final v = value.trim().toLowerCase();
    for (final a in values) {
      if (a.name == v) return a;
    }
    return null;
  }
}

/// Which providers to try, in order, before plain CPU.
///
/// - Nothing asked for, or [InferenceAccelerator.cpu]: CPU only. This is the
///   default because both shipped models are *dynamically* quantised
///   (`DynamicQuantizeLinear` + `MatMulInteger` / `ConvInteger`), which XNNPACK,
///   NNAPI and Core ML do not run: they would take only a few float nodes, and the
///   copies between providers cost more than they save. Not measured on phones.
/// - Otherwise [requested], when this platform can have it ([os]: `android`, `ios`,
///   `macos`, `linux`, ...) and the runtime library lists it in [available].
///
/// The session falls back to CPU when appending the provider or creating the
/// session with it fails, so a wrong choice costs load time, not a crash.
List<InferenceAccelerator> acceleratorPlan({
  required String os,
  required Set<String> available,
  InferenceAccelerator? requested,
}) {
  if (requested == null || requested == InferenceAccelerator.cpu) {
    return const [];
  }
  final platformOk = switch (requested) {
    InferenceAccelerator.cpu => true,
    InferenceAccelerator.xnnpack => true,
    InferenceAccelerator.nnapi => os == 'android',
    InferenceAccelerator.coreml => os == 'ios' || os == 'macos',
  };
  if (!platformOk || !available.contains(requested.providerName)) {
    return const [];
  }
  return [requested];
}
