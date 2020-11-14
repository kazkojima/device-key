# Root key module

This is my trial of a verilog implementation of an example ROT (root of trust) module based on

I. Lebedev, K. Hogan and S. Devadas, "Invited Paper: Secure Boot and Remote Attestation in the Sanctum Processor," 2018 IEEE 31st Computer Security Foundations Symposium (CSF), Oxford, 2018, pp. 46-60, doi: 10.1109/CSF.2018.00011.

There are 2 imported submodules:

* SHA3: A forked version of [Freecores SHA3](https://github.com/freecores/sha3.git)
* TRNG: [Ringoscillator TRNG](https://github.com/dpiegdon/ringoscillator.git)

Notice that they have their own LICENCE files.

## Device utilisation

```
Info:          TRELLIS_SLICE: 23601/41820    56%
Info:             TRELLIS_IO:    21/  365     5%
Info:                   DCCA:     2/   56     3%
Info:                 DP16KD:    12/  208     5%
Info:             MULT18X18D:     0/  156     0%
Info:                 ALU54B:     0/   78     0%
Info:                EHXPLLL:     1/    4    25%
```

## Status

Only basic functions work on the real chip at 50MHz clock, ATM.
