import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
// The onnxruntime_v2 plug-in (MIT) ships the native ONNX Runtime library; A2 uses
// the same library and the same stable C API, so the app carries a single copy of
// ONNX Runtime. This file talks to the C API directly (it must not import A2's
// lib/engine/runtime/).
// ignore: implementation_imports
import 'package:onnxruntime_v2/src/bindings/onnxruntime_bindings_generated.dart'
    as ort;

import 'vad.dart';

/// Error reported by ONNX Runtime while running the VAD.
class VadRuntimeException implements Exception {
  /// Creates the exception.
  const VadRuntimeException(this.message);

  /// ONNX Runtime's message.
  final String message;

  @override
  String toString() => 'VadRuntimeException: $message';
}

/// Opens the platform's ONNX Runtime library, or [path] when given.
ffi.DynamicLibrary openVadOnnxRuntime([String? path]) {
  if (path != null) return ffi.DynamicLibrary.open(path);
  if (Platform.isIOS) return ffi.DynamicLibrary.process();
  if (Platform.isMacOS) return ffi.DynamicLibrary.open('libonnxruntime.dylib');
  if (Platform.isWindows) return ffi.DynamicLibrary.open('onnxruntime.dll');
  if (Platform.isLinux) {
    return ffi.DynamicLibrary.open('libonnxruntime.so.1.22.0');
  }
  return ffi.DynamicLibrary.open('libonnxruntime.so'); // Android
}

const int _apiVersion = 14;
const int _sampleRate = 16000;
const int _chunk = 512;
const int _context = 64;
const int _stateSize = 2 * 1 * 128;

typedef _StatusFn = ort.OrtStatusPtr Function();

/// ORT API table and environment, one per isolate and library path.
class _Api {
  _Api(ffi.DynamicLibrary lib) {
    final base = ort.OnnxRuntimeBindings(lib).OrtGetApiBase();
    final getApi = base.ref.GetApi
        .asFunction<ffi.Pointer<ort.OrtApi> Function(int)>();
    final p = getApi(_apiVersion);
    if (p == ffi.nullptr) {
      throw const VadRuntimeException('ONNX Runtime library is too old');
    }
    api = p.ref;
    env = using((arena) {
      final out = arena<ffi.Pointer<ort.OrtEnv>>();
      check(
        () =>
            api.CreateEnv.asFunction<
              ort.OrtStatusPtr Function(
                int,
                ffi.Pointer<ffi.Char>,
                ffi.Pointer<ffi.Pointer<ort.OrtEnv>>,
              )
            >()(
              ort.OrtLoggingLevel.ORT_LOGGING_LEVEL_ERROR,
              'coach-vad'.toNativeUtf8(allocator: arena).cast(),
              out,
            ),
      );
      return out.value;
    });
    cpu = using((arena) {
      final out = arena<ffi.Pointer<ort.OrtMemoryInfo>>();
      check(
        () =>
            api.CreateCpuMemoryInfo.asFunction<
              ort.OrtStatusPtr Function(
                int,
                int,
                ffi.Pointer<ffi.Pointer<ort.OrtMemoryInfo>>,
              )
            >()(
              ort.OrtAllocatorType.OrtArenaAllocator,
              ort.OrtMemType.OrtMemTypeDefault,
              out,
            ),
      );
      return out.value;
    });
  }

  static final _cache = <String, _Api>{};

  static _Api instance(String? path) =>
      _cache.putIfAbsent(path ?? '', () => _Api(openVadOnnxRuntime(path)));

  late final ort.OrtApi api;
  late final ffi.Pointer<ort.OrtEnv> env;
  late final ffi.Pointer<ort.OrtMemoryInfo> cpu;

  void check(_StatusFn call) {
    final status = call();
    if (status == ffi.nullptr) return;
    final message =
        api.GetErrorMessage.asFunction<
              ffi.Pointer<ffi.Char> Function(ort.OrtStatusPtr)
            >()(status)
            .cast<Utf8>()
            .toDartString();
    api.ReleaseStatus.asFunction<void Function(ort.OrtStatusPtr)>()(status);
    throw VadRuntimeException(message);
  }

