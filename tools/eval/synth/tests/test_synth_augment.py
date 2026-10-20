import random

import numpy as np
import pytest

from tools.eval.synth import augment as aug

SR = 16000


def tone(freq=440.0, secs=1.0, sr=SR):
    t = np.arange(int(secs * sr)) / sr
    return 0.5 * np.sin(2 * np.pi * freq * t)


def band_energy(x, sr, lo, hi):
    spec = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(len(x), 1 / sr)
    return spec[(f >= lo) & (f < hi)].sum()


def test_resample_length_and_pitch():
    x = tone(1000, 1.0, 24000)
    y = aug.resample(x, 24000, SR)
    assert len(y) == SR
    f = np.fft.rfftfreq(len(y), 1 / SR)[np.argmax(np.abs(np.fft.rfft(y)))]
    assert abs(f - 1000) < 2
    assert aug.resample(x, 24000, 24000) is not x
    assert len(aug.resample(tone(500, 0.5, 8000), 8000, SR)) == SR // 2
    assert len(aug.resample(tone(500, 1.0, 22050), 22050, SR)) == SR


def test_resample_removes_content_above_new_nyquist():
    x = tone(10000, 1.0, 24000)
    assert np.max(np.abs(aug.resample(x, 24000, SR))) < 1e-6


@pytest.mark.parametrize("kind", aug.NOISE_KINDS)
def test_coloured_noise_unit_rms_and_slope(kind):
    n = aug.coloured_noise(SR * 2, kind, np.random.default_rng(0))
    assert np.sqrt(np.mean(n**2)) == pytest.approx(1.0, rel=1e-6)
    low, high = band_energy(n, SR, 100, 500), band_energy(n, SR, 4000, 4400)
    if kind == "white":
        assert low / high == pytest.approx(1.0, rel=0.3)
    else:
        assert low > 3 * high


@pytest.mark.parametrize("snr", [10.0, 20.0, 30.0])
def test_add_noise_hits_the_snr(snr):
    x = tone()
    y = aug.add_noise(x, SR, snr, "white", np.random.default_rng(1))
    noise = y - x
    got = 10 * np.log10(np.mean(x**2) / np.mean(noise**2))
    assert got == pytest.approx(snr, abs=0.2)


def test_active_rms_ignores_padding_and_silence():
    x = np.concatenate([np.zeros(SR), tone()])
    assert aug.active_rms(x, SR) == pytest.approx(np.sqrt(np.mean(tone() ** 2)), rel=0.01)
    assert aug.active_rms(np.zeros(100), SR) == 0.0


def test_reverb_adds_a_tail():
    x = np.zeros(SR)
    x[100] = 1.0
    y = aug.reverb(x, SR, 0.3, 0.3, np.random.default_rng(2))
    assert y[100] == pytest.approx(0.7)
    assert np.abs(y[200:2000]).sum() > 0


def test_phone_band_cuts_lows_and_highs():
    x = tone(100) + tone(1000) + tone(6000)
    y = aug.phone_band(x, SR)
    assert band_energy(y, SR, 900, 1100) > 0.9 * band_energy(x, SR, 900, 1100)
    assert band_energy(y, SR, 50, 150) < 1e-6 * band_energy(x, SR, 50, 150)
    assert band_energy(y, SR, 5900, 6100) < 1e-6 * band_energy(x, SR, 5900, 6100)


def test_draw_profile_ranges_and_seeding():
    ps = [aug.draw_profile(random.Random(i)) for i in range(400)]
    assert all(0.9 <= p.speed <= 1.1 for p in ps)
    noisy = [p for p in ps if p.noise]
    assert 0.6 < len(noisy) / len(ps) < 0.8
    assert all(10 <= p.snr_db <= 30 for p in noisy)
    assert 0.15 < sum(p.phone for p in ps) / len(ps) < 0.35
    assert all(0.2 <= p.rt60 <= 0.5 for p in ps if p.rt60)
    assert aug.draw_profile(random.Random(5)) == aug.draw_profile(random.Random(5))


def test_describe_and_dict():
    p = aug.Profile(speed=0.95, noise="pink", snr_db=12, rt60=0.3, wet=0.2, phone=True)
    assert p.describe() == "speed=0.95,pink@12dB,reverb=0.30s,phone"
    assert aug.Profile(**p.to_dict()) == p
    assert aug.Profile().describe() == "speed=1.00"


def test_apply_pads_resamples_and_sets_peak():
    x = tone(300, 1.0, 24000)
    p = aug.Profile(
        lead_ms=100,
        tail_ms=200,
        noise="white",
        snr_db=20,
        rt60=0.2,
        wet=0.2,
        phone=True,
        gain_db=-6.0,
    )
    y = aug.apply(x, 24000, p, seed=3)
    assert len(y) == SR + 1600 + 3200
    assert np.max(np.abs(y)) == pytest.approx(10 ** (-6 / 20))
    assert np.array_equal(y, aug.apply(x, 24000, p, seed=3))
    dry = aug.clean(x, 24000)
    assert np.all(dry[:2000] == 0)
    assert np.max(np.abs(dry)) == pytest.approx(10 ** (-3 / 20))
