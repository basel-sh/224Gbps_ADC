# 224 Gb/s simulation flow

Run `main_224` from the project root. It adds its processing folders, obtains all
settings from `config_224G`, creates the output folders, and runs Tests 1-6.
Only base MATLAB is required.

## Signal chain

Bits -> Gray-coded 64-QAM -> TX per-tone de-emphasis -> Hermitian OFDM IFFT
-> cyclic prefix -> DAC -> THRU/FEXT convolution -> RX noise/VGA/ADC
-> remove cyclic prefix -> FFT -> equalization -> QAM decisions -> BER/SER/EVM.

Pilot training uses the same `link_forward_pass` function as data so it sees
the same channel and hardware model. `calibrate_link_gains` shares fixed gain
settings between training and data. Noise placement depends on whether a fixed
noise level or an explicit SNR override is requested; see `assumptions.md`.

## Calls from the entry point

- `experiment_ideal_channel`: Test 1, isolated QAM AWGN reference.
- `experiment_fext`: Tests 2-4, known channels without converter impairments.
- `experiment_224G`: Tests 5-6, full impairments and pilot estimation, followed
  by original/+20 dB FEXT SNR sweeps on the existing BER/SER figures.
- `run_224G_test`: shared data generation, training, propagation, equalization,
  and scoring. It saves both cancellation modes from the same received data.

All generated images and `results_224G.mat` stay under `results/224G/`.
The optional `analysis/redraw_224G_figures.m` redraws selected saved-sample
comparisons; it does not run the channel again or regenerate every figure.
