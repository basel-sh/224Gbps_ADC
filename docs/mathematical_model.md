# Mathematical Model

This document explains, block by block, the math implemented in the MATLAB project, and maps every
equation to the MATLAB function that implements it. All equation numbers referencing "[FEXT]" are from
G. Kim, *Far-End Crosstalk Cancellation With MIMO OFDM for >200 Gb/s ADC-Based Serial Links*, IEEE TCAS-II,
2023; "[DSE]" refers to the companion paper, *Design Space Exploration of Single-Lane OFDM-Based Serial
Links...*, IEEE OJ-CAS, 2022. See `config/224G_paper_specs.md` for the exact page/section citation of every
parameter value used below.

## 1. QAM modulation (`tx/qam_modulate.m`, `rx/qam_demodulate.m`)

Square M-QAM with Gray coding on the I and Q rails independently. For M = 64, each symbol carries
log2(64) = 6 bits (3 on I, 3 on Q). Bits are Gray-mapped to PAM levels in {-7,-5,...,-1,1,...,7} on each
rail, combined as `s = I + jQ`, then normalized to unit average energy:

```
E[|s|^2] = 1  =>  s_normalized = s_raw / sqrt(2*(M-1)/3)
```

(the `2*(M-1)/3` factor is the standard average energy of a square M-QAM constellation with unit rail
spacing, combining both I and Q rails). Demodulation is nearest-neighbor slicing followed by the inverse
Gray-to-binary mapping.

## 2. OFDM mapping and IDFT/IFFT (`tx/ofdm_modulate.m`)

Given N_used = N_FFT/2 - 1 frequency-domain QAM symbols X(k), k = 1..N_used, they are placed on IDFT
input bins 2..N_used+1 (bin 1 = DC, left at 0). Hermitian symmetry is enforced by mirroring:

```
Bin(N_FFT - k + 2) = conj(Bin(k)),  k = 2 .. N_used+1
```

so that the N_FFT-point IDFT output is purely real (no imaginary time-domain samples are transmitted, per
[FEXT] Sec. II-A and [DSE] Sec. II-A/Fig. 7). This matches the paper's statement that only the first half
of the DFT/IDFT bins (excluding DC) carry data, since the second half is redundant by Hermitian symmetry.

```
x(n) = (1/sqrt(N_FFT)) * sum_{k=0}^{N_FFT-1} Bin(k) * exp(j*2*pi*k*n/N_FFT),  n = 0..N_FFT-1
```

(implemented via `ifft` with a `sqrt(N_FFT)` scaling convention, exactly inverted by `rx/ofdm_demodulate.m`'s
`fft(...)/sqrt(N_FFT)`).

## 3. Cyclic prefix (`tx/ofdm_modulate.m`, `rx/ofdm_demodulate.m`)

The last N_CP time-domain samples of each OFDM symbol are copied to its front:

```
tx_time = [ x(N_FFT-N_CP+1 : N_FFT) ; x(1:N_FFT) ]
```

At the receiver, the first N_CP samples of each received block are discarded before the FFT. As long as
the channel's impulse response fits within N_CP samples, this converts the linear convolution with the
channel into a per-subcarrier *circular* multiplication -- i.e. the entire reason per-subcarrier
single-tap equalization works. [DSE] Sec. II-B / III-C studies exactly what happens when the channel's
significant impulse response exceeds the prefix (residual ISI). The active model
retains a 512-tap imported response and an 8-sample CP, leaving some residual
interference. Exact circular-convolution equivalence requires channel memory
(length minus one) no greater than N_CP.

## 4. TX de-emphasis / power loading (`impairments/tx_deemphasis.m`)

A real, per-sub-channel linear gain g(k) is applied to X(k) BEFORE the IDFT:

```
g_dB(k) = -10.5 + (0 - (-10.5)) * (k-1)/(511-1),   k = 1..511    [A, FEXT Sec. V]
g(k) = 10^(g_dB(k)/20)
```

extended to a general N_used by linearly re-mapping k onto [1,511] (see `impairments/deemphasis_gain_vector.m`).

## 5. DAC / ADC (`tx/dac_model.m`, `rx/adc_model.m`, `impairments/clipping_model.m`,
`impairments/quantization_model.m`)

Both converters share the same three-stage model: (i) RMS-normalize the input to hit a target RMS derived
from the paper's clipping-ratio definition ([DSE] Sec. V):

```
R_clip = beta / A_RMS   (dB value given by the paper; beta = one-sided full-scale amplitude)
=> target_RMS = beta / 10^(R_clip_dB/20)
```

(ii) hard-clip to +/-beta; (iii) uniformly quantize the clipped signal into 2^bits levels spanning
[-beta, beta]. The RX chain additionally applies a VGA gain BEFORE clipping so that the ADC input RMS hits
its own target ("VGA amplifies the input signal so the ADC uses its input full-scale", [FEXT] p.84).

