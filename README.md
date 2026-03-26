# RGBa Matchbox Shaders

Some of my old Matchbox shaders. I went through all of them and updated them with small fixes and added tooltips.
They have all been tested in SCRATCH. Not all have been tested in Flame. If something is weird, let me know or edit them to your own liking.

---

## EdgeDetect — Edge Detection

RGBa | v0.2

A 3x3 edge detection shader with a choice of Sobel or Scharr gradient kernels.

---

### Kernels

**Sobel (default)**
Standard 3x3 first-order gradient operator. Fast and predictable. Has a slight directional bias — diagonal edges can appear marginally different to horizontal/vertical ones.

**Scharr**
A drop-in 3x3 alternative with improved rotational symmetry. Produces more consistent edge strength regardless of edge angle. Generally preferred when edge direction varies across the image.

---

### Notes

- Luminance is calculated using ITU-R BT.709 weights `(0.2126, 0.7152, 0.0722)`.
- Source alpha is passed through unchanged.
- For fatter, more diffuse edges see **Chobel**, which uses a 5x5 kernel with a softness control.

---

## Chobel — Chubby Sobel Edge Detection

RGBa | v0.3

A 5x5 Sobel edge detector designed to produce fatter, more diffuse edges than the standard 3x3 Sobel.

---

### Notes

- Luminance is calculated using ITU-R BT.709 weights `(0.2126, 0.7152, 0.0722)`.
- Source alpha is passed through unchanged.
- For a tighter, crisper edge matte see **EdgeDetect**, which uses a 3x3 kernel with a Scharr option.

---

## Diffusion — Random Scatter Blur

RGBa | v0.2

A diffusion blur that scatters samples randomly within a disc. Produces a soft, organic blur character — less uniform than a Gaussian, more like optical diffusion or a diffusion filter. A better diffusion shader is in the works, but for now this is fine. An optional edge mask restricts the effect.

---

## Advection — Edge-Tangent Flow

RGBa | v0.2

Advects pixels along the tangent flow field of the image's own edges — the direction that runs *along* contours rather than across them. Two modes offer very different looks from the same underlying technique. Not REALLY advection, but something close without being too complex.

---

## WaveBlur — Parametric Wave Blur

RGBa | v1.0

A blur shader where each sample follows a parametric wave curve. Three kernel modes produce entirely different blur characters — floral, knotted, or spiral — all of which can be deformed with a vortex twist and split into chromatic channels.

---

## Halation — Film Halation & Bloom


RGBa | v0.2

Simulates film halation — very early version. Not very good yet.

An optional bloom adds a neutral luminance glow, which commonly accompanies halation around specular highlights.

---

## Dither — Combined Dither Shader


RGBa | v1.0

Six dither algorithms in one shader. All support multi-level quantization, colour or luma mode, and temporal animation.

---

### Algorithms

#### Bayer 2x2
The smallest ordered dither matrix — a 2×2 tile. At `Levels=2` it produces a hard checkerboard. At higher levels the geometric grid becomes a stylised posterize.

#### Bayer 4x4
Classic 4×4 ordered dither. Recognisable video-game / early desktop look. Coarser than 8×8 but with a clear repeating structure.

#### Bayer 8x8
Halftone grid. At `Levels=2` the screen is fine enough to read as a texture rather than individual cells.

#### White Noise
Per-pixel random hash — no spatial structure whatsoever. High `Levels` for a subtle texture. At `Levels=2` it is mostly just noise.

#### IGN (Interleaved Gradient Noise)
Interleaved Gradient Noise: Less structured than Bayer, smoother than white noise. Good general-purpose noise dither with a slightly organic character.

#### Error Diffusion
Approximation of error-diffusion dithering (Floyd-Steinberg).

---

## Dithering — Original Error Diffusion


RGBa | v0.1

The original error diffusion dither. Converts the image to greyscale using manual per-channel luma weights, then runs an approximate 1D error diffusion sweep along both x and y axes before thresholding to black and white. Output is always B&W. Very bad, lots of fun.

---

## Dither2 — Multi-Algorithm Dither (Bayer / Noise)


RGBa | v0.2

Ordered and noise dithering. An old version, but decided to keep it. 

---

## Streak - Streak / Flare Filter

RGBa | v1.0

Creates elongated light streaks radiating from bright highlights. Two primary uses: anamorphic lens streaks (long horizontal blue-white streaks, characteristic of anamorphic cinema lenses) and star filter patterns (4-point, 6-point, 8-point star from multiple streak directions).

---

## Streak Directions

| Streaks value | Pattern | Ray count |
|---|---|---|
| 1 | Anamorphic (horizontal at Angle=0) | 2 |
| 2 | 4-point star | 4 |
| 3 | 6-point star | 6 |
| 4 | 8-point star | 8 |
| 5 | 10-point star | 10 |
| 6 | 12-point star | 12 |

Each additional direction adds an equal amount to total streak brightness. If you want a 4-point star at the same per-streak brightness as a 1-direction anamorphic, reduce `Intensity` proportionally.

---


