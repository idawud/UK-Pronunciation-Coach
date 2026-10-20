from tools.eval import calibrate as cal
from tools.eval.synth import calibrate as sc
from tools.eval.synth.tests.conftest import word_row


def probe_row(item, idx, scores, split="tune", kind="clean"):
    return word_row(
        item=item,
        word_index=idx,
        split=split,
        kind=kind,
        status="close",
        phoneme_scores=" ".join(str(s) for s in scores),
    )


def label(item, idx, lab, split):
    return {"item": item, "word_index": str(idx), "label": lab, "split": split}


def data():
    # probe scores: 50 = GOP 0, 30 = GOP -4, 10 = GOP -8
    synth = [
        probe_row("t1", 0, [60, 60, 60]),  # right word, GOP +2
        probe_row("t1", 1, [60, 30, 60]),  # wrong word, one sound at GOP -4
        probe_row("h1", 0, [60, 60, 60], split="heldout"),
        probe_row("h1", 1, [60, 10, 60], split="heldout"),
    ]
    labels = [
        label("t1", 0, "right", "tune"),
        label("t1", 1, "wrong", "tune"),
        label("h1", 0, "right", "heldout"),
        label("h1", 1, "wrong", "heldout"),
    ]
    native = [
        probe_row("n1", 0, [55, 55, 55], kind="native"),
        probe_row("n2", 0, [55, 40, 55], kind="native", split="heldout"),
    ]
    return cal.observe(synth), sc.split_labels(labels), cal.observe(native)


def test_evaluate_current_defaults():
    synth, labels, native = data()
    m = sc.evaluate(sc.CURRENT, synth, labels, native)
    assert m["agree_tune"] == 1.0 and m["agree_heldout"] == 1.0
    assert m["native_red_tune"] == 0.0
    assert set(m) >= {"kappa_all", "recall_heldout", "false_red_tune", "native_red_all"}


def test_search_respects_native_red_limit():
    synth, labels, native = data()
    harsh = cal.Params(curve=[(-10, 0), (10, 0)])  # everything red
    best, m, n = sc.search(synth, labels, native, [harsh, sc.CURRENT], max_red=0.1)
    assert n == 2 and best is sc.CURRENT and m["agree_tune"] == 1.0
    none, m2, _ = sc.search(synth, labels, native, [harsh], max_red=0.1)
    assert none is None and m2 == {}


def test_native_red_by_split():
    rows = [
        {"kind": "native", "status": "fix", "split": "tune"},
        {"kind": "native", "status": "good", "split": "heldout"},
        {"kind": "clean", "status": "fix", "split": "tune"},
        {"kind": "native", "status": "notScored", "split": "tune"},
    ]
    assert sc.native_red(rows, "tune") == 1.0
    assert sc.native_red(rows, None) == 0.5
    assert sc.native_red([], None) == 0.0
