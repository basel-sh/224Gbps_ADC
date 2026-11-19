# 224 Gb/s MIMO-OFDM MATLAB simulation

This project contains the 224 Gb/s behavioral link study based on G. Kim's
*Far-End Crosstalk Cancellation With MIMO OFDM for >200 Gb/s ADC-Based Serial Links*.

## Software and running

- MATLAB R2026b was used for the retained runs.
- Base MATLAB is sufficient; no Communications Toolbox, Python, or external software is required.
- Open this project folder as MATLAB's Current Folder, then run:

```matlab
main_224
```

The entry point adds its own processing folders, loads the included THRU/FEXT
channel files, runs Tests 1-6, plots the results, and saves them automatically.
No download, absolute machine-specific path, or separate setup command is needed.
The full run takes a few minutes depending on the computer. The SNR sweep prints
one waiting message rather than a line for every point.

## Tests

| Test | Conditions | Purpose |
|---|---|---|
| 1 | 64-QAM with symbol-level Gaussian noise, Es/N0 = 10:2:30 dB; no physical channel | Compare SER against QAM theory |
| 2 | Main channel, no FEXT; known channel; converter/noise impairments off | Check main-path equalization |
| 3 | Main + FEXT; known channel; cancellation off; impairments off | Isolate uncancelled interference |
| 4 | Same as Test 3 with cancellation on | Check cancellation with a known channel |
| 5 | Main + FEXT; full impairments; pilot estimation L=1; cancellation on | Check estimation sensitivity |
| 6 | Main + FEXT; full impairments; pilot estimation L=200; cancellation on | Full baseline |

The BER/SER-vs-SNR figures overlay with/without cancellation at original FEXT and
at +20 dB FEXT (10 times leakage amplitude). The latter is a labeled stress test,
not the original imported channel. Both modes use the same received samples and
channel estimate at each sweep point.

## Settings

All baseline settings are in `config/config_224G.m`: FFT1024, CP8, 511 data tones,
64-QAM, 75.25 GS/s, 7-bit DAC/ADC, 1% UI RMS TX/RX jitter, 1.8 mV fixed noise,
2,000 data OFDM symbols per lane, and CHEST averaging L200.
The actual gross rate is 223.5625 Gb/s per lane, rounded to 224 Gb/s;
training and FEC overhead are not included in that number.

The imported channel is IEEE 802.3ck Channel1 `Asic_Mezz_Retimer_L10` THRU/FEXT1.
Its two required `.s4p` files and source/hash record are included under `channel/data/`.

## Outputs

- `results/224G/figures/`: PNG figures, including the existing
  `fig06_ber_vs_snr.png` and `fig07_ser_vs_snr.png` with both FEXT strengths.
- `results/224G/results_224G.mat`: saved configuration, symbol samples, metrics,
  baseline SNR sweep, and the complete `test56.fext_snr_sweep` results.

A new run replaces these outputs. Optional functional checks:

```matlab
run(fullfile('tests', 'validate_224G.m'))
```

## Folder guide

| Folder/file | Role |
|---|---|
| `main_224.m` | Single full-run entry point |
| `config/` | Baseline settings and paper specification table |
| `tx/`, `rx/` | QAM, OFDM, converters, and pilot estimation |
| `channel/` | Imported THRU/FEXT data, convolution, and random noise |
| `impairments/` | Clipping, quantization, jitter, and TX loading |
| `mimo/` | Per-tone equalization and FEXT cancellation |
| `experiments/` | Tests 1-6 and shared link engine |
| `analysis/` | Error metrics, plotting, and optional saved-result redraw |
| `tests/` | 224 Gb/s functional checks |
| `docs/` | Model equations, flow, assumptions, validation, and source papers |
| `presentations/Second meeting/` | Retained 224 Gb/s meeting materials |

## Interpretation

This is a behavioral model, not a circuit implementation or an exact reproduction
of the paper's error rates. The imported coupling differs from the paper's case.
The fixed-noise baseline retains 1.8 mV added after VGA; the SNR sweeps instead
set noise before VGA from the requested SNR. These conditions are deliberately
unchanged by project cleanup. CP8 also leaves residual interference from the
longer imported impulse response. Zero observed SER does not establish zero
underlying error probability.

See `docs/validation.md`, `docs/assumptions.md`, `docs/simulation_flow.md`,
`docs/mathematical_model.md`, and `config/224G_paper_specs.md` for details.
