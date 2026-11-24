# Changelog

All notable changes to fpmath-nv are recorded here. The format is
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this
package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with the pre-1.0 rule that a breaking change bumps the MINOR number.

## 0.1.0 — 2026-11-24

### Added

- **`fpmath`** — single-precision `sin`, `cos`, `atan`, `atan2`, `asin`,
  `sqrt` and `inv_sqrt` for a device whose tier refuses libm, extracted
  from `ahrs-nv`'s `fpmath` and `odometry-nv`'s `odotrig`, which carried
  the same routines.
- `tests/fpmath_tests.nv`, each function against the host's `math` over a
  dense sweep, and `tests/accuracy.nv`, which prints the maxima the README
  gives.
- `tests/function_sizes.sh`, the size of each function on a Cortex-M4.
- `tests/embedded_probe.nv` and `tests/device_build.sh`, the device claim as
  a program, built for the nRF52840-DK, the nRF54LM20-DK and the emulated
  board, with the image sizes beside a baseline and a QEMU run.

### Changed

- The stated error of `asin` is 3e-7 over `[-1, 1]`. `ahrs-nv` stated 5e-4
  at the ends; the sweep finds 1.1e-7 within 1.2e-4 of them, because the
  root is taken of `(1 - x) * (1 + x)`.

### Known

- The compiler carries a binary32 value across an `if` as a binary64, so
  `quarter_turns`, `atan` and `inv_sqrt` link libgcc's binary64 routines
  into a device image.