## 6. Channel model: main (THRU) and FEXT (`channel/main_channel.m`, `channel/fext_channel.m`,
`channel/touchstone_channel.m`)

The active path imports differential THRU and FEXT transfer functions from the
included IEEE 802.3ck Channel1 Touchstone files. `touchstone_channel` converts
the four-port data to a differential transfer function, interpolates onto the
FFT grid, removes common bulk delay, and retains 512 impulse-response samples.
No synthetic attenuation model is used in the active project.

The symmetric two-lane model is:

```
y1 = h_main * x1 + h_fext * x2
y2 = h_fext * x1 + h_main * x2
```

Here * denotes linear convolution. A stress gain D dB changes only
`h_fext` to `10^(D/20)*h_fext`, consistently in pilots and data.
Lane symmetry is an assumption, and the imported channel is not established
as the exact measured channel from the paper.

## 7. 2x2 MIMO channel estimation (`rx/channel_estimation.m`, `rx/estimate_mimo_channel.m`)

Exactly implements [FEXT] eqs. (7)-(12). Two pilot OFDM symbols per CHEST cycle:

```
n=1 (opposite polarity):  X1=Sk,  X2=-Sk   =>  Y1^(1) = H13*Sk - H23*Sk,  Y2^(1) = H14*Sk - H24*Sk
n=2 (identical):          X1=Sk,  X2=+Sk   =>  Y1^(2) = H13*Sk + H23*Sk,  Y2^(2) = H14*Sk + H24*Sk

H23 = (Y1^(2) - Y1^(1)) / (2*Sk)      H13 = (Y1^(2) + Y1^(1)) / (2*Sk)
H14 = (Y2^(2) + Y2^(1)) / (2*Sk)      H24 = (Y2^(2) - Y2^(1)) / (2*Sk)
```

Because of random noise, the raw per-cycle estimate is repeated for L cycles (paper recommends L > 100,
[FEXT] Fig. 9) and averaged in the inverse-coefficient domain: `P_avg = mean(inv(H_raw), over L cycles)`.
The known equal-I/Q QPSK pilots vary between cycles using reproducible seeds;
their exact sequence is a model assumption.

## 8. 2x2 MIMO frequency-domain equalization (`mimo/fext_cancellation.m`, `mimo/mimo_fde.m`)

Per [FEXT] eqs. (3)-(6), for each sub-channel k:

```
Hk = [ H13(k)  H23(k) ;  H14(k)  H24(k) ]
Pk = Hk^-1 = (1/det(Hk)) * [ H24(k)  -H23(k) ; -H14(k)  H13(k) ],   det(Hk) = H13(k)*H24(k) - H23(k)*H14(k)

[ Xhat1(k) ]   [ P1(k)  P2(k) ] [ Y1(k) ]
[ Xhat2(k) ] = [ P3(k)  P4(k) ] [ Y2(k) ]
```

This is the general per-sub-channel model referenced in the project brief:

```
Y(k) = H(k) X(k) + N(k)
```

where Y(k) = [Y1(k); Y2(k)] is the received vector, X(k) = [X1(k); X2(k)] the transmitted vector, H(k) the
2x2 channel matrix above, and N(k) the (post-ADC, equivalent frequency-domain) noise vector. H13/H24 are
the **main** (THRU) responses; H23/H14 are the **FEXT** (crosstalk) responses -- consistent with [FEXT]'s
own definition. The "without FEXT cancellation" comparison case (`mimo/mimo_fde.m`, mode `'naive'`) simply
uses the single-lane inverse `Xhat_m(k) = Y_m(k) / H_main,m(k)`, ignoring the off-diagonal (FEXT) terms
entirely, matching [FEXT] eq. (1) and the paper's own baseline comparison.

## 9. QAM demodulation, BER/SER/EVM (`rx/qam_demodulate.m`, `analysis/calculate_ber.m`,
`analysis/calculate_ser.m`, `analysis/calculate_evm.m`)

- **BER**: fraction of mismatched bits between the original TX bitstream and the demodulated RX bitstream.
- **SER**: fraction of symbols whose nearest-constellation-point index differs between the (re-quantized)
  TX symbol and the equalized RX symbol.
- **EVM**: `EVM% = 100 * sqrt( E[|rx-tx|^2] / E[|tx|^2] )`, the standard error-vector-magnitude definition.

## 10. Theoretical AWGN reference (`experiments/experiment_ideal_channel.m`)

For validation purposes only (TEST 1), the measured SER of the isolated modulator/demodulator pair under
direct complex AWGN is compared against the closed-form square M-QAM AWGN SER:

```
SER_theory = 1 - (1 - 2*(1 - 1/sqrt(M)) * Q(sqrt(3*Es/N0/(M-1))))^2,   Q(x) = 0.5*erfc(x/sqrt(2))
```
