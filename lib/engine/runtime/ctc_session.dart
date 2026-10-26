import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
// The plug-in ships the native ONNX Runtime library for each platform; we call the
// stable ORT C API through its generated struct bindings, but load the library
// ourselves so the path can be overridden (host tests) and outputs read zero-copy.
// ignore: implementation_imports
import 'package:onnxruntime_v2/src/bindings/onnxruntime_bindings_generated.dart'
    as ort;

import 'cpu_cores.dart';
import 'execution_providers.dart';

/// Raw CTC logits for one clip: row-major `[frames, vocabSize]`.
class CtcLogits {
  /// Creates the logits.
  const CtcLogits(this.data, this.frames, this.vocabSize);

  /// Row-major values.
  final Float32List data;

  /// Number of frames (rows).
  final int frames;

  /// Number of symbols (columns).
  final int vocabSize;
}

/// One loaded CTC model. Synchronous: only ever used inside the inference isolate.
abstract interface class CtcModelSession {
  /// Runs the model on a normalised 16 kHz [waveform] (batch of one).
  CtcLogits run(Float32List waveform);

  /// Frees native memory. The session must not be used afterwards.
  Future<void> close();
}

/// Opens a [CtcModelSession] for the ONNX file at `modelPath`. Must be sendable to
/// the inference isolate (a top-level / static function, or a closure capturing only
/// sendable values).
typedef CtcSessionOpener = CtcModelSession Function(String modelPath);

/// `--dart-define=ORT_THREADS=n` overrides [defaultInferenceThreads] (0 or unset:
/// automatic). For measuring on phones.
const int configuredInferenceThreads = int.fromEnvironment('ORT_THREADS');

/// `--dart-define=ORT_ACCELERATOR=xnnpack|nnapi|coreml|cpu` asks for an execution
/// provider (default: CPU only, see [acceleratorPlan]). For measuring on phones.
final InferenceAccelerator? configuredAccelerator = InferenceAccelerator.parse(
  const String.fromEnvironment('ORT_ACCELERATOR'),
);

/// Default number of ONNX Runtime intra-op threads: [configuredInferenceThreads]
/// when set, else the device's big / performance cores, between 1 and 4
/// ([inferenceThreadsFor]).
int defaultInferenceThreads() => configuredInferenceThreads > 0
    ? configuredInferenceThreads
    : inferenceThreadsFor(
        os: Platform.operatingSystem,
        processors: Platform.numberOfProcessors,
      );

/// Error reported by ONNX Runtime.
class OnnxRuntimeException implements Exception {
  /// Creates the exception.
  const OnnxRuntimeException(this.message);

  /// ORT's error message.
  final String message;

  @override
  String toString() => 'OnnxRuntimeException: $message';
}

/// Opens the platform's ONNX Runtime library (shipped by the `onnxruntime_v2`
/// plug-in), or [path] when given.
ffi.DynamicLibrary openOnnxRuntimeLibrary([String? path]) {
  if (path != null) return ffi.DynamicLibrary.open(path);
  if (Platform.isIOS) return ffi.DynamicLibrary.process();
  if (Platform.isMacOS) return ffi.DynamicLibrary.open('libonnxruntime.dylib');
  if (Platform.isWindows) return ffi.DynamicLibrary.open('onnxruntime.dll');
  if (Platform.isLinux) {
    return ffi.DynamicLibrary.open('libonnxruntime.so.1.22.0');
  }
  return ffi.DynamicLibrary.open('libonnxruntime.so'); // Android
}

/// ORT C API version requested (ORT >= 1.14 provides it).
const int _apiVersion = 14;

