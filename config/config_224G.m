function cfg = config_224G()
%CONFIG_224G  Centralized configuration for the 224 Gb/s MIMO-OFDM baseline.
%
% Every numeric value below is tagged in a trailing comment:
%   [A] = explicitly stated in the reference paper (Kim, TCAS-II 2023, "FEXT
%         Cancellation With MIMO OFDM for >200 Gb/s ADC-Based Serial Links")
%   [B] = derived mathematically from [A] values
%   [C] = NOT SPECIFIED IN REFERENCE PAPER -> configurable assumption
%
% See config/224G_paper_specs.md for full source citations (page/section/table)
% and docs/assumptions.md for the rationale behind every [C] value.
%
% This is the ONLY place 224G numeric parameters should live. Every function
% in tx/, channel/, rx/, mimo/, impairments/ receives its parameters through
% this struct (or a field of it) -- never hard-code a parameter elsewhere.

cfg = struct();
root = fileparts(fileparts(mfilename('fullpath')));

%% ---- Identification -----------------------------------------------------
cfg.name        = '224G_baseline';
cfg.data_rate_bps = 224e9;                 % [A] p.84 Sec. V

%% ---- OFDM / FFT ------------------------------------------------------
cfg.ofdm.N_FFT  = 1024;                    % [A] p.84 Sec. V
cfg.ofdm.N_CP   = 8;                       % [A] p.84 Sec. V
cfg.ofdm.N_used = cfg.ofdm.N_FFT/2 - 1;    % [B] k = 1..511, DC & Nyquist unused
cfg.ofdm.k_idx  = (1:cfg.ofdm.N_used).';   % sub-channel indices used for TX/RX

%% ---- Modulation --------------------------------------------------------
cfg.mod.order      = 64;                  % [A] 64-QAM, p.84 Sec. V
cfg.mod.bits_per_sym = log2(cfg.mod.order); % [B]
cfg.mod.bit_loading = false;               % [A] homogeneous QAM (no bit-loading)

%% ---- Sampling ------------------------------------------------------------
cfg.fs          = 75.25e9;                 % [A] DAC/ADC sampling rate, p.84 Sec. V
cfg.occupied_bw = 37.625e9;                % [A] p.84 Sec. V

%% ---- Data converters -----------------------------------------------------
cfg.dac.bits          = 7;                 % [A] p.84 Sec. V
cfg.adc.bits           = 7;                % [A] p.84 Sec. V
cfg.dac.vfs_diff_pp    = 1.0;               % [A] 1 Vpp,diff DAC full-scale
cfg.adc.vfs_diff_pp    = 0.5;               % [A] 0.5 Vpp,diff ADC full-scale
cfg.dac.clip_ratio_dB  = 12.6;              % [A] FEXT p.84 (DSE uses a different setting)
cfg.adc.clip_ratio_dB  = 13.4;              % [A] FEXT p.84
cfg.dac.clip_reference = 'mean_abs';        % [C] literal "average magnitude" interpretation
cfg.adc.clip_reference = 'mean_abs';        % [C] compare explicitly against RMS interpretation
cfg.noise.reference = 'adc_input';         % [C] retained baseline: fixed noise after VGA
cfg.use_ctle           = false;             % [A] "CTLE is not considered"
cfg.vga_normalizes_to_adc_fullscale = true; % [A] VGA scales signal to ADC full-scale
cfg.adc.vga_gain_fixed = [];                % [C] calibrated once, shared by training/data
cfg.dac.scale_fixed = [];                  % [C] stationary QAM ensemble RMS calibration
%% ---- Impairments -----------------------------------------------------
cfg.jitter.rms_UI      = 0.01;             % [A] 1% UI RMS TX/RX sampling jitter
cfg.noise.rx_input_rms_V = 1.8e-3;         % [A] 1.8 mV RMS RX input random noise
cfg.noise.type          = 'gaussian_white'; % [C] shape not specified; assumed AWGN

%% ---- TX de-emphasis (power loading) --------------------------------------
% [A] -10.5 dB at k=1, 0 dB at k=511, linear in dB vs. k (p.84 Sec. V)
cfg.deemph.k1_dB   = -10.5;
cfg.deemph.k511_dB = 0.0;
cfg.deemph.gain_dB = @(k) cfg.deemph.k1_dB + ...
    (cfg.deemph.k511_dB - cfg.deemph.k1_dB) * (k - 1) / (511 - 1); % [B]

%% ---- Imported 224G channel --------------------------------------------
% [C] Public IEEE channel retained from the validated baseline; not claimed
% to be the exact measured channel used in the reference paper.
chan_dir = fullfile(root, 'channel', 'data', 'ieee_8023ck_c2c', 'Channel1');
prefix = 'Asic_Mezz_Retimer_L10';
cfg.channel.type = 'touchstone';
cfg.channel.ir_fft_len = 4096;
cfg.channel.touchstone = struct( ...
    'thru_file', fullfile(chan_dir, [prefix '_Thru.s4p']), ...
    'fext_file', fullfile(chan_dir, [prefix '_FEXT1.s4p']), ...
    'num_taps', 512, 'main_cursor_idx', 2);
cfg.channel.fext_gain_dB = 0;              % [C] original imported coupling

%% ---- MIMO ------------------------------------------------------------
cfg.mimo.num_lanes = 2;                    % [A] 2x2 MIMO, one aggressor, p.83 Sec. III

%% ---- Channel estimation ------------------------------------------------
cfg.chest.M_symbol_period = 200;           % [A] "M > 100" recommended; 200 chosen [C-within-A-bound]
cfg.chest.L_moving_avg    = 200;           % [A] "L > 100" stabilizes; 200 chosen [C-within-A-bound]
cfg.chest.average_domain = 'coefficients'; % [A] average inverse coefficients P, Fig.7
cfg.chest.vary_pilots = true;              % [C] independent known equal-I/Q pilots per cycle

%% ---- Simulation control (NOT specified by the paper -> assumptions) ------
cfg.sim.num_ofdm_symbols = 2000;           % [C] number of data OFDM symbols per run
cfg.sim.rng_seed          = 2024;          % [C] reproducible seed
cfg.sim.snr_sweep_dB       = 10:2:30;       % [C] SNR sweep range for BER/SER-vs-SNR plots
cfg.sim.fext_sweep_gain_dB = [0 20];        % [C] baseline and +20 dB FEXT stress test

%% ---- Paths -------------------------------------------------------------
cfg.results_dir = fullfile(root, 'results', '224G');
cfg.fig_dir     = fullfile(cfg.results_dir, 'figures');

end
