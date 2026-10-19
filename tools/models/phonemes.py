"""Phoneme helpers: vocab files, eSpeak NG IPA labels, CTC greedy decoding and PER.

eSpeak NG (GPL-3.0) is only ever run as an external binary from tools/ (never imported,
linked or shipped). Point `ESPEAK_NG` at the binary if it is not on PATH; the usual
`ESPEAK_DATA_PATH` / `LD_LIBRARY_PATH` variables pass straight through.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from collections.abc import Iterable, Sequence
from pathlib import Path

BLANK = "<pad>"
SPECIALS = ("<pad>", "<s>", "</s>", "<unk>")
STRESS_MARKS = "ˈˌ"
# eSpeak voices: the full model was trained on en-us labels; the light model is trained
# on Received Pronunciation labels (closest eSpeak voice to Standard Southern British).
VOICE_RP = "en-gb-x-rp"
VOICE_US = "en-us"


def load_vocab(path: Path) -> dict[str, int]:
    """Reads a HuggingFace-style vocab.json ({token: id})."""
    return json.loads(path.read_text(encoding="utf-8"))


def vocab_list(vocab: dict[str, int]) -> list[str]:
    """Tokens ordered by id (column i of the logits is `vocab_list(v)[i]`)."""
    if sorted(vocab.values()) != list(range(len(vocab))):
        raise ValueError("vocab ids are not contiguous from 0")
    out = [""] * len(vocab)
    for token, idx in vocab.items():
        out[idx] = token
    return out


def blank_index(vocab: dict[str, int]) -> int:
    """Index of the CTC blank (`<pad>`, as in every wav2vec2 CTC model)."""
    return vocab[BLANK]


def espeak_binary() -> str:
    """Path of the eSpeak NG binary (env ESPEAK_NG, else `espeak-ng` on PATH)."""
    exe = os.environ.get("ESPEAK_NG") or shutil.which("espeak-ng")
    if not exe:
        raise FileNotFoundError("eSpeak NG not found: install it or set ESPEAK_NG=<binary>")
    return exe


def espeak_ipa(text: str, voice: str = VOICE_RP, runner=None) -> list[list[str]]:
    """IPA phones for [text], one list per eSpeak word group, stress marks removed.

    Uses `espeak-ng -q --ipa --sep=_`; eSpeak sometimes merges short function words into
    one group ("from the"), which does not matter for utterance-level labels.
    """
    runner = runner or subprocess.run
    result = runner(
        [espeak_binary(), "-q", "--ipa", "--sep=_", "-v", voice, text],
        capture_output=True,
        text=True,
        check=True,
    )
    words = []
    for group in result.stdout.split():
        phones = [p.strip(STRESS_MARKS) for p in group.split("_")]
        phones = [p for p in phones if p]
        if phones:
            words.append(phones)
    return words


def to_vocab_tokens(phones: Iterable[str], vocab: dict[str, int] | set[str]) -> list[str]:
    """Maps eSpeak phones onto vocab tokens.

    A phone that is a vocab token is kept; otherwise it is split greedily into the longest
    vocab tokens (`ɑːɹ` stays whole in the full vocab, `aɪə` -> `aɪ` + `ə` in a vocab
    without it). Characters with no token at all are dropped.
    """
    out: list[str] = []
    for phone in phones:
        if phone in vocab:
            out.append(phone)
            continue
        i = 0
        while i < len(phone):
            for j in range(len(phone), i, -1):
                if phone[i:j] in vocab:
                    out.append(phone[i:j])
                    i = j
                    break
            else:
                i += 1
    return out


def text_to_tokens(
    text: str,
    vocab: dict[str, int] | set[str],
    voice: str = VOICE_RP,
    runner=None,
) -> list[str]:
    """Flat vocab-token label sequence for a transcript."""
    phones = [p for word in espeak_ipa(text, voice, runner) for p in word]
    return to_vocab_tokens(phones, vocab)


def ctc_greedy(ids: Sequence[int], blank: int = 0) -> list[int]:
    """Greedy CTC decode: collapse repeats, drop blanks."""
    out = []
    prev = None
    for i in ids:
        if i != prev and i != blank:
            out.append(int(i))
        prev = i
    return out


def edit_distance(ref: Sequence, hyp: Sequence) -> int:
    """Levenshtein distance (substitutions, insertions, deletions all cost 1)."""
    prev = list(range(len(hyp) + 1))
    for i, r in enumerate(ref, 1):
        cur = [i] + [0] * len(hyp)
        for j, h in enumerate(hyp, 1):
            cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (r != h))
        prev = cur
    return prev[-1]


def normalise_for_per(tokens: Sequence[str]) -> list[str]:
    """Loose comparison form: drops length marks and r-colouring so `ɑːɹ` == `ɑ` etc.

    Used for the "loose" PER that does not punish the full model's American eSpeak labels
    when it hears British speech; the strict PER compares tokens as they are.
    """
    out = []
    for t in tokens:
        t = t.replace("ː", "").replace("ɹ", "") if len(t) > 1 else t
        if t:
            out.append(t)
    return out


def phoneme_error_rate(pairs: Iterable[tuple[Sequence, Sequence]]) -> float:
    """Corpus PER: total edit distance / total reference length over (ref, hyp) pairs."""
    errors = total = 0
    for ref, hyp in pairs:
        errors += edit_distance(ref, hyp)
        total += len(ref)
    return errors / total if total else 0.0


def build_light_vocab(label_tokens: Iterable[Sequence[str]], full_vocab: dict[str, int]) -> dict:
    """Light-tier vocab: the specials (blank `<pad>` = 0) plus every token used in the
    labels, ordered by the full vocab's ids. Every token is a full-vocab token string, so
    A3's IPA -> vocab mapping works for both tiers."""
    used = {t for seq in label_tokens for t in seq}
    unknown = used - set(full_vocab)
    if unknown:
        raise ValueError(f"tokens not in the full vocab: {sorted(unknown)}")
    ordered = [t for t, _ in sorted(full_vocab.items(), key=lambda kv: kv[1]) if t in used]
    tokens = list(SPECIALS) + [t for t in ordered if t not in SPECIALS]
    return {t: i for i, t in enumerate(tokens)}