  List<String> names(ffi.Pointer<ort.OrtSession> s, {required bool input}) =>
      using((arena) {
        final count = arena<ffi.Size>();
        check(
          () => (input ? api.SessionGetInputCount : api.SessionGetOutputCount)
              .asFunction<
                ort.OrtStatusPtr Function(
                  ffi.Pointer<ort.OrtSession>,
                  ffi.Pointer<ffi.Size>,
                )
              >()(s, count),
        );
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
        final alloc = arena<ffi.Pointer<ort.OrtAllocator>>();
        check(
          () =>
              api.GetAllocatorWithDefaultOptions.asFunction<
                ort.OrtStatusPtr Function(
                  ffi.Pointer<ffi.Pointer<ort.OrtAllocator>>,
                )
              >()(alloc),
        );
        final free =
            api.AllocatorFree.asFunction<
              ort.OrtStatusPtr Function(
                ffi.Pointer<ort.OrtAllocator>,
                ffi.Pointer<ffi.Void>,
              )
            >();
        return [
          for (var i = 0; i < count.value; i++)
            () {
              final p = arena<ffi.Pointer<ffi.Char>>();
              check(() => nameFn(s, i, alloc.value, p));
              final name = p.value.cast<Utf8>().toDartString();
              check(() => free(alloc.value, p.value.cast()));
              return name;
            }(),
        ];
      });

  ffi.Pointer<ort.OrtValue> tensor(
    ffi.Pointer<ffi.Void> data,
    int bytes,
    List<int> shape,
    int type,
  ) => using((arena) {
    final dims = arena<ffi.Int64>(shape.isEmpty ? 1 : shape.length);
    for (var i = 0; i < shape.length; i++) {
      dims[i] = shape[i];
    }
    final out = arena<ffi.Pointer<ort.OrtValue>>();
    check(
      () =>
          api.CreateTensorWithDataAsOrtValue.asFunction<
            ort.OrtStatusPtr Function(
              ffi.Pointer<ort.OrtMemoryInfo>,
              ffi.Pointer<ffi.Void>,
              int,
              ffi.Pointer<ffi.Int64>,
              int,
              int,
              ffi.Pointer<ffi.Pointer<ort.OrtValue>>,
            )
          >()(cpu, data, bytes, dims, shape.length, type, out),
    );
    return out.value;
  });

  ffi.Pointer<ffi.Float> floatData(ffi.Pointer<ort.OrtValue> v) =>
      using((arena) {
        final out = arena<ffi.Pointer<ffi.Void>>();
        check(
          () =>
              api.GetTensorMutableData.asFunction<
                ort.OrtStatusPtr Function(
                  ffi.Pointer<ort.OrtValue>,
                  ffi.Pointer<ffi.Pointer<ffi.Void>>,
                )
              >()(v, out),
        );
        return out.value.cast<ffi.Float>();
      });

  void release(ffi.Pointer<ort.OrtValue> v) {
    if (v == ffi.nullptr) return;
    api.ReleaseValue.asFunction<void Function(ffi.Pointer<ort.OrtValue>)>()(v);
  }
}

