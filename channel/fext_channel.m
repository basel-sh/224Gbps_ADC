function [h, info] = fext_channel(cfg, main_info) %#ok<INUSD>
%FEXT_CHANNEL Import FEXT, with an optional gain for the 224G stress sweep.
% Positive fext_gain_dB increases leakage amplitude by 10^(gain_dB/20).
[h, info] = touchstone_channel(cfg, 'fext');
gain_dB = 0;
if isfield(cfg.channel, 'fext_gain_dB')
    gain_dB = cfg.channel.fext_gain_dB;
end
validateattributes(gain_dB, {'numeric'}, {'scalar','real','finite'});
h = h * 10^(gain_dB/20);
info.fext_gain_dB = gain_dB;
end
