# Theory Notes: Post-ASD Closure 0D Cardiovascular Model

**Reference:** Valenti et al. (2023). Lumped-parameter cardiovascular model for ASD closure simulation.
**Model type:** 0D closed-loop lumped parameter (Windkessel/RLC)

---

## 1. Model Overview

The model represents the closed-loop cardiovascular system using 14 coupled ODEs:
- **4 cardiac chamber volumes** (LA, LV, RA, RV)
- **6 vascular compartment pressures** (systemic arterial, capillary, venous; pulmonary arterial, capillary, venous)
- **4 inertial flows** (systemic arterial/venous, pulmonary arterial/venous)

---

## 2. Governing Equations

### 2.1 Chamber Pressure (Time-Varying Elastance)

$$P_{chamber}(t) = E(t) \cdot (V_{chamber} - V_0)$$

where $E(t)$ [mmHg/mL] is the time-varying elastance and $V_0$ [mL] is the unstressed volume.

### 2.2 Elastance Activation Function (Piecewise Cosine)

$$E(t) = E_{min} + (E_{max} - E_{min}) \cdot e_n(t_{rel})$$

$$e_n(t_{rel}) = \begin{cases}
\frac{1}{2}\left(1 - \cos\frac{\pi t_{rel}}{T_{sys}}\right) & 0 \le t_{rel} < T_{sys} \\
\frac{1}{2}\left(1 + \cos\frac{\pi (t_{rel}-T_{sys})}{T_{rel}}\right) & T_{sys} \le t_{rel} < T_{sys}+T_{rel} \\
0 & \text{otherwise}
\end{cases}$$

where $t_{rel} = \text{mod}(t - t_{on},\, T_{cardiac})$.

### 2.3 Chamber Volume ODEs

$$\frac{dV_{LA}}{dt} = Q_{pv} - Q_{mv} - Q_{shunt\_asd}$$

$$\frac{dV_{LV}}{dt} = Q_{mv} - Q_{ao}$$

$$\frac{dV_{RA}}{dt} = Q_{sv} - Q_{tv} + Q_{shunt\_asd}$$

$$\frac{dV_{RV}}{dt} = Q_{tv} - Q_{pv\_valve}$$

### 2.4 Vascular Pressure ODEs (RLC Compartments)

$$C \frac{dP}{dt} = Q_{in} - Q_{out}$$

| Compartment | $C$ | $Q_{in}$ | $Q_{out}$ |
|---|---|---|---|
| Systemic arterial ($P_{sa}$) | $C_{sa}$ | $Q_{ao}$ (valve) | $Q_{sa}$ (inertial) |
| Systemic capillary ($P_{sc}$) | $C_{sc}$ | $Q_{sa}$ | $Q_{sc}$ (algebraic) |
| Systemic venous ($P_{sv}$) | $C_{sv}$ | $Q_{sc}$ | $Q_{sv}$ (inertial) |
| Pulmonary arterial ($P_{pa}$) | $C_{pa}$ | $Q_{pv\_valve}$ | $Q_{pa}$ (inertial) |
| Pulmonary capillary ($P_{pc}$) | $C_{pc}$ | $Q_{pa}$ | $Q_{pc}$ (algebraic) |
| Pulmonary venous ($P_{pv}$) | $C_{pv}$ | $Q_{pc}$ | $Q_{pv}$ (inertial) |

### 2.5 Inertial Flow ODEs

$$L \frac{dQ}{dt} = \Delta P - R \cdot Q$$

| Flow | $L$ | $R$ | $\Delta P$ |
|---|---|---|---|
| $Q_{sa}$ | $L_{sa}$ | $R_{sa}$ | $P_{sa} - P_{sc}$ |
| $Q_{sv}$ | $L_{sv}$ | $R_{sv}$ | $P_{sv} - P_{ra}$ |
| $Q_{pa}$ | $L_{pa}$ | $R_{pa}$ | $P_{pa} - P_{pc}$ |
| $Q_{pv}$ | $L_{pv}$ | $R_{pv}$ | $P_{pv} - P_{la}$ |

### 2.6 Algebraic Capillary Flows

$$Q_{sc} = \frac{P_{sc} - P_{sv}}{R_{sc}}, \quad Q_{pc} = \frac{P_{pc} - P_{pv}}{R_{pc}}$$

### 2.7 Valve Flow (R_min / R_max Switching)

$$Q_{valve} = \frac{\max(0, \Delta P)}{R_{min}} + \frac{\min(0, \Delta P)}{R_{max}}$$

Forward flow (open valve): $\Delta P > 0$, resistance = $R_{min}$
Reverse flow (closed valve): $\Delta P \le 0$, resistance = $R_{max} \gg R_{min}$

Applied to: mitral ($Q_{mv}$), aortic ($Q_{ao}$), tricuspid ($Q_{tv}$), pulmonary ($Q_{pv\_valve}$).

### 2.8 ASD Shunt Equation

$$Q_{shunt\_asd} = \frac{P_{la} - P_{ra}}{R_{ASD}}$$

- **Open ASD:** $R_{ASD}$ = finite resistance [mmHg·s/mL]
- **Post-closure:** $R_{ASD} = \infty \Rightarrow Q_{shunt\_asd} = 0$
- **Sign convention:** $Q_{shunt\_asd} > 0$ → left-to-right shunt (LA → RA)

---

## 3. ASD Circuit Integration

The ASD shunt affects atrial volumes:

$$\frac{dV_{LA}}{dt} = Q_{pv} - Q_{mv} - Q_{shunt\_asd}$$

$$\frac{dV_{RA}}{dt} = Q_{sv} - Q_{tv} + Q_{shunt\_asd}$$

Post-closure ($R_{ASD} = \infty$): the atrial ODEs reduce to the standard (no-shunt) form.

---

## 4. Assumptions

1. Incompressible, Newtonian blood (no non-Newtonian effects)
2. Lumped (0D) compartments — no spatial pressure gradients
3. Valve dynamics are instantaneous (no inertia/compliance at leaflets)
4. Pericardial constraint neglected
5. Autonomic regulation and baroreflex not modelled (open-loop autonomics)
6. ASD is modelled as a linear Ohmic resistor (valid for small-to-moderate defects)
7. Pulmonary and systemic beds are symmetric (bilateral symmetry within each circuit)
8. Heart rate is constant (no heart rate variability)

---

## 5. Unit System

| Quantity | Unit |
|---|---|
| Pressure | mmHg |
| Volume | mL |
| Flow (ODE internal) | mL/s |
| Resistance | mmHg·s/mL |
| Compliance | mL/mmHg |
| Elastance | mmHg/mL |
| Inertance | mmHg·s²/mL |
| Time | s |

Flow reported clinically: L/min (convert via ×60/1000).

---

## 6. References

1. Valenti et al. (2023). Lumped-parameter cardiovascular model for ASD closure. *(primary model source)*
2. Heldt T, Shim EB, Kamm RD, Mark RG (2002). Computational modeling of cardiovascular response to orthostatic stress. *J Appl Physiol* 92:1239-1254.
3. Shi Y, Lawford P, Hose R (2011). Review of zero-D and 1-D models of blood flow in the cardiovascular system. *Interface Focus* 1:20-33.
4. Guyton AC, Hall JE. *Textbook of Medical Physiology*, 14th Ed. Elsevier.
5. Lang RM et al. (2015). Recommendations for cardiac chamber quantification. *J Am Soc Echocardiogr* 28:1-39.