/// Silero VAD (v5/v6 ONNX, MIT) on ONNX Runtime's C API, 16 kHz, 512-sample chunks.
///
/// Model I/O: `input` float [1, 64 + 512] (64 samples of context from the previous
/// chunk, as Silero's own wrapper does), `state` float [2, 1, 128], `sr` int64
/// scalar; outputs `output` float [1, 1] (speech probability) and `stateN`.
/// Synchronous; one instance per isolate.
class SileroVadModel implements SpeechProbabilityModel {
  SileroVadModel._(this._api, this._session) {
    final inputs = _api.names(_session, input: true);
    final outputs = _api.names(_session, input: false);
    for (final n in const ['input', 'state', 'sr']) {
      if (!inputs.contains(n)) {
        close();
        throw VadRuntimeException(
          'Not a Silero VAD v5+ model: inputs are $inputs',
        );
      }
    }
    if (outputs.length < 2) {
      close();
      throw VadRuntimeException('Expected 2 outputs, got $outputs');
    }
    _outNames = outputs;
    _input = malloc<ffi.Float>(_context + _chunk);
    _state = malloc<ffi.Float>(_stateSize);
    _sr = malloc<ffi.Int64>()..value = _sampleRate;
    _inValues = malloc<ffi.Pointer<ort.OrtValue>>(3);
    _inNames = malloc<ffi.Pointer<ffi.Char>>(3);
    _outNamePtrs = malloc<ffi.Pointer<ffi.Char>>(2);
    _outValues = malloc<ffi.Pointer<ort.OrtValue>>(2);
    const f = ort.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT;
    const i64 =
        ort.ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64;
    _inValues[0] = _api.tensor(_input.cast(), (_context + _chunk) * 4, [
      1,
      _context + _chunk,
    ], f);
    _inValues[1] = _api.tensor(_state.cast(), _stateSize * 4, [2, 1, 128], f);
    _inValues[2] = _api.tensor(_sr.cast(), 8, const [], i64);
    _inNames[0] = 'input'.toNativeUtf8().cast();
    _inNames[1] = 'state'.toNativeUtf8().cast();
    _inNames[2] = 'sr'.toNativeUtf8().cast();
    _outNamePtrs[0] = outputs[0].toNativeUtf8().cast();
    _outNamePtrs[1] = outputs[1].toNativeUtf8().cast();
    _ready = true;
    reset();
  }

  /// Loads the model from ONNX [bytes]. [libraryPath] overrides where ONNX Runtime
  /// is loaded from (host tests).
  factory SileroVadModel.fromBytes(Uint8List bytes, {String? libraryPath}) {
    final api = _Api.instance(libraryPath);
    final session = using((arena) {
      final options = _options(api, arena);
      try {
        final data = arena<ffi.Uint8>(bytes.length);
        data.asTypedList(bytes.length).setAll(0, bytes);
        final out = arena<ffi.Pointer<ort.OrtSession>>();
        api.check(
          () => api.api.CreateSessionFromArray
              .asFunction<
                ort.OrtStatusPtr Function(
                  ffi.Pointer<ort.OrtEnv>,
                  ffi.Pointer<ffi.Void>,
                  int,
                  ffi.Pointer<ort.OrtSessionOptions>,
                  ffi.Pointer<ffi.Pointer<ort.OrtSession>>,
                )
              >()(api.env, data.cast(), bytes.length, options, out),
        );
        return out.value;
      } finally {
        api.api.ReleaseSessionOptions
            .asFunction<void Function(ffi.Pointer<ort.OrtSessionOptions>)>()(
          options,
        );
      }
    });
    return SileroVadModel._(api, session);
  }

  static ffi.Pointer<ort.OrtSessionOptions> _options(_Api api, Arena arena) {
    final out = arena<ffi.Pointer<ort.OrtSessionOptions>>();
    api.check(
      () => api.api.CreateSessionOptions
          .asFunction<
            ort.OrtStatusPtr Function(
              ffi.Pointer<ffi.Pointer<ort.OrtSessionOptions>>,
            )
          >()(out),
    );
    final set = api.api.SetIntraOpNumThreads
        .asFunction<
          ort.OrtStatusPtr Function(ffi.Pointer<ort.OrtSessionOptions>, int)
        >();
    // A 2 MB model on 32 ms chunks: one thread is fastest and leaves the cores
    // to the UI and the phoneme model.
    api.check(() => set(out.value, 1));
    api.check(
      () => api.api.SetInterOpNumThreads
          .asFunction<
            ort.OrtStatusPtr Function(ffi.Pointer<ort.OrtSessionOptions>, int)
          >()(out.value, 1),
    );
    return out.value;
  }

