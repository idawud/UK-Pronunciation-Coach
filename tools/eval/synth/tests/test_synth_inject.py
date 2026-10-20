import random

from tools.eval.synth import inject as inj

THINK = [("θ", 0), ("ɪ", 1), ("ŋ", 0), ("k", 0)]
CAR = [("k", 0), ("ɑː", 1)]
ASK = [("ɑː", 1), ("s", 0), ("k", 0)]
APPLE = [("æ", 1), ("p", 0), ("ə", 0), ("l", 0)]
HOUSE = [("h", 0), ("aʊ", 1), ("s", 0)]
BANANA = [("b", 0), ("ə", 0), ("n", 0), ("ɑː", 1), ("n", 0), ("ə", 0)]
KITCHEN = [("k", 0), ("ɪ", 1), ("tʃ", 0), ("ə", 0), ("n", 0)]


def kinds(text, phones, nxt=None):
    return {e.kind: e for e in inj.word_errors(text, phones, nxt)}


def test_substitutions_and_stress_kept_on_vowels():
    e = kinds("think", THINK, [("ð", 0)])
    assert {"θ->t", "θ->f", "θ->s", "ɪ->iː"} <= set(e)
    assert e["θ->t"].phones[0] == ("t", 0)
    assert e["ɪ->iː"].phones[1] == ("iː", 1)
    assert e["θ->t"].detail == "0:θ->t"


def test_bath_only_before_fricative_or_nasal_and_without_ar_spelling():
    assert "ɑː->æ" in kinds("ask", ASK)
    assert "ɑː->æ" not in kinds("car", CAR)
    assert "ɑː->æ" not in kinds("barn", [("b", 0), ("ɑː", 1), ("n", 0)])


def test_added_r_needs_spelled_r_and_no_linking_context():
    assert "added_r" in kinds("car", CAR, [("p", 0)])
    assert "added_r" in kinds("car", CAR, None)
    assert "added_r" not in kinds("car", CAR, [("ɪ", 0)])  # linking r: correct SSBE
    assert "added_r" not in kinds("banana", BANANA, None)  # no r in the spelling
    e = kinds("car", CAR)["added_r"]
    assert e.phones == (("k", 0), ("ɑː", 1), ("ɹ", 0))
    # "-rə" already has its r; a vowel before ɹ is not post-vocalic
    assert "added_r" not in kinds("camera", [("k", 0), ("æ", 1), ("m", 0), ("ɹ", 0), ("ə", 0)])


def test_added_r_word_internal():
    e = kinds("hard", [("h", 0), ("ɑː", 1), ("d", 0)], [("w", 0)])
    assert e["added_r"].phones == (("h", 0), ("ɑː", 1), ("ɹ", 0), ("d", 0))


def test_dropped_final_only_before_vowel_or_pause():
    assert "dropped_final" in kinds("think", THINK, None)
    assert "dropped_final" in kinds("think", THINK, [("ʌ", 0)])
    assert "dropped_final" not in kinds("think", THINK, [("s", 0)])
    assert kinds("think", THINK)["dropped_final"].phones == tuple(THINK[:-1])


def test_h_errors_skip_function_words():
    assert "h_dropped" in kinds("house", HOUSE)
    assert "h_added" in kinds("apple", APPLE)
    assert "h_dropped" not in kinds("his", [("h", 0), ("ɪ", 1), ("z", 0)])
    assert "h_added" not in kinds("an", [("ə", 0), ("n", 0)])


def test_stress_moves_to_a_full_vowel_when_possible():
    e = kinds("banana", BANANA)["stress"]
    assert e.phones[3] == ("ɑː", 0)
    assert sum(s == 1 for _, s in e.phones) == 1
    k = kinds("kitchen", KITCHEN)["stress"]  # only a schwa left
    assert k.phones[3] == ("ə", 1) and k.phones[1] == ("ɪ", 0)
    assert "stress" not in kinds("car", CAR)


def test_inject_is_seeded_and_bounded():
    words = [("think", THINK), ("apple", APPLE), ("house", HOUSE), ("ask", ASK)] * 3
    a = inj.inject(words, "s1|v1")
    assert a == inj.inject(words, "s1|v1")
    assert 1 <= len(a) <= 3
    assert inj.inject(words, "s1|v1", k=2).keys().__len__() == 2


def test_inject_stops_when_out_of_candidates():
    assert inj.inject([("the", [("ð", 0), ("ə", 0)])], "x", k=3).keys() == {0}
    assert inj.inject([("a", [("ə", 0)])], "x", k=3) == {}


def test_error_count_is_about_a_quarter():
    rng = random.Random(1)
    assert inj.error_count(4, rng) == 1
    assert inj.error_count(12, rng) == 3
    assert inj.error_count(40, rng) == 3


def test_error_class():
    assert inj.error_class("θ->t") == "consonant"
    assert inj.error_class("ɪ->iː") == "vowel"
    assert inj.error_class("added_r") == "added_r"
