function [h, info] = main_channel(cfg)
%MAIN_CHANNEL Import the 224G main (THRU) impulse response from Touchstone.
[h, info] = touchstone_channel(cfg, 'main');
end
