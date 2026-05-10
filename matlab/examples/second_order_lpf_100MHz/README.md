# 100 MHz Second-order Low-pass Simulink Example

This example builds and validates a second-order Butterworth low-pass filter
as an equivalent passive RLC circuit:

```text
Vin -> R -> L -> Vout
                 |
                 C
                 |
                GND
```

The Simulink model uses the equivalent continuous transfer function:

```text
H(s) = Vout/Vin = 1 / (L*C*s^2 + R*C*s + 1)
```

Design target:

```text
fc = 100 MHz
Q  = 1/sqrt(2)  Butterworth
L  = 100 nH
C  = 25.3303 pF
R  = 88.8577 ohm
```

Run from MATLAB:

```matlab
cd(fileparts(mfilename("fullpath")))
validate_second_order_lpf_100MHz
```

Generated files:

- `second_order_lpf_100MHz.slx`
- `second_order_lpf_100MHz_design.mat`
- `validation_summary.csv`
- `validation_probe_points.csv`
- `validation_bode.png`