  final _Api _api;
  ffi.Pointer<ort.OrtSession> _session;
  late final List<String> _outNames;
  late final ffi.Pointer<ffi.Float> _input;
  late final ffi.Pointer<ffi.Float> _state;
  late final ffi.Pointer<ffi.Int64> _sr;
  late final ffi.Pointer<ffi.Pointer<ort.OrtValue>> _inValues;
  late final ffi.Pointer<ffi.Pointer<ffi.Char>> _inNames;
  late final ffi.Pointer<ffi.Pointer<ffi.Char>> _outNamePtrs;
  late final ffi.Pointer<ffi.Pointer<ort.OrtValue>> _outValues;
  bool _ready = false;

  /// Names of the model's outputs (probability first, then state).
  List<String> get outputNames => _outNames;

  @override
  int get chunkSamples => _chunk;

  @override
  double process(Float32List chunk) {
    if (_session == ffi.nullptr) throw StateError('SileroVadModel closed');
    if (chunk.length != _chunk) {
      throw ArgumentError.value(chunk.length, 'chunk', 'must be $_chunk');
    }
    final input = _input.asTypedList(_context + _chunk);
    input.setRange(_context, _context + _chunk, chunk);
    _outValues[0] = ffi.nullptr;
    _outValues[1] = ffi.nullptr;
    try {
      _api.check(
        () =>
            _api.api.Run
                .asFunction<
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
              _session,
              ffi.nullptr,
              _inNames,
              _inValues,
              3,
              _outNamePtrs,
              2,
              _outValues,
            ),
      );
      final p = _api.floatData(_outValues[0])[0];
      final next = _api.floatData(_outValues[1]).asTypedList(_stateSize);
      _state.asTypedList(_stateSize).setAll(0, next);
      // The last 64 samples become the next chunk's context.
      input.setRange(0, _context, input, _chunk);
      return p.clamp(0.0, 1.0);
    } finally {
      _api.release(_outValues[0]);
      _api.release(_outValues[1]);
    }
  }

  @override
  void reset() {
    if (!_ready) return;
    _input.asTypedList(_context + _chunk).fillRange(0, _context + _chunk, 0);
    _state.asTypedList(_stateSize).fillRange(0, _stateSize, 0);
  }

  @override
  void close() {
    final s = _session;
    if (s == ffi.nullptr) return;
    _session = ffi.nullptr;
    if (_ready) {
      for (var i = 0; i < 3; i++) {
        _api.release(_inValues[i]);
        malloc.free(_inNames[i]);
      }
      malloc
        ..free(_outNamePtrs[0])
        ..free(_outNamePtrs[1])
        ..free(_input)
        ..free(_state)
        ..free(_sr)
        ..free(_inValues)
        ..free(_inNames)
        ..free(_outNamePtrs)
        ..free(_outValues);
    }
    _api.api.ReleaseSession
        .asFunction<void Function(ffi.Pointer<ort.OrtSession>)>()(s);
  }
}

/// [VadBackend] for Silero VAD. Streaming runs on the caller's isolate (about
/// 0.1-0.5 ms per 32 ms chunk); whole-clip [analyse] runs in a short-lived
/// background isolate so the UI does not stall on long clips.
class SileroVadBackend implements VadBackend {
  /// Creates the backend for the Silero ONNX [modelBytes]. Throws
  /// [VadRuntimeException] now if the model does not load.
  SileroVadBackend(this.modelBytes, {this.libraryPath}) {
    open().close();
  }

  /// The ONNX model.
  final Uint8List modelBytes;

  /// ONNX Runtime library override (host tests).
  final String? libraryPath;

  @override
  String get name => 'silero';

  @override
  int get chunkSamples => _chunk;

  @override
  SpeechProbabilityModel open() =>
      SileroVadModel.fromBytes(modelBytes, libraryPath: libraryPath);

  @override
  Future<List<double>> analyse(Float32List samples) {
    final bytes = modelBytes;
    final lib = libraryPath;
    return Isolate.run(() {
      final model = SileroVadModel.fromBytes(bytes, libraryPath: lib);
      try {
        return probabilitiesOf(model, samples);
      } finally {
        model.close();
      }
    });
  }
}
