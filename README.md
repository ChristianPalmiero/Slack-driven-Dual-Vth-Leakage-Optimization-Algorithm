# Slack-driven-Dual-Vth-Leakage-Optimization-Algorithm
A TCL command to be integrated within Design Compiler that performs a Slack-driven Dual-Vth post synthesis optimization based on the Logic Synthesis Flow using Synopsys.<br />
Such a command reduces leakage power by means of dual-Vth assignment while forcing the number of quasi-critical paths below a user-defined constraint.
<br />
Main arguments of the command are:
<br />* arrivalTime: the actual timing constraint the circuit has to satisfy after dual-Vth assignment [ns]
<br />* criticalPaths: the total number of timing paths that fall within a given slack window after the dual-Vth
assignment [integer]
<br />* slackWin: is the slack window for critical paths [ns]
<br />The command returns the list resList containing the following 4 items:
<br />item 0--> power-savings: % of leakage reduction w.r.t. the initial configuration;
<br />item 1--> execution-time: difference between starting-time and end-time [seconds]*.
<br />item 2--> lvt: % of LVT gates
<br />item 3--> hvt: % of HVT gates
