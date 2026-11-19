function results = experiment_224G(cfg)
%EXPERIMENT_224G  TESTS 5 and 6 (Part 5) plus the headline supervisor-
%meeting figures (Part 6):
%   TEST 5: full DAC/ADC impairments + a MINIMAL, single-cycle (L=1,
%           un-averaged, noisy) CHEST -- isolates the effect of CHEST
%           estimation NOISE, matching the paper's own study of P_k vs.
%           moving-average window size L ([FEXT] Fig. 9, p.84-85)
%   TEST 6: FULL 224 Gb/s baseline -- full impairments + a well-converged,
%           moving-averaged CHEST (cfg.chest.L_moving_avg, paper recommends
%           L>100) -- this is "the" reported baseline result

fig_dir = cfg.fig_dir;

% --- TEST 5: minimal (L=1) CHEST, to show estimation noise sensitivity ---
cfg5 = cfg; cfg5.chest.L_moving_avg = 1;
opts5 = struct('enable_fext', true, 'apply_impairments', true, ...
               'use_genie_channel', false, 'fde_mode', 'cancel', 'seed_offset', 2);
r5 = run_224G_test(cfg5, opts5);

% --- TEST 6: full baseline, well-converged CHEST (L per config, default 200) ---
opts6 = struct('enable_fext', true, 'apply_impairments', true, ...
               'use_genie_channel', false, 'fde_mode', 'cancel', 'seed_offset', 3);
r6 = run_224G_test(cfg, opts6);

fprintf('[TEST 5] Impairments + minimal (L=1) CHEST:  SER = %.3e, BER = %.3e, EVM = %.2f%%\n', ...
    r5.ser, r5.ber, r5.evm_percent);
fprintf('[TEST 6] FULL 224G BASELINE (CHEST+impair.):  SER = %.3e, BER = %.3e, EVM = %.2f%%\n', ...
    r6.ser, r6.ber, r6.evm_percent);
fprintf('         (paper-reported reference: SER w/ cancel = 1.4e-5, SER w/o cancel = 4e-1, BER = 2.4e-6)\n');

% Figure: channel frequency response (main + FEXT)
plot_channel_response(cfg, fullfile(fig_dir, 'fig02_03_channel_response.png'));

% Figure: constellation before/after FEXT cancellation, full baseline
plot_constellation(r6.rx_syms1_other, r6.rx_syms1, ...
    'TEST 6: full 224G baseline constellation, lane 1 (all sub-channels)', ...
    fullfile(fig_dir, 'fig04_05_constellation_before_after_fext_cancel.png'));

% Overlay baseline and stronger-FEXT stress tests in the existing images.
snr_range = cfg.sim.snr_sweep_dB;
fext_gains = [0 20];
if isfield(cfg.sim, 'fext_sweep_gain_dB')
    fext_gains = cfg.sim.fext_sweep_gain_dB;
end
assert(isvector(fext_gains) && ~isempty(fext_gains) && ...
    all(isfinite(fext_gains)) && isreal(fext_gains), 'Invalid FEXT sweep gains');
