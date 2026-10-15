# Hardware IP Setup using Bender

To clone and check out all required hardware IPs (including the `cv32e40p` RISC-V core) for the DFT flow, run the following command from the repository root:

```bash
make checkout
```

### What this command does:
1. Automatically downloads the `bender` dependency manager into `utils/bin/bender` (if not already present).
2. Clones and checks out all 40 hardware IPs specified in `Bender.yml` into the `.bender/git/checkouts/` directory.

### Direct Bender command:
If `bender` is already downloaded:
```bash
./utils/bin/bender checkout
```
