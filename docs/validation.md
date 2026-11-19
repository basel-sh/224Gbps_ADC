# 224 Gb/s validation

Run `main_224` for the retained full suite. The current numeric results belong
in `results/224G/results_224G.mat`; the corresponding PNGs are in `figures/`.
This document does not substitute historical confirmation values for a new run.

## What is checked

1. Test 1 compares measured 64-QAM SER against the AWGN expression.
2. Tests 2-4 isolate main-path equalization and FEXT cancellation with known
   channels and disabled converter/noise impairments. EVM exposes residual
   distortion when all symbol decisions are correct.
3. Tests 5-6 include noise, clipping, quantization, independent TX/RX jitter,
   and pilot-based estimation, comparing L1 against L200.
4. BER/SER SNR sweeps compare cancellation modes on identical received data
   at each point, for both original and +20 dB FEXT. Stress curves are labeled.
5. `tests/validate_224G.m` checks gross-rate arithmetic, QAM/OFDM round trips,
   calibrated gain sharing, independent jitter draws, ideal-link recovery,
   and the channel-estimation algebra.

## Interpretation limits

The paper reports SER with cancellation 1.4e-5, SER without cancellation 4e-1,
and pre-FEC BER 2.4e-6. These remain comparison values, not claims about our
results. The imported channel/coupling and fixed-noise injection convention
are not a demonstrated match to that paper. See `assumptions.md`.

The gross per-lane rate is 511*6*75.25e9/1032 = 223.5625e9 bit/s, rounded to
224 Gb/s. BER/SER pooled over two lanes does not change this per-lane rate.

A zero observed SER should be reported with its error count and symbol count.
The short CP can leave nonzero EVM even in Test 2 with no FEXT or added noise.
Increasing CP to cover the full channel removes this source of interference,
but would also change framing overhead; CP8 remains the baseline.