/// The ORT C API table plus one environment, per isolate and library path.
class _Ort {
  _Ort(ffi.DynamicLibrary lib) : bindings = ort.OnnxRuntimeBindings(lib) {
    final base = bindings.OrtGetApiBase();
    final getApi = base.ref.GetApi
        .asFunction<ffi.Pointer<ort.OrtApi> Function(int)>();
    final api = getApi(_apiVersion);
    if (api == ffi.nullptr) {
      throw const OnnxRuntimeException('ONNX Runtime library is too old');
    }
    this.api = api.ref;
    using((arena) {
      final out = arena<ffi.Pointer<ort.OrtEnv>>();
      check(
        this.api.CreateEnv
            .asFunction<
              ort.OrtStatusPtr Function(
                int,
                ffi.Pointer<ffi.Char>,
                ffi.Pointer<ffi.Pointer<ort.OrtEnv>>,
              )
            >()(
          ort.OrtLoggingLevel.ORT_LOGGING_LEVEL_ERROR,
          'coach'.toNativeUtf8(allocator: arena).cast(),
          out,
        ),
      );
      env = out.value;
      final alloc = arena<ffi.Pointer<ort.OrtAllocator>>();
      check(
        this.api.GetAllocatorWithDefaultOptions
            .asFunction<
              ort.OrtStatusPtr Function(
                ffi.Pointer<ffi.Pointer<ort.OrtAllocator>>,
              )
            >()(alloc),
      );
      allocator = alloc.value;
      final mem = arena<ffi.Pointer<ort.OrtMemoryInfo>>();
      check(
        this.api.CreateCpuMemoryInfo
            .asFunction<
              ort.OrtStatusPtr Function(
                int,
                int,
                ffi.Pointer<ffi.Pointer<ort.OrtMemoryInfo>>,
              )
            >()(
          ort.OrtAllocatorType.OrtArenaAllocator,
          ort.OrtMemType.OrtMemTypeDefault,
          mem,
        ),
      );
      cpuMemory = mem.value;
    });
  }

  static final _instances = <String, _Ort>{};

  static _Ort instance(String? libraryPath) => _instances.putIfAbsent(
    libraryPath ?? '',
    () => _Ort(openOnnxRuntimeLibrary(libraryPath)),
  );

  /// The library's exported functions (provider entry points live here).
  final ort.OnnxRuntimeBindings bindings;
  late final ort.OrtApi api;
  late final ffi.Pointer<ort.OrtEnv> env;

  /// Execution providers this library was built with.
  late final Set<String> availableProviders = using((arena) {
    final out = arena<ffi.Pointer<ffi.Pointer<ffi.Char>>>();
    final count = arena<ffi.Int>();
    check(
      api.GetAvailableProviders.asFunction<
        ort.OrtStatusPtr Function(
          ffi.Pointer<ffi.Pointer<ffi.Pointer<ffi.Char>>>,
          ffi.Pointer<ffi.Int>,
        )
      >()(out, count),
    );
    final names = {
      for (var i = 0; i < count.value; i++)
        out.value[i].cast<Utf8>().toDartString(),
    };
    check(
      api.ReleaseAvailableProviders.asFunction<
        ort.OrtStatusPtr Function(ffi.Pointer<ffi.Pointer<ffi.Char>>, int)
      >()(out.value, count.value),
    );
    return names;
  });
  late final ffi.Pointer<ort.OrtAllocator> allocator;
  late final ffi.Pointer<ort.OrtMemoryInfo> cpuMemory;

  /// Throws [OnnxRuntimeException] for a non-null status (and releases it).
  void check(ort.OrtStatusPtr status) {
    if (status == ffi.nullptr) return;
    final message =
        api.GetErrorMessage.asFunction<
              ffi.Pointer<ffi.Char> Function(ort.OrtStatusPtr)
            >()(status)
            .cast<Utf8>()
            .toDartString();
    api.ReleaseStatus.asFunction<void Function(ort.OrtStatusPtr)>()(status);
    throw OnnxRuntimeException(message);
  }

  List<String> names(
    ffi.Pointer<ort.OrtSession> session, {
    required bool input,
  }) {
    return using((arena) {
      final count = arena<ffi.Size>();
      final countFn =
          (input ? api.SessionGetInputCount : api.SessionGetOutputCount)
              .asFunction<
                ort.OrtStatusPtr Function(
                  ffi.Pointer<ort.OrtSession>,
                  ffi.Pointer<ffi.Size>,
                )
              >();
      check(countFn(session, count));
      final nameFn =
          (input ? api.SessionGetInputName : api.SessionGetOutputName)
              .asFunction<
                ort.OrtStatusPtr Function(
                  ffi.Pointer<ort.OrtSession>,
                  int,
                  ffi.Pointer<ort.OrtAllocator>,
                  ffi.Pointer<ffi.Pointer<ffi.Char>>,
                )
              >();
      final free =
          api.AllocatorFree.asFunction<
            ort.OrtStatusPtr Function(
              ffi.Pointer<ort.OrtAllocator>,
              ffi.Pointer<ffi.Void>,
            )
          >();
      final out = <String>[];
      for (var i = 0; i < count.value; i++) {
        final p = arena<ffi.Pointer<ffi.Char>>();
        check(nameFn(session, i, allocator, p));
        out.add(p.value.cast<Utf8>().toDartString());
        check(free(allocator, p.value.cast()));
      }
      return out;
    });
  }
}

