"""Builds tiny_ctc.onnx: a few-KB stand-in for a wav2vec2 CTC phoneme model.

Same interface as the real model: input `input_values` float32 [batch, samples]
(16 kHz), output `logits` float32 [batch, frames, vocab] with one frame per 320
samples (20 ms) and wav2vec2's frame count, floor((samples - 400) / 320) + 1.
Weights are random (fixed seed), so the output is meaningless; tests only check the
plumbing (shapes, vocab, log-softmax, isolates, download). Regenerate with:

    .venv/bin/python test/engine/runtime/fixtures/make_tiny_model.py
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import onnx
from onnx import TensorProto, helper, numpy_helper

HERE = Path(__file__).resolve().parent
VOCAB = ["<pad>", "<s>", "</s>", "<unk>", "t", "iː", "ð", "ə"]
CHANNELS = 8


def build(with_mask: bool) -> onnx.ModelProto:
    rng = np.random.default_rng(7)
    conv_w = (rng.standard_normal((CHANNELS, 1, 400)) * 0.05).astype(np.float32)
    proj_w = rng.standard_normal((CHANNELS, len(VOCAB))).astype(np.float32)
    proj_b = rng.standard_normal(len(VOCAB)).astype(np.float32)
    axes = numpy_helper.from_array(np.array([1], dtype=np.int64), "axes")
    nodes = [
        helper.make_node("Unsqueeze", ["input_values", "axes"], ["x3"]),
        helper.make_node("Conv", ["x3", "conv_w"], ["c"], kernel_shape=[400], strides=[320]),
        helper.make_node("Tanh", ["c"], ["h"]),
        helper.make_node("Transpose", ["h"], ["ht"], perm=[0, 2, 1]),
        helper.make_node("MatMul", ["ht", "proj_w"], ["m"]),
        helper.make_node("Add", ["m", "proj_b"], ["logits"]),
    ]
    inputs = [helper.make_tensor_value_info("input_values", TensorProto.FLOAT, ["batch", "samples"])]
    if with_mask:
        # The mask is accepted (like Hugging Face exports) and folded in as a no-op.
        inputs.append(helper.make_tensor_value_info("attention_mask", TensorProto.INT64, ["batch", "samples"]))
    graph = helper.make_graph(
        nodes,
        "tiny_ctc",
        inputs,
        [helper.make_tensor_value_info("logits", TensorProto.FLOAT, ["batch", "frames", len(VOCAB)])],
        initializer=[
            axes,
            numpy_helper.from_array(conv_w, "conv_w"),
            numpy_helper.from_array(proj_w, "proj_w"),
            numpy_helper.from_array(proj_b, "proj_b"),
        ],
    )
    model = helper.make_model(graph, opset_imports=[helper.make_opsetid("", 17)])
    model.ir_version = 8
    onnx.checker.check_model(model)
    return model


def main() -> None:
    onnx.save(build(with_mask=False), HERE / "tiny_ctc.onnx")
    onnx.save(build(with_mask=True), HERE / "tiny_ctc_mask.onnx")
    vocab = {s: i for i, s in enumerate(VOCAB)}
    (HERE / "tiny_vocab.json").write_text(json.dumps(vocab, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
