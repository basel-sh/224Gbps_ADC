% Checks that address reproducibility failures found in the paper audit.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root);
folders = {'config','tx','channel','impairments','rx','mimo','experiments','analysis'};
for k = 1:numel(folders)
    addpath(fullfile(root, folders{k}));
end
c = config_224G();
rate = c.ofdm.N_used*c.mod.bits_per_sym*c.fs/(c.ofdm.N_FFT+c.ofdm.N_CP);
assert(abs(rate/223.5625e9-1)<1e-12);
c=config_224G();c.sim.num_ofdm_symbols=20;
b=generate_bits(c.ofdm.N_used*6*20,100);
X=reshape(qam_modulate(b,64),c.ofdm.N_used,20);
Z=ofdm_demodulate(ofdm_modulate(X,c),c);
assert(max(abs(X(:)-Z(:)))<1e-12);
assert(isequal(b,qam_demodulate(X(:),64)));
o=struct('enable_channel',true,'enable_fext',true,'apply_impairments',true);
c=calibrate_link_gains(c,o);
assert(abs(effective_clip_ratio(c.dac)-3.404)<0.01);
[~,m1]=dac_model(ofdm_modulate(X,c),c,false);
[~,m2]=dac_model(ofdm_modulate(X(:,1),c),c,false);
assert(m1.scale==m2.scale);
x=sin((1:10000)'*0.6);
a=jitter_model(x,c.fs,0.01,31)-x;b2=jitter_model(x,c.fs,0.01,53)-x;
cc=corrcoef(a,b2); assert(abs(cc(1,2))<0.05);
r=run_224G_test(c,struct('apply_impairments',false,'enable_channel',false));
assert(r.bit_errors==0 && r.symbol_errors==0);
% Algebraic training recovery with four distinct complex channel entries.
S=exp(1j*(1:10)');h13=0.7+0.2j;h24=0.6-0.1j;h23=0.1j;h14=-0.03j;
[a,b2,d,e]=channel_estimation(S,(h13-h23)*S,(h14-h24)*S, ...
 (h13+h23)*S,(h14+h24)*S);
assert(max(abs(a-h13))<1e-12 && max(abs(b2-h23))<1e-12);
assert(max(abs(d-h14))<1e-12 && max(abs(e-h24))<1e-12);
fprintf('224G_CHECKS_PASS: rate, QAM/OFDM, shared gains, independent jitter, CHEST algebra\n');
