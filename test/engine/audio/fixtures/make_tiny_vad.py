"""Builds tiny_vad.onnx: a few-hundred-byte stand-in with Silero VAD v5/v6's interface.

Inputs `input` float32 [1, 576] (64 context + 512 samples), `state` float32 [2, 1, 128],
`sr` int64 scalar; outputs `output` float32 [1, 1] and `stateN` float32 [2, 1, 128].
The "probability" is an energy detector, sigmoid((rms_dBFS + 40) / 3), so speech
fixtures score high and silence low; `stateN` = state + mean power, so tests can see
that state is carried between chunks. Tests use it to exercise the ONNX Runtime
plumbing in CI, where the real 2.3 MB model is not fetched. Regenerate with:

    .venv/bin/python test/engine/audio/fixtures/make_tiny_vad.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import onnx
from onnx import TensorProto, helper, numpy_helper

HERE = Path(__file__).resolve().parent


def build() -> onnx.ModelProto:
    c = {
        "eps": np.array(1e-10, np.float32),
        "ten_over_ln10": np.array(10 / np.log(10), np.float32),
        "forty": np.array(40.0, np.float32),
        "third": np.array(1 / 3, np.float32),
        "zero": np.array(0.0, np.float32),
    }
    nodes = [
        helper.make_node("Mul", ["input", "input"], ["sq"]),
        helper.make_node("ReduceMean", ["sq"], ["power"], axes=[1], keepdims=1),
        helper.make_node("Add", ["power", "eps"], ["p1"]),
        helper.make_node("Log", ["p1"], ["ln"]),
        helper.make_node("Mul", ["ln", "ten_over_ln10"], ["db"]),
        helper.make_node("Add", ["db", "forty"], ["shifted"]),
        helper.make_node("Mul", ["shifted", "third"], ["z"]),
        helper.make_node("Cast", ["sr"], ["srf"], to=TensorProto.FLOAT),
        helper.make_node("Mul", ["srf", "zero"], ["srz"]),
        helper.make_node("Add", ["z", "srz"], ["z2"]),
        helper.make_node("Sigmoid", ["z2"], ["output"]),
        helper.make_node("Add", ["state", "power"], ["stateN"]),
    ]
    graph = helper.make_graph(
        nodes,
        "tiny_vad",
        [
            helper.make_tensor_value_info("input", TensorProto.FLOAT, [None, None]),
            helper.make_tensor_value_info("state", TensorProto.FLOAT, [2, None, 128]),
            helper.make_tensor_value_info("sr", TensorProto.INT64, []),
        ],
        [
            helper.make_tensor_value_info("output", TensorProto.FLOAT, [None, 1]),
            helper.make_tensor_value_info("stateN", TensorProto.FLOAT, [2, None, 128]),
        ],
        initializer=[numpy_helper.from_array(v, k) for k, v in c.items()],
    )
    model = helper.make_model(graph, opset_imports=[helper.make_opsetid("", 16)])
    model.ir_version = 8
    onnx.checker.check_model(model)
    return model


def build_bad() -> onnx.ModelProto:
    """A model with the wrong inputs, for the error path."""
    graph = helper.make_graph(
        [helper.make_node("Identity", ["x"], ["y"])],
        "not_vad",
        [helper.make_tensor_value_info("x", TensorProto.FLOAT, [1])],
        [helper.make_tensor_value_info("y", TensorProto.FLOAT, [1])],
    )
    model = helper.make_model(graph, opset_imports=[helper.make_opsetid("", 16)])
    model.ir_version = 8
    return model


if __name__ == "__main__":
    onnx.save(build(), HERE / "tiny_vad.onnx")
    onnx.save(build_bad(), HERE / "not_vad.onnx")
    print("wrote tiny_vad.onnx, not_vad.onnx")
