function results = validate_second_order_lpf_100MHz()
%VALIDATE_SECOND_ORDER_LPF_100MHZ Validate the 100 MHz second-order LPF.

exampleDir = fileparts(mfilename("fullpath"));
design = create_second_order_lpf_100MHz();

assignin("base", "R", design.R);
assignin("base", "L", design.L);
assignin("base", "C", design.C);

freqHz = logspace(6, 10, 801).';
w = 2*pi*freqHz;
H = 1 ./ (design.L*design.C*(1j*w).^2 + design.R*design.C*(1j*w) + 1);
magDb = 20*log10(abs(H));
phaseDeg = unwrap(angle(H))*180/pi;

probeHz = [10e6; 100e6; 1e9];
probeW = 2*pi*probeHz;
probeH = 1 ./ (design.L*design.C*(1j*probeW).^2 + design.R*design.C*(1j*probeW) + 1);
probeMagDb = 20*log10(abs(probeH));
probePhaseDeg = unwrap(angle(probeH))*180/pi;

[~, idxFc] = min(abs(freqHz - design.fc));
fcMagDb = magDb(idxFc);
fcPhaseDeg = phaseDeg(idxFc);

expectedFcMagDb = -3.01029995664;
fcMagErrorDb = fcMagDb - expectedFcMagDb;
pass = abs(fcMagErrorDb) < 0.05;

results = table(probeHz, probeMagDb, probePhaseDeg, ...
    'VariableNames', {'frequency_Hz', 'magnitude_dB', 'phase_deg'});
summary = table(design.fc, design.R, design.L, design.C, design.Q, ...
    fcMagDb, fcPhaseDeg, fcMagErrorDb, pass, ...
    'VariableNames', {'fc_Hz', 'R_ohm', 'L_H', 'C_F', 'Q', ...
    'magnitude_at_fc_dB', 'phase_at_fc_deg', 'fc_magnitude_error_dB', 'pass'});

writetable(results, fullfile(exampleDir, "validation_probe_points.csv"));
writetable(summary, fullfile(exampleDir, "validation_summary.csv"));

fig = figure("Visible", "off");
tiledlayout(fig, 2, 1);

nexttile;
semilogx(freqHz, magDb, "LineWidth", 1.5);
grid on;
xline(design.fc, "--", "100 MHz");
yline(expectedFcMagDb, "--", "-3.01 dB");
xlabel("Frequency (Hz)");
ylabel("Magnitude (dB)");
title("Second-order 100 MHz Butterworth Low-pass Magnitude");

nexttile;
semilogx(freqHz, phaseDeg, "LineWidth", 1.5);
grid on;
xline(design.fc, "--", "100 MHz");
xlabel("Frequency (Hz)");
ylabel("Phase (deg)");
title("Phase Response");

exportgraphics(fig, fullfile(exampleDir, "validation_bode.png"), "Resolution", 180);
close(fig);

load_system(design.modelName);
simIn = Simulink.SimulationInput(design.modelName);
simIn = simIn.setVariable("R", design.R);
simIn = simIn.setVariable("L", design.L);
simIn = simIn.setVariable("C", design.C);
simIn = simIn.setModelParameter("StopTime", "200e-9");
sim(simIn);

fprintf("Validation %s\n", char(string(pass)));
fprintf("Magnitude at %.3f MHz = %.6f dB, error = %.6f dB\n", ...
    design.fc/1e6, fcMagDb, fcMagErrorDb);
fprintf("Wrote validation outputs under %s\n", exampleDir);
end