/// [CtcModelSession] on ONNX Runtime's C API.
///
/// Expects a Hugging Face style wav2vec2 CTC export: float input `input_values`
/// `[batch, samples]`, optional int64 `attention_mask` `[batch, samples]`, float
/// output `logits` `[batch, frames, vocab]`. Falls back to the first input / output
/// when those names are missing.
class OrtCtcModelSession implements CtcModelSession {
  OrtCtcModelSession._(
    this._ort,
    this._session,
    this._inputName,
    this._maskName,
    this._outputName,
    this.accelerator,
    this.threads,
  );

  /// Opens [modelPath] with [threads] intra-op threads (default
  /// [defaultInferenceThreads]) and, when [accelerator] (default
  /// [configuredAccelerator]) is available here ([acceleratorPlan]), that
  /// execution provider; if that fails it opens the model on the CPU provider.
  /// [libraryPath] overrides where the ONNX Runtime library is loaded from (host
  /// tests).
  factory OrtCtcModelSession.open(
    String modelPath, {
    int? threads,
    String? libraryPath,
    InferenceAccelerator? accelerator,
  }) {
    final o = _Ort.instance(libraryPath);
    final n = threads ?? defaultInferenceThreads();
    final plan = acceleratorPlan(
      os: Platform.operatingSystem,
      available: o.availableProviders,
      requested: accelerator ?? configuredAccelerator,
    );
    for (final a in plan) {
      try {
        return _openWith(o, modelPath, n, a);
      } on Object {
        // Fall back to the next provider, and finally to plain CPU.
      }
    }
    return _openWith(o, modelPath, n, InferenceAccelerator.cpu);
  }

  /// Execution providers the ONNX Runtime library at [libraryPath] (default: the
  /// platform's) was built with, e.g. `{CPUExecutionProvider, XnnpackExecutionProvider}`.
  static Set<String> availableProviders([String? libraryPath]) =>
      _Ort.instance(libraryPath).availableProviders;

  static OrtCtcModelSession _openWith(
    _Ort o,
    String modelPath,
    int threads,
    InferenceAccelerator accelerator,
  ) {
    final api = o.api;
    final session = using((arena) {
      final optionsOut = arena<ffi.Pointer<ort.OrtSessionOptions>>();
      o.check(
        api.CreateSessionOptions.asFunction<
          ort.OrtStatusPtr Function(
            ffi.Pointer<ffi.Pointer<ort.OrtSessionOptions>>,
          )
        >()(optionsOut),
      );
      final options = optionsOut.value;
      ffi.Pointer<ffi.Char> str(String v) =>
          v.toNativeUtf8(allocator: arena).cast();
      try {
        final setThreads =
            api.SetIntraOpNumThreads.asFunction<
              ort.OrtStatusPtr Function(ffi.Pointer<ort.OrtSessionOptions>, int)
            >();
        o.check(setThreads(options, threads));
        o.check(
          api.SetInterOpNumThreads.asFunction<
            ort.OrtStatusPtr Function(ffi.Pointer<ort.OrtSessionOptions>, int)
          >()(options, 1),
        );
        o.check(
          api.SetSessionGraphOptimizationLevel.asFunction<
            ort.OrtStatusPtr Function(ffi.Pointer<ort.OrtSessionOptions>, int)
          >()(options, ort.GraphOptimizationLevel.ORT_ENABLE_ALL),
        );
        final config =
            api.AddSessionConfigEntry.asFunction<
              ort.OrtStatusPtr Function(
                ffi.Pointer<ort.OrtSessionOptions>,
                ffi.Pointer<ffi.Char>,
                ffi.Pointer<ffi.Char>,
              )
            >();
        switch (accelerator) {
          case InferenceAccelerator.cpu:
            break;
          case InferenceAccelerator.xnnpack:
            // XNNPACK brings its own thread pool: keep ORT's from spinning
            // against it (ONNX Runtime's XNNPACK guidance).
            o.check(
              config(options, str('session.intra_op.allow_spinning'), str('0')),
            );
            final keys = arena<ffi.Pointer<ffi.Char>>()
              ..value = str('intra_op_num_threads');
            final values = arena<ffi.Pointer<ffi.Char>>()
              ..value = str('$threads');
            o.check(
              api.SessionOptionsAppendExecutionProvider.asFunction<
                ort.OrtStatusPtr Function(
                  ffi.Pointer<ort.OrtSessionOptions>,
                  ffi.Pointer<ffi.Char>,
                  ffi.Pointer<ffi.Pointer<ffi.Char>>,
                  ffi.Pointer<ffi.Pointer<ffi.Char>>,
                  int,
                )
              >()(options, str('XNNPACK'), keys, values, 1),
            );
          case InferenceAccelerator.nnapi:
            o.check(
              o.bindings.OrtSessionOptionsAppendExecutionProvider_Nnapi(
                options,
                0,
              ),
            );
          case InferenceAccelerator.coreml:
            o.check(
              o.bindings.OrtSessionOptionsAppendExecutionProvider_CoreML(
                options,
                0,
              ),
            );
        }
        final out = arena<ffi.Pointer<ort.OrtSession>>();
        o.check(
          api.CreateSession.asFunction<
            ort.OrtStatusPtr Function(
              ffi.Pointer<ort.OrtEnv>,
              ffi.Pointer<ffi.Char>,
              ffi.Pointer<ort.OrtSessionOptions>,
              ffi.Pointer<ffi.Pointer<ort.OrtSession>>,
            )
          >()(o.env, str(modelPath), options, out),
        );
        return out.value;
      } finally {
        api.ReleaseSessionOptions.asFunction<
          void Function(ffi.Pointer<ort.OrtSessionOptions>)
        >()(options);
      }
    });
    final inputs = o.names(session, input: true);
    final outputs = o.names(session, input: false);
    final input = inputs.contains('input_values')
        ? 'input_values'
        : inputs.first;
    final mask = inputs.contains('attention_mask') ? 'attention_mask' : null;
    final output = outputs.contains('logits') ? 'logits' : outputs.first;
    return OrtCtcModelSession._(
      o,
      session,
      input,
      mask,
      output,
      accelerator,
      threads,
    );
  }

