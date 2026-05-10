function design = create_second_order_lpf_100MHz()
%CREATE_SECOND_ORDER_LPF_100MHZ Build a Simulink model for a 100 MHz LPF.
%
% The example models a passive second-order RLC low-pass network:
%
%   Vin -> R -> L -> Vout, with C from Vout to ground.
%
% Its transfer function is:
%
%   H(s) = Vout/Vin = 1 / (L*C*s^2 + R*C*s + 1)
%
% The component values below give a Butterworth response with fc = 100 MHz.

exampleDir = fileparts(mfilename("fullpath"));
modelName = "second_order_lpf_100MHz";
modelFile = fullfile(exampleDir, modelName + ".slx");

design.fc = 100e6;
design.wc = 2*pi*design.fc;
design.Q = 1/sqrt(2);
design.L = 100e-9;
design.C = 1/(design.wc^2*design.L);
design.R = sqrt(design.L/design.C)/design.Q;
design.num = 1;
design.den = [design.L*design.C, design.R*design.C, 1];
design.modelName = char(modelName);
design.modelFile = char(modelFile);

save(fullfile(exampleDir, "second_order_lpf_100MHz_design.mat"), "design");

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

new_system(modelName);
open_system(modelName);

set_param(modelName, ...
    "Solver", "ode23tb", ...
    "StopTime", "200e-9", ...
    "MaxStep", "20e-12", ...
    "SignalLogging", "on");

add_block("simulink/Sources/In1", modelName + "/Vin", ...
    "Position", [70 90 100 110]);
add_block("simulink/Continuous/Transfer Fcn", modelName + "/RLC_2nd_Order_LPF", ...
    "Numerator", "1", ...
    "Denominator", "[L*C R*C 1]", ...
    "Position", [170 75 340 125]);
add_block("simulink/Sinks/Out1", modelName + "/Vout", ...
    "Position", [430 90 460 110]);
add_block("simulink/Sinks/To Workspace", modelName + "/Vout_to_workspace", ...
    "VariableName", "vout", ...
    "SaveFormat", "Structure With Time", ...
    "Position", [430 145 545 175]);

add_line(modelName, "Vin/1", "RLC_2nd_Order_LPF/1", "autorouting", "on");
add_line(modelName, "RLC_2nd_Order_LPF/1", "Vout/1", "autorouting", "on");
add_line(modelName, "RLC_2nd_Order_LPF/1", "Vout_to_workspace/1", "autorouting", "on");

annotationText = sprintf([ ...
    'Second-order RLC low-pass, Butterworth response\n', ...
    'fc = %.3g Hz, Q = %.4f\n', ...
    'R = %.6g ohm, L = %.6g H, C = %.6g F\n', ...
    'H(s)=1/(L*C*s^2 + R*C*s + 1)'], ...
    design.fc, design.Q, design.R, design.L, design.C);
note = Simulink.Annotation(modelName, "Design note");
note.Text = annotationText;
note.Position = [60 205 555 300];

assignin("base", "R", design.R);
assignin("base", "L", design.L);
assignin("base", "C", design.C);

save_system(modelName, modelFile);
fprintf("Created %s\n", modelFile);
fprintf("R = %.9g ohm, L = %.9g H, C = %.9g F\n", design.R, design.L, design.C);
end
