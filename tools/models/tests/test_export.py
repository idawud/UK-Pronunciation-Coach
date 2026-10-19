"""End-to-end export of a tiny random wav2vec2: ONNX opset 17, int8 close to fp32."""

import json

import numpy as np
import pytest
import torch

from tools.models import evaluate as ev
from tools.models import export_onnx as ex
from tools.models import manifest as mf
from tools.models.audio import normalise
from tools.models.tests.conftest import VOCAB, tone


def test_export_writes_int8_model_and_vocab(tiny_export):
    release, work, summary = tiny_export
    assert (release / "model.onnx").exists()
    assert json.loads((release / "vocab.json").read_text(encoding="utf-8")) == VOCAB
    assert (work / "model.fp32.onnx").exists()
    assert summary["opset"] == ex.OPSET == 17
    assert summary["vocab_size"] == len(VOCAB)
    assert summary["blank_index"] == 0
    assert summary["quant_ops"] == list(ex.QUANT_OPS)
    assert summary["int8_bytes"] < summary["fp32_bytes"]


def test_weights_are_uint8_and_load_on_cpu(tiny_export):
    import onnx

    release, _, summary = tiny_export
    model = onnx.load(str(release / "model.onnx"))
    quantised = [t for t in model.graph.initializer if t.name.endswith("_quantized")]
    assert quantised, "no quantised weights found"
    assert {t.data_type for t in quantised} == {onnx.TensorProto.UINT8}
    assert summary["weight_type"] == "uint8"
    ops = {n.op_type for n in model.graph.node}
    assert "MatMulInteger" in ops and "ConvInteger" not in ops
    sess = ex.session(release / "model.onnx")
    assert sess.get_providers() == ["CPUExecutionProvider"]


def test_graph_contract(tiny_export):
    release, _, _ = tiny_export
    sess = ex.session(release / "model.onnx")
    (inp,) = sess.get_inputs()
    (out,) = sess.get_outputs()
    assert inp.name == "input_values" and len(inp.shape) == 2
    assert out.name == "logits" and len(out.shape) == 3
    assert isinstance(inp.shape[1], str), "length axis must be dynamic"


@pytest.mark.parametrize("seconds", [0.5, 1.3, 3.0])
def test_fp32_onnx_matches_pytorch(tiny_model, tiny_export, seconds):
    _, work, _ = tiny_export
    audio = normalise(tone(seconds, 300))
    ref = ex.torch_logits(tiny_model, audio)
    got = ex.onnx_logits(ex.session(work / "model.fp32.onnx"), audio)
    assert got.shape == ref.shape == (int(seconds * 50) - 1, len(VOCAB))
    assert np.abs(got - ref).max() < 1e-4


def test_int8_within_tolerance_of_fp32(tiny_export):
    release, work, _ = tiny_export
    fp32 = ex.session(work / "model.fp32.onnx")
    int8 = ex.session(release / "model.onnx")
    results = []
    for i, freq in enumerate((180, 260, 410, 650)):
        audio = normalise(tone(1.0 + 0.25 * i, freq, seed=i))
        results.append(ev.compare_logits(ex.onnx_logits(fp32, audio), ex.onnx_logits(int8, audio)))
    summary = ev.summarise(results)
    assert summary["mean_abs"] < 0.05
    assert summary["max_abs_logprob"] < 0.5
    assert summary["argmax_agree"] > 0.9


def test_export_leaves_model_in_eval_mode(tiny_model, tmp_path):
    ex.export_fp32(tiny_model, tmp_path / "m.onnx", seconds=0.5)
    assert not tiny_model.training


def test_quantise_conv_variant(tiny_model, tmp_path):
    summary = ex.export_tier(
        tiny_model, VOCAB, tmp_path / "rel", tmp_path / "work", quant_ops=ex.QUANT_OPS_WITH_CONV
    )
    assert summary["quant_ops"] == ["MatMul", "Gemm", "Conv"]
    sess = ex.session(tmp_path / "rel" / "model.onnx")
    assert ex.onnx_logits(sess, normalise(tone(1.0, 200))).shape == (49, len(VOCAB))


def test_load_model_checks_vocab_size(tiny_model_dir, tmp_path):
    model, vocab = ex.load_model(tiny_model_dir)
    assert vocab == VOCAB and not model.training
    bad = tmp_path / "bad"
    model.save_pretrained(bad)
    (bad / "vocab.json").write_text(json.dumps({"<pad>": 0}), encoding="utf-8")
    with pytest.raises(ValueError, match="vocab.json has 1 tokens"):
        ex.load_model(bad)


def test_cli_end_to_end_with_manifest(tiny_model_dir, tmp_path, capsys):
    release = tmp_path / "release"
    args = ["--model", str(tiny_model_dir), "--out", str(release / "full")]
    assert ex.main([*args, "--work", str(tmp_path)]) == 0
    assert json.loads((tmp_path / "export.json").read_text())["opset"] == 17
    manifest = mf.build_manifest(release)
    mf.write_manifest(release, manifest)
    assert mf.verify_manifest(release) == []
    assert {f["name"] for f in manifest["files"]} == {"full-model.onnx", "full-vocab.json"}
    assert "int8_bytes" in capsys.readouterr().out


def test_torch_logits_no_grad(tiny_model):
    out = ex.torch_logits(tiny_model, normalise(tone(0.5, 100)))
    assert isinstance(out, np.ndarray)
    assert torch.is_grad_enabled()
