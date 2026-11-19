# Assumptions of the 224 Gb/s model

The active configuration is `config/config_224G.m`. Paper-stated values are
separated from model choices in `config/224G_paper_specs.md`.

- The channel uses the included IEEE 802.3ck Channel1 THRU/FEXT1 data. It is not
  established as the exact channel from the paper. Two identical main paths
  and symmetric coupling from one neighboring lane are assumed.
- Channel processing retains 512 FIR taps on a 4096-point reconstruction grid,
  removes common bulk delay, and places the main cursor at index 2 (zero based).
  Physical time-domain convolution is used. CP8 does not cover the entire
  response, so residual inter-symbol/intercarrier interference can remain.
- The fixed-noise baseline injects 1.8 mV RMS Gaussian white noise after VGA.
  The paper describes RX-input noise; identical RMS values at different
  injection points are not equivalent. SNR sweeps inject noise before VGA
  and adjust its amplitude from the channel-output waveform power.
- DAC/ADC clipping ratios remain 12.6/13.4 dB using the retained mean-absolute
  interpretation. Full scales are 1.0/0.5 Vpp. Converters are ideal uniform
  7-bit quantizers; this is not a measured ENOB specification.
- TX and RX jitter are independently seeded at 1% UI RMS using UI=1/Fs.
  The retained interpolation model is behavioral, not a measured clock model.
- Training and data share calibrated gains. CHEST uses opposite/same polarity
  pilot pairs and averages inverse coefficients. L=1 and L=200 distinguish
  Tests 5 and 6. The data run does not interleave periodic tracking pilots.
- Two thousand data OFDM symbols are generated per lane with fixed seeds.
  Results are finite observations; zero errors is not proof of zero BER/SER.
- The +20 dB FEXT sweep multiplies only the imported coupling impulse response
  by ten before both training and data propagation. It is an artificial
  coupling stress test, not a second measured passive interconnect.
- Reported gross rate excludes training and FEC overhead. No FEC or transistor
  implementation is included.