fext_gains = unique([0 reshape(fext_gains,1,[])], 'stable');
base_gain = 0;
if isfield(cfg.channel,'fext_gain_dB'), base_gain = cfg.channel.fext_gain_dB; end
sweeps = struct([]);
ber_curves = {}; ser_curves = {}; curve_labels = {};
fprintf('Sweeping FEXT Strength now; this may take some time. Please wait about 2 minuites\n');
for g = 1:numel(fext_gains)
    sweep_cfg = cfg;
    sweep_cfg.channel.fext_gain_dB = base_gain + fext_gains(g);
    ber_cancel = zeros(size(snr_range)); ser_cancel = ber_cancel;
    ber_naive = ber_cancel; ser_naive = ber_cancel;
    for i = 1:numel(snr_range)
        o = struct('enable_fext', true, 'apply_impairments', true, ...
                   'use_genie_channel', false, 'fde_mode', 'cancel', ...
                   'snr_override_dB', snr_range(i), 'seed_offset', 10+i);
        % Reuse the same data, channel estimate and noise for both decisions.
        rc = run_224G_test(sweep_cfg, o);
        ber_cancel(i) = rc.ber; ser_cancel(i) = rc.ser;
        tx1 = qam_demodulate(rc.tx_syms1, cfg.mod.order);
        tx2 = qam_demodulate(rc.tx_syms2, cfg.mod.order);
        rx1 = qam_demodulate(rc.rx_syms1_other, cfg.mod.order);
        rx2 = qam_demodulate(rc.rx_syms2_other, cfg.mod.order);
        ber_naive(i) = mean([calculate_ber(tx1,rx1), calculate_ber(tx2,rx2)]);
        ser_naive(i) = rc.ser_other_mode;
    end
    sweeps(g).fext_change_dB = fext_gains(g);
    sweeps(g).fext_gain_dB = sweep_cfg.channel.fext_gain_dB;
    sweeps(g).snr_dB = snr_range;
    sweeps(g).ber_cancel = ber_cancel; sweeps(g).ber_naive = ber_naive;
    sweeps(g).ser_cancel = ser_cancel; sweeps(g).ser_naive = ser_naive;
    ber_curves = [ber_curves {ber_cancel,ber_naive}]; %#ok<AGROW>
    ser_curves = [ser_curves {ser_cancel,ser_naive}]; %#ok<AGROW>
    curve_labels = [curve_labels { ...
        sprintf('With FEXT cancellation (%+g dB FEXT)', fext_gains(g)), ...
        sprintf('Without FEXT cancellation (%+g dB FEXT)', fext_gains(g))}]; %#ok<AGROW>
end
plot_results(snr_range, ber_curves, curve_labels, ...
    'RX input SNR (dB)', 'Bit Error Rate', ...
    'Fig. 6: BER vs. SNR, baseline and FEXT stress sweep', ...
    fullfile(fig_dir, 'fig06_ber_vs_snr.png'));
plot_results(snr_range, ser_curves, curve_labels, ...
    'RX input SNR (dB)', 'Symbol Error Rate', ...
    'Fig. 7: SER vs. SNR, baseline and FEXT stress sweep', ...
    fullfile(fig_dir, 'fig07_ser_vs_snr.png'));

% Figure 8: actual baseline values, with both zero-based bars visible.
plot_baseline_ser(r6, fig_dir);

% Figure 9: full 224G baseline summary (text/metric panel)
fig = figure('Visible','off','Color','w','Position',[100 100 640 420]);
axis off;
txt = { ...
    sprintf('224 Gb/s MIMO-OFDM baseline -- TEST 6 summary'), ...
    '', ...
    sprintf('Data rate (config):        %.1f Gb/s', cfg.data_rate_bps/1e9), ...
    sprintf('N_{FFT} / N_{CP}:            %d / %d', cfg.ofdm.N_FFT, cfg.ofdm.N_CP), ...
    sprintf('Modulation:                 %d-QAM', cfg.mod.order), ...
    sprintf('Sampling rate:              %.2f GS/s', cfg.fs/1e9), ...
    sprintf('DAC/ADC resolution:         %d / %d bit', cfg.dac.bits, cfg.adc.bits), ...
    '', ...
    sprintf('SER (with FEXT cancel):     %.3e   [paper: 1.4e-5]', r6.ser), ...
    sprintf('SER (without cancel):       %.3e   [paper: 4e-1]', r6.ser_other_mode), ...
    sprintf('BER (with FEXT cancel):     %.3e   [paper: 2.4e-6, gray-coded]', r6.ber), ...
    sprintf('EVM (with FEXT cancel):     %.2f%%', r6.evm_percent), ...
    '', ...
    'See docs/validation.md for what matches, what is approximate,', ...
    'and which values are configurable assumptions (config/224G_paper_specs.md).'};
% Draw one line at a time (more portable across renderers than a single
% multi-line cell-array text() call, which some graphics backends mis-place).
xlim([0 1]); ylim([0 1]);
line_h = 0.062;
y0 = 0.97;
for li = 1:numel(txt)
    text(0.02, y0 - (li-1)*line_h, txt{li}, 'Units','normalized', ...
        'VerticalAlignment','top', 'FontSize', 10, 'Interpreter','none');
end
save_figure(fig, fullfile(fig_dir, 'fig09_baseline_summary.png'));

results = struct('test5', r5, 'test6', r6, ...
    'snr_sweep', sweeps(1), 'fext_snr_sweep', sweeps);

end