  /// The execution provider the session runs on (besides CPU).
  final InferenceAccelerator accelerator;

  /// ONNX Runtime intra-op threads.
  final int threads;

  /// [CtcSessionOpener] with default settings.
  static CtcModelSession opener(String modelPath) =>
      OrtCtcModelSession.open(modelPath);

  final _Ort _ort;
  ffi.Pointer<ort.OrtSession>? _session;
  final String _inputName;
  final String? _maskName;
  final String _outputName;

  ffi.Pointer<ort.OrtValue> _tensor(
    Arena arena,
    ffi.Pointer<ffi.Void> data,
    int bytes,
    int n,
    int type,
  ) {
    final shape = arena<ffi.Int64>(2)
      ..[0] = 1
      ..[1] = n;
    final out = arena<ffi.Pointer<ort.OrtValue>>();
    _ort.check(
      _ort.api.CreateTensorWithDataAsOrtValue
          .asFunction<
            ort.OrtStatusPtr Function(
              ffi.Pointer<ort.OrtMemoryInfo>,
              ffi.Pointer<ffi.Void>,
              int,
              ffi.Pointer<ffi.Int64>,
              int,
              int,
              ffi.Pointer<ffi.Pointer<ort.OrtValue>>,
            )
          >()(_ort.cpuMemory, data, bytes, shape, 2, type, out),
    );
    return out.value;
  }

