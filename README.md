# fpmath-nv

A device program that turns a sensor reading into an angle, or an angle
into a rotation, needs a sine, a cosine, an arctangent, an arcsine and a
square root. On a microcontroller at `@tier(embedded)` the standard
library's `math.sin`, `math.cos`, `math.atan2` and `math.sqrt` are refused,
because each lowers to a call into the C maths library, which a 64 KB image
cannot link. This package holds the seven functions a filter needs on
`fp32`, written in `+ - * /` and comparisons, with no allocation and no
effect, and states how close each comes to the real function and how many
bytes it costs.

The routines are the ones Cephes (S. L. Moshier) gives for binary32: a
reduction of the argument to a short interval and a polynomial over it. A
filter or an odometry package imports this module in place of carrying its
own copy; `ahrs-nv` and `odometry-nv` do.

| Quantity | Value |
| --- | --- |
| Number format | single precision (`fp32`), rounded to binary32 after every operation |
| Allocations | none |
| Effects | none |
| Tier | every function checks at `@tier(embedded)` |

## Install

```
novo pkg add fpmath-nv
```

## Example

```novo
use fpmath

fn heading_of(y: fp32, x: fp32) -> fp32
    // The angle of the point (x, y) from the x axis, in (-pi, pi].
    fpmath.atan2(y, x)

fn main() [io]
    let s = fpmath.sin(1.5707964)
    let r = fpmath.sqrt(2.0)
    println("${s > 0.99999 and r > 1.41421 and heading_of(1.0, -1.0) > 2.3561}")   // true
```

The functions take and answer `fp32`. A literal beside an `fp32` makes the
operation binary64, which a Cortex-M4 does in software, so a program binds
a constant to a typed `let` first, as the module does.

## What the package contains

| Function | What it answers | Domain | Error bound the tests assert |
| --- | --- | --- | --- |
| `sin(x)`, `cos(x)` | the sine and cosine of `x` in radians | `\|x\| <= 100` | 2e-7 absolute |
| `atan(x)` | the arctangent in `(-pi/2, pi/2)` | every `fp32` | 3e-7 absolute |
| `atan2(y, x)` | the angle of `(x, y)` in `(-pi, pi]`, `y` first; zero for `(0, 0)` | every pair | 3e-7 absolute |
| `asin(x)` | the arcsine in `[-pi/2, pi/2]`; `x` outside `[-1, 1]` is clamped | `[-1, 1]` | 3e-7 absolute |
| `sqrt(x)` | the square root; zero for `x < 0` | `x >= 0` | 2e-7 relative |
| `inv_sqrt(x)` | the reciprocal square root; zero for `x <= 0` | `x > 0` | 2e-7 relative |

The argument of `sin` and `cos` is reduced by whole quarter turns in three
parts, so that the product of the count and pi/2 loses nothing; a larger
angle is as accurate as its own rounding allows, and the bound is stated
to 100 radians.

## How close each function is

`tests/fpmath_tests.nv` compares each function with the host's `math` (in
binary64) over a dense sweep and asserts the bound above; `tests/accuracy.nv`
prints the maxima. Measured with `novo 0.26.2`; "ulp" is the error in units
of the binary32 spacing at the true value:

| Function | Sweep | Points | Largest error | In ulp |
| --- | --- | ---: | ---: | ---: |
| `sin` | `[-100, 100]`, step 0.001 | 200,001 | 7.6e-8 absolute | 1.43 |
| `cos` | `[-100, 100]`, step 0.001 | 200,001 | 7.3e-8 absolute | 1.42 |
| `atan` | `[-15, 15]` step 0.0005, and 1e-4 to 1e4 log-spaced, both signs | 76,003 | 1.3e-7 absolute | 2.29 |
| `atan2` | the grid `[-10, 10]` by 0.1 in both arguments, and 100,001 points of a circle | 140,402 | 2.7e-7 absolute | 2.74 |
| `asin` | `[-1, 1]`, step 1e-5, and 20,001 points within 1.2e-4 of each end | 220,001 | 1.5e-7 absolute | 3.53 |
| `sqrt` | 1e-5 to 1e5, log-spaced | 100,001 | 8.9e-8 relative | |
| `inv_sqrt` | 1e-5 to 1e5, log-spaced | 100,001 | 1.4e-7 relative | |

`sin` over 100 to 1100 radians stays within 7e-8. Near zero the functions
are exact to the binary32 spacing (`sin` and `atan` differ from the real
function by less than 3e-21 below 2e-7).

## What each function costs

Sizes are bytes of Thumb-2 code for a Cortex-M4 (`nrf52-qemu`, the board's
default level), each function kept out of its callers so that the size is
the function's own (`tests/function_sizes.sh`). A public function calls
the private ones listed:

| Function | Its own size | Calls | Total with what it calls |
| --- | ---: | --- | ---: |
| `sin` | 80 | `quarter_turns` 360, `reduce` 188, `sin_poly` 60, `cos_poly` 76 | 764 |
| `cos` | 80 | the same four | 764 |
| `atan` | 216 | | 216 |
| `atan2` | 140 | `atan` | 356 |
| `asin` | 26 | `atan2`, `sqrt` | 598 |
| `sqrt` | 68 | `inv_sqrt` 148 | 216 |
| `inv_sqrt` | 148 | | 148 |

`sin` and `cos` share their callees, so a program that calls both pays 764
bytes plus 80 for the second. The image of `tests/embedded_probe.nv`, which
calls every function once, is 3,064 bytes larger than a program that does
not call the package (`nrf52840-dk`, `tests/device_build.sh`); that figure
includes the few libgcc routines the probe's comparisons pull in.

`quarter_turns`, `atan` and `inv_sqrt` carry a binary32 value across an `if`
as a binary64, which links libgcc's binary64 routines into the image; the
sizes above are the functions' own and do not include them. The compiler
holds the cause.

## The square root

`sqrt` and `inv_sqrt` are Newton iterations over a bit-pattern estimate,
because the embedded tier has no `math.sqrt` on an `fp32`. When it has,
the change is one line, the last line of `sqrt` in `src/fpmath.nv`:
`s + half * (x - s * s) * r` becomes `math.sqrt(x)`, and `inv_sqrt`
becomes `one / math.sqrt(x)`. No caller changes.

## Tests

```
novo test tests
bash tests/function_sizes.sh
bash tests/device_build.sh
```

`tests/embedded_probe.nv` is built for the nRF52840-DK, the nRF54LM20-DK and
the emulated board, and the emulated image is run under QEMU.

## Licence

Apache-2.0.
