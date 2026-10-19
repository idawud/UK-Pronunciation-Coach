"""Export a wav2vec2 CTC phoneme model to ONNX (opset 17) and quantise it to int8.

Graph contract (what A2 loads):
  input  `input_values` float32 [batch, samples]: 16 kHz mono, zero-mean / unit-variance
  output `logits`       float32 [batch, frames, vocab]: raw CTC logits, 20 ms frames
         (A2 applies log_softmax; column i is token vocab_list(vocab.json)[i]; blank `<pad>`)

    python -m tools.models.export_onnx --model facebook/wav2vec2-lv-60-espeak-cv-ft \
        --out tools/models/release/full --work tools/models/work/full
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np
import onnx
import onnxruntime as ort
import torch
from onnxruntime.quantization import QuantType, quantize_dynamic

FULL_MODEL = "facebook/wav2vec2-lv-60-espeak-cv-ft"
FULL_REVISION = "ae45363bf3413b374fecd9dc8bc1df0e24c3b7f4"  # pinned hub commit
OPSET = 17
INPUT = "input_values"
OUTPUT = "logits"
# Default: only MatMul/Gemm weights are quantised (most of wav2vec2's parameters;
# MatMulInteger runs on every ONNX Runtime build). Adding Conv also quantises the conv
# feature encoder and positional conv (ConvInteger): about 27 MB smaller for the base
# model, which the light tier needs to stay under 100 MB.
QUANT_OPS = ("MatMul", "Gemm")
QUANT_OPS_WITH_CONV = ("MatMul", "Gemm", "Conv")


class LogitsOnly(torch.nn.Module):
    """Wraps a HF Wav2Vec2ForCTC so the traced graph has one tensor in and one out."""

    def __init__(self, model: torch.nn.Module):
        super().__init__()
        self.model = model

    def forward(self, input_values: torch.Tensor) -> torch.Tensor:
        return self.model(input_values).logits


def load_model(name_or_path: str | Path):
    """(Wav2Vec2ForCTC in eval mode, vocab dict) from a hub id or a local directory."""
    from transformers import Wav2Vec2ForCTC

    revision = FULL_REVISION if str(name_or_path) == FULL_MODEL else None
    model = Wav2Vec2ForCTC.from_pretrained(str(name_or_path), revision=revision).eval()
    local = Path(name_or_path)
    if local.is_dir():
        vocab_path = local / "vocab.json"
    else:  # pragma: no cover - needs the network
        from huggingface_hub import hf_hub_download

        vocab_path = Path(hf_hub_download(str(name_or_path), "vocab.json", revision=revision))
    vocab = json.loads(vocab_path.read_text(encoding="utf-8"))
    if len(vocab) != model.config.vocab_size:
        raise ValueError(f"vocab.json has {len(vocab)} tokens, model has {model.config.vocab_size}")
    return model, vocab


def export_fp32(model: torch.nn.Module, path: Path, opset: int = OPSET, seconds: float = 2.0):
    """Traces [model] to an fp32 ONNX file with dynamic batch and length axes."""
    path.parent.mkdir(parents=True, exist_ok=True)
    wrapper = LogitsOnly(model).eval()
    dummy = torch.randn(1, int(16000 * seconds))
    with torch.no_grad():
        torch.onnx.export(
            wrapper,
            (dummy,),
            str(path),
            input_names=[INPUT],
            output_names=[OUTPUT],
            opset_version=opset,
            dynamo=False,
            dynamic_axes={INPUT: {0: "batch", 1: "samples"}, OUTPUT: {0: "batch", 1: "frames"}},
        )
    model.eval()  # export restores the wrapper's mode; keep the caller's model in eval
    onnx.checker.check_model(str(path))
    return path


def quantize_int8(fp32_path: Path, int8_path: Path, ops: tuple[str, ...] = QUANT_OPS) -> Path:
    """Dynamic int8 quantisation of [ops] (weights int8, activations quantised at run time)."""
    int8_path.parent.mkdir(parents=True, exist_ok=True)
    quantize_dynamic(
        model_input=str(fp32_path),
        model_output=str(int8_path),
        op_types_to_quantize=list(ops),
        weight_type=QuantType.QInt8,
        per_channel=False,
    )
    onnx.checker.check_model(str(int8_path))
    return int8_path


def onnx_opset(path: Path) -> int:
    """Default-domain opset of an ONNX file."""
    model = onnx.load(str(path), load_external_data=False)
    return next(o.version for o in model.opset_import if o.domain in ("", "ai.onnx"))


def session(path: Path, threads: int = 0) -> ort.InferenceSession:
    """CPU ONNX Runtime session (threads=0 lets ORT pick)."""
    opts = ort.SessionOptions()
    opts.intra_op_num_threads = threads
    opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
    return ort.InferenceSession(str(path), opts, providers=["CPUExecutionProvider"])


def onnx_logits(sess: ort.InferenceSession, audio: np.ndarray) -> np.ndarray:
    """[frames, vocab] logits for one normalised 16 kHz clip."""
    return sess.run([OUTPUT], {INPUT: audio[None, :].astype(np.float32)})[0][0]


def torch_logits(model: torch.nn.Module, audio: np.ndarray) -> np.ndarray:
    """[frames, vocab] PyTorch logits for one normalised 16 kHz clip."""
    with torch.no_grad():
        return model(torch.from_numpy(audio[None, :].astype(np.float32))).logits[0].numpy()


def export_tier(
    model,
    vocab: dict[str, int],
    out_dir: Path,
    work_dir: Path,
    opset: int = OPSET,
    quant_ops: tuple[str, ...] = QUANT_OPS,
) -> dict:
    """Writes out_dir/model.onnx (int8) and out_dir/vocab.json; the fp32 export stays in
    work_dir. Returns a small summary (paths, sizes, export seconds)."""
    out_dir.mkdir(parents=True, exist_ok=True)
    fp32 = work_dir / "model.fp32.onnx"
    t0 = time.perf_counter()
    export_fp32(model, fp32, opset)
    t1 = time.perf_counter()
    int8 = quantize_int8(fp32, out_dir / "model.onnx", quant_ops)
    t2 = time.perf_counter()
    (out_dir / "vocab.json").write_text(
        json.dumps(vocab, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    return {
        "fp32_path": str(fp32),
        "int8_path": str(int8),
        "fp32_bytes": fp32.stat().st_size,
        "int8_bytes": int8.stat().st_size,
        "export_seconds": round(t1 - t0, 1),
        "quantise_seconds": round(t2 - t1, 1),
        "opset": onnx_opset(int8),
        "quant_ops": list(quant_ops),
        "vocab_size": len(vocab),
        "blank_index": vocab["<pad>"],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Export a wav2vec2 CTC model to int8 ONNX")
    parser.add_argument("--model", required=True, help="hub id or local HF model directory")
    parser.add_argument("--out", type=Path, required=True, help="release tier folder")
    parser.add_argument("--work", type=Path, required=True, help="scratch folder (fp32 export)")
    parser.add_argument("--opset", type=int, default=OPSET)
    parser.add_argument("--quantise-conv", action="store_true", help="also quantise Conv")
    args = parser.parse_args(argv)
    model, vocab = load_model(args.model)
    ops = QUANT_OPS_WITH_CONV if args.quantise_conv else QUANT_OPS
    summary = export_tier(model, vocab, args.out, args.work, args.opset, ops)
    args.work.mkdir(parents=True, exist_ok=True)
    (args.work / "export.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