  @override
  CtcLogits run(Float32List waveform) {
    final session = _session;
    if (session == null) throw StateError('Session closed');
    final api = _ort.api;
    final release =
        api.ReleaseValue.asFunction<void Function(ffi.Pointer<ort.OrtValue>)>();
    return using((arena) {
      final n = waveform.length;
      final hasMask = _maskName != null;
      final names = arena<ffi.Pointer<ffi.Char>>(hasMask ? 2 : 1);
      final values = arena<ffi.Pointer<ort.OrtValue>>(hasMask ? 2 : 1);
      final samples = arena<ffi.Float>(n);
      samples.asTypedList(n).setAll(0, waveform);
      names[0] = _inputName.toNativeUtf8(allocator: arena).cast();
      values[0] = _tensor(
        arena,
        samples.cast(),
        n * 4,
        n,
        ort.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
      );
      if (hasMask) {
        final mask = arena<ffi.Int64>(n);
        mask.asTypedList(n).fillRange(0, n, 1);
        names[1] = _maskName.toNativeUtf8(allocator: arena).cast();
        values[1] = _tensor(
          arena,
          mask.cast(),
          n * 8,
          n,
          ort.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64,
        );
      }
      final outName = arena<ffi.Pointer<ffi.Char>>()
        ..value = _outputName.toNativeUtf8(allocator: arena).cast();
      final output = arena<ffi.Pointer<ort.OrtValue>>()..value = ffi.nullptr;
      try {
        _ort.check(
          api.Run.asFunction<
            ort.OrtStatusPtr Function(
              ffi.Pointer<ort.OrtSession>,
              ffi.Pointer<ort.OrtRunOptions>,
              ffi.Pointer<ffi.Pointer<ffi.Char>>,
              ffi.Pointer<ffi.Pointer<ort.OrtValue>>,
              int,
              ffi.Pointer<ffi.Pointer<ffi.Char>>,
              int,
              ffi.Pointer<ffi.Pointer<ort.OrtValue>>,
            )
          >()(
            session,
            ffi.nullptr,
            names,
            values,
            hasMask ? 2 : 1,
            outName,
            1,
            output,
          ),
        );
        return _readLogits(arena, output.value);
      } finally {
        release(values[0]);
        if (hasMask) release(values[1]);
        if (output.value != ffi.nullptr) release(output.value);
      }
    });
  }

  CtcLogits _readLogits(Arena arena, ffi.Pointer<ort.OrtValue> value) {
    final api = _ort.api;
    final infoOut = arena<ffi.Pointer<ort.OrtTensorTypeAndShapeInfo>>();
    _ort.check(
      api.GetTensorTypeAndShape.asFunction<
        ort.OrtStatusPtr Function(
          ffi.Pointer<ort.OrtValue>,
          ffi.Pointer<ffi.Pointer<ort.OrtTensorTypeAndShapeInfo>>,
        )
      >()(value, infoOut),
    );
    final info = infoOut.value;
    final List<int> dims;
    try {
      final count = arena<ffi.Size>();
      _ort.check(
        api.GetDimensionsCount.asFunction<
          ort.OrtStatusPtr Function(
            ffi.Pointer<ort.OrtTensorTypeAndShapeInfo>,
            ffi.Pointer<ffi.Size>,
          )
        >()(info, count),
      );
      final dimsPtr = arena<ffi.Int64>(math.max(1, count.value));
      _ort.check(
        api.GetDimensions.asFunction<
          ort.OrtStatusPtr Function(
            ffi.Pointer<ort.OrtTensorTypeAndShapeInfo>,
            ffi.Pointer<ffi.Int64>,
            int,
          )
        >()(info, dimsPtr, count.value),
      );
      final type = arena<ffi.Int32>();
      _ort.check(
        api.GetTensorElementType.asFunction<
          ort.OrtStatusPtr Function(
            ffi.Pointer<ort.OrtTensorTypeAndShapeInfo>,
            ffi.Pointer<ffi.Int32>,
          )
        >()(info, type),
      );
      if (type.value !=
          ort.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT) {
        throw OnnxRuntimeException(
          'logits are not float32 (type ${type.value})',
        );
      }
      dims = dimsPtr.asTypedList(count.value).toList();
    } finally {
      api.ReleaseTensorTypeAndShapeInfo.asFunction<
        void Function(ffi.Pointer<ort.OrtTensorTypeAndShapeInfo>)
      >()(info);
    }
    if (dims.length != 3 || dims[0] != 1) {
      throw OnnxRuntimeException(
        'Expected logits [1, frames, vocab], got $dims',
      );
    }
    final frames = dims[1];
    final vocab = dims[2];
    final dataOut = arena<ffi.Pointer<ffi.Void>>();
    _ort.check(
      api.GetTensorMutableData.asFunction<
        ort.OrtStatusPtr Function(
          ffi.Pointer<ort.OrtValue>,
          ffi.Pointer<ffi.Pointer<ffi.Void>>,
        )
      >()(value, dataOut),
    );
    final data = Float32List.fromList(
      dataOut.value.cast<ffi.Float>().asTypedList(frames * vocab),
    );
    return CtcLogits(data, frames, vocab);
  }

  @override
  Future<void> close() async {
    final session = _session;
    _session = null;
    if (session == null) return;
    _ort.api.ReleaseSession
        .asFunction<void Function(ffi.Pointer<ort.OrtSession>)>()(session);
  }
}
