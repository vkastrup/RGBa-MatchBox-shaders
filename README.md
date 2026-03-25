# RGBa Matchbox Shaders

A collection of GLSL fragment shaders for **Autodesk Flame**, packaged as Matchbox nodes. Each shader pairs a `.glsl` source file with an `.xml` parameter definition. The collection focuses on image analysis (edge detection), blur and flow effects, and photographic/stylistic treatments — all written to work on linear-light RGBa footage and pass source alpha through unchanged.

---

## EdgeDetect — Edge Detection

**Matchbox Shader for Autodesk Flame**
RGBa | v0.2

A 3x3 edge detection shader with a choice of Sobel or Scharr gradient kernels. Produces crisp, thin edge mattes suitable for downstream compositing or stylisation.

---

### Parameters

| Parameter | Type | Range | Default | Description |
|---|---|---|---|---|
| Step Size | float | 0.01 – 10.0 | 1.0 | Sample offset in pixels. Increase for broader, softer edges. |
| Threshold | float | 0.0 – 1.0 | 0.0 | Clips edges below this value. Raise to suppress faint edges and texture noise. |
| Gain | float | 0.0 – 10.0 | 1.0 | Multiplies edge brightness after detection. |
| Scharr | bool | off / on | off | Switches the gradient kernel. Off = Sobel, On = Scharr. |
| Colour Edges | bool | off / on | off | Off = BT.709 luminance. On = per-channel RGB, which detects isoluminant colour transitions invisible to luma-only detection. |
| Add to Source | bool | off / on | off | Off = edge matte only. On = edge result added additively over the source image. |

---

### Kernels

**Sobel (default)**
Standard 3x3 first-order gradient operator. Fast and predictable. Has a slight directional bias — diagonal edges can appear marginally different to horizontal/vertical ones.

**Scharr**
A drop-in 3x3 alternative with improved rotational symmetry. Produces more consistent edge strength regardless of edge angle. Generally preferred when edge direction varies across the image.

---

### Notes

- Luminance is calculated using ITU-R BT.709 weights `(0.2126, 0.7152, 0.0722)` — correct for HD and linear-light images.
- Source alpha is passed through unchanged.
- For fatter, more diffuse edges see **Chobel**, which uses a 5x5 kernel with a softness control.

---

## Chobel — Chubby Sobel Edge Detection

**Matchbox Shader for Autodesk Flame**
RGBa | v0.3

A 5x5 Sobel edge detector designed to produce fatter, more diffuse edges than the standard 3x3 Sobel. The wider kernel gives edges natural body. The softness control further diffuses the response by blending each kernel tap toward the local neighbourhood mean before convolution — creating soft, spread-out edges without any additional texture fetches.

---

### Parameters

| Parameter | Type | Range | Default | Description |
|---|---|---|---|---|
| Step Size | float | 0.01 – 10.0 | 1.0 | Sample spacing in pixels. Increase to spread the 5x5 kernel further and fatten edges. |
| Softness | float | 0.0 – 1.0 | 0.0 | Diffuses the edge response. At 0 the kernel behaves as a normal 5x5 Sobel. As it increases, each tap is blended toward the local mean, producing progressively softer and more spread-out edges. |
| Threshold | float | 0.0 – 1.0 | 0.0 | Clips edges below this value. Raise to suppress faint edges and texture noise. |
| Gain | float | 0.0 – 10.0 | 1.0 | Multiplies edge brightness after detection. |
| Colour Edges | bool | off / on | off | Off = BT.709 luminance. On = per-channel RGB, which detects isoluminant colour transitions invisible to luma-only detection. |
| Add to Source | bool | off / on | off | Off = edge matte only. On = edge result added additively over the source image. |

---

### How Softness Works

All 25 sample values are cached, and their mean is computed. Each tap is then blended toward that mean by the `softness` amount before being multiplied by the kernel weights:

- `softness = 0.0` — normal 5x5 Sobel, each tap at its exact position
- `softness = 0.5` — taps half-pulled toward the local mean, noticeably softer edges
- `softness = 1.0` — all taps equal the mean, gradient collapses to near zero (fully diffuse)

**Step Size** and **Softness** are independent controls: Step Size sets how wide the kernel reaches; Softness sets how diffuse the gradient response is within that area.

---

### Notes

- Luminance is calculated using ITU-R BT.709 weights `(0.2126, 0.7152, 0.0722)` — correct for HD and linear-light images.
- Source alpha is passed through unchanged.
- For a tighter, crisper edge matte see **EdgeDetect**, which uses a 3x3 kernel with a Scharr option.

---

## Diffusion — Random Scatter Blur

**Matchbox Shader for Autodesk Flame**
RGBa | v0.2

A diffusion blur that scatters samples randomly within a disc. Produces a soft, organic blur character — less uniform than a Gaussian, more like optical diffusion or a diffusion filter over a lens. An optional edge mask restricts the effect to flat areas, keeping edges sharp while diffusing smooth regions.

---

### Parameters

| Parameter | Type | Range | Default | Description |
|---|---|---|---|---|
| Radius | float | 0.0 – 50.0 | 5.0 | Scatter radius in pixels. Controls how far samples are drawn from. |
| Iterations | int | 1 – 64 | 16 | Number of random samples per pixel. Higher = smoother result, lower = visible scatter grain. 16–32 is a practical working range. |
| Strength | float | 0.0 – 1.0 | 1.0 | Blend between original and diffused result. |
| Edge Mask | bool | off / on | off | When on, restricts diffusion to flat areas. Edges detected by the internal Sobel are preserved sharp. |
| Edge Threshold | float | 0.0 – 1.0 | 0.1 | Sensitivity of the edge mask. Lower values protect more edges; higher values only protect the strongest edges. Only active when Edge Mask is on. |

---

### How It Works

Each output pixel takes `Iterations` random samples from within a disc of `Radius` pixels, uniformly distributed (square-root radius weighting ensures even coverage, not clustering at the centre). The samples are averaged and mixed with the original by `Strength`.

The random sequence uses golden-ratio offsets per iteration, which decorrelates samples across iterations and minimises structured banding patterns.

**Edge Mask** runs a Sobel edge detection (BT.709 luminance) on the source and uses it to reduce `Strength` at edges — flat regions receive full diffusion, edges receive none.

---

### Notes

- Higher `Iterations` costs proportionally more GPU time. Values above 32 have diminishing returns.
- `Radius` is in pixels, so the effect is resolution-independent in terms of physical image coverage.
- Source alpha is passed through unchanged.
- The scatter pattern is static per frame (deterministic hash). For a moving/animated look this would need temporal variation via `adsk_time`.

---

## Advection — Edge-Tangent Flow

**Matchbox Shader for Autodesk Flame**
RGBa | v0.2

Advects pixels along the tangent flow field of the image's own edges — the direction that runs *along* contours rather than across them. Two modes offer very different looks from the same underlying technique.

---

### Modes

#### Smear (default)
Walks along the edge tangent for `iterations` steps and samples the image at the final landing position. The result is a directional warp or displacement that follows the image's contour structure. Good for glass distortion, heat shimmer, liquid surfaces, and organic warp effects that feel tied to the image's shapes.

#### Flow / LIC
Line Integral Convolution — walks `iterations` steps forward **and** `iterations` steps backward from each pixel, accumulating colour at every step along the path. Samples are weighted by a Gaussian falloff (steps closer to the origin contribute more). The result is a fibrous, brushstroke-like anisotropic smear that flows along edges — similar to oil paint, Van Gogh-style stroke direction, iridescent fabric, or hair/fibre texture. The total sample count is 2× iterations plus the origin pixel.

---

### Parameters

| Parameter | Type | Range | Default | Description |
|---|---|---|---|---|
| Strength | float | 0.1 – 20.0 | 3.0 | Step size in pixels per iteration. Controls how far each step reaches. |
| Iterations | int | 1 – 32 | 8 | Steps per direction. In Flow mode: 8 → 17 total samples (8 forward + origin + 8 backward). |
| Edge Threshold | float | 0.0 – 1.0 | 0.01 | Minimum gradient magnitude to trigger advection. Raise to restrict the effect to stronger edges and leave flat areas untouched. |
| Flow (LIC) | bool | off / on | off | Switches between Smear and Flow/LIC mode. |
| Flow Bias | float | -180 – 180 | 0.0 | Rotates the walk direction by this many degrees. 0° = along edge tangent. 90° = perpendicular to edge (into/out of the gradient). Values in between give diagonal or mixed flows. |

#### Wave Controls
Applies a sinusoidal rotation to the walk direction at each step, adding ripple or curl to the advection path.

| Parameter | Type | Range | Default | Description |
|---|---|---|---|---|
| Wave Amplitude | float | 0.0 – 3.14 | 0.0 | Rotation amount in radians. 0 = no wave. π ≈ 180° max swing. |
| Wave Frequency | float | 0.0 – 50.0 | 5.0 | Number of wave cycles across the image. |
| Radial Waves | bool | off / on | off | Off = wave phase runs along X axis (parallel bands). On = wave phase is radial distance from Center (concentric rings). |
| Center | vec2 | 0 – 1 | 0.5, 0.5 | Centre point for radial waves in UV coordinates. |

---

### How Flow Bias Works

At 0°, advection walks purely along the edge tangent — contours are smeared along themselves. At 90°, the walk turns perpendicular to the tangent, following the gradient direction instead — contours are smeared *across* themselves, creating a cross-contour blur. At 45°, you get a diagonal combination. Negative values mirror the rotation. This lets you steer the overall flow without losing the edge-aware structure.

---

### Notes

- Gradient is computed using BT.709 luminance `(0.2126, 0.7152, 0.0722)` — correct for HD and linear-light images.
- If the gradient at a step falls below Edge Threshold, the walk stops early for that pixel.
- Higher Iterations with lower Strength (shorter steps) creates denser, more fibrous streaks in Flow mode. Higher Strength with fewer Iterations creates longer, sparser ones.
- Wave controls work in both modes. In Flow mode, wave modulation at each step creates curling or rippling fibre patterns rather than straight streaks.
- Source alpha is passed through in Flow mode. Smear mode returns the full sampled texel (including its alpha) at the walk endpoint.
- Gradient values are clamped before normalization to prevent NaN from Inf-valued pixels (e.g. extreme highlights or over-range EXR values), which would otherwise render as black.

---

## WaveBlur — Parametric Wave Blur

**Matchbox Shader for Autodesk Flame**
RGBa | v1.0

A blur shader where each sample follows a parametric wave curve rather than a simple disc or line. Three kernel modes produce entirely different blur characters — floral, knotted, or spiral — all of which can be deformed with a vortex twist and split into chromatic channels.

---

### Modes

#### Petal (Rose / Rhodonea Curve)
Samples trace a rose curve: `r = size × |cos(complexity × t)|`. Produces N-petal flower kernels. Blurring with a petal kernel creates soft floral halos with directional lobes.

- Integer `complexity` values give clean petals (1, 3, 5 = that many petals; 2, 4, 6 = double that many)
- Non-integer values (e.g. 2.7, 3.4) produce partial or spiral-petal forms — often more interesting
- `Wave Amp` adds a secondary ripple along each petal edge, giving the petals texture

#### Lissajous
Samples trace Lissajous figures — the classic oscilloscope patterns produced by two independent sine waves. `Wave Amp` is the primary creative control in this mode, acting as the phase offset between the two axes.

| Wave Amp | Shape |
|---|---|
| 0.0 | Degenerate diagonal line |
| 0.25 | Tilted ellipse |
| 0.5 | Figure-8 / infinity symbol |
| 1.0 | Classic Lissajous knot (3+ lobes with Complexity ≥ 3) |

`Complexity` sets the x:y frequency ratio. `Complexity=2, WaveAmp=0.5` gives a figure-8. `Complexity=3, WaveAmp=1.0` gives a 3-lobed pretzel.

#### Spiral
Samples trace an Archimedean spiral outward from the centre. `Complexity` controls the number of turns. `Wave Amp` modulates the spiral radius with a sine wave — at low values the arms undulate gently; at high values they fold back on themselves, creating dense overlapping interference patterns.

---

### Parameters

#### Wave
| Parameter | Type | Range | Default | Description |
|---|---|---|---|---|
| Size | float | 0 – 200 | 30.0 | Kernel scale in pixels. Controls overall blur radius. |
| Mode | int | 0 – 2 | 0 | 0 = Petal, 1 = Lissajous, 2 = Spiral |
| Complexity | float | 0.5 – 8.0 | 3.0 | Wave complexity. Petal: petal count. Lissajous: x:y frequency ratio. Spiral: number of turns. |
| Wave Amp | float | 0.0 – 1.0 | 0.5 | Wave modulation depth. Meaning varies per mode — see mode descriptions above. |
| Twist | float | -6 – 6 | 0.0 | Vortex deformation. Quadratic — inner samples stay nearly fixed while outer samples sweep strongly. Cannot be replicated by Rotation: the kernel core holds its shape while the outer arms spiral. Negative values twist counter-clockwise. |

#### Options
| Parameter | Type | Range | Default | Description |
|---|---|---|---|---|
| Rotation | float | 0 – 360 | 0.0 | Rigid rotation of the entire kernel in degrees. Rotates all samples by the same angle. |
| Chroma | float | 0.0 – 1.0 | 0.2 | Chromatic aberration. Scales R and B sample positions apart slightly (7% at max), adding colour fringing along blur trails. 0 = no separation. |
| Samples | int | 8 – 128 | 48 | Sample count. Higher = smoother blur. Lower = the kernel structure becomes visible as a deliberate repeating pattern — intentionally usable as a stylistic effect. |

---

### Twist vs Rotation

These are not the same thing:

**Rotation** shifts every sample by the same angle — the kernel rotates rigidly, like turning a stencil.

**Twist** uses a quadratic curve: at 25% of max radius the sample shifts by only 6% of the twist value; at 50% it shifts by 25%; at the outer edge it shifts by the full amount. The inner part of the kernel holds still while the outer arms sweep into arcs. This is a genuine vortex deformation, not a rotation.

Combined, they let you position the kernel at an angle (Rotation) while independently controlling the vortex character (Twist).

---

### Notes

- Source alpha is passed through unchanged.
- At low sample counts (8–16) the discrete kernel structure is clearly visible. On Petal and Lissajous modes this produces clean geometric ghost patterns rather than a smooth blur — can be used deliberately for a prism or kaleidoscope look.
- Chromatic aberration is always radial — R pushes outward, B pulls inward. The fringing follows whatever shape the kernel traces.

---

## Halation — Film Halation & Bloom

**Matchbox Shader for Autodesk Flame**
RGBa | v0.2

Simulates film halation — the red-orange halo that bleeds from bright areas into dark surroundings on photographic film. Caused by light passing through the emulsion, reflecting off the film backing, and re-exposing the red-sensitive layer. At higher intensities the green layer is also re-exposed, shifting the colour from red toward orange. The blue layer is unaffected.

An optional bloom adds a neutral luminance glow, which commonly accompanies halation around specular highlights.

---

### The Physics

Film emulsion is built in layers. The blue-sensitive layer sits at the front, the green in the middle, and the red-sensitive layer at the back — closest to the film base. When intense light passes through all layers and reflects off the backing, the reflected light re-exposes the red layer first. If the source is bright enough, it also reaches the green layer on the way back. This produces:

- **Red halo** at moderate over-exposure (red layer only)
- **Orange halo** at high over-exposure (red + green layers)
- No blue contribution — the blue layer is at the front and isn't reached by the reflected light
- The halo spreads **outward into dark areas**, not onto the bright source itself
- Effect is most pronounced on 16mm film; minimal on 65mm

---

### Parameters

#### Halation

| Parameter | Type | Range | Default | Description |
|---|---|---|---|---|
| Threshold | float | 0.0 – 1.0 | 0.5 | Minimum luminance to trigger halation. Raise to restrict the effect to only the brightest highlights. |
| Radius | float | 1 – 150 | 30.0 | Scatter radius in pixels. Controls how far the halo extends from the bright source. |
| Softness | float | 0.5 – 8.0 | 2.0 | Falloff rate. Higher = softer, more diffuse halo. Lower = denser, sharper edge. |
| Hue | float | 0.0 – 1.0 | 0.35 | Halo colour shift. 0 = pure red (red layer only). 1 = orange (red + green layers). Physically, higher values simulate more intense re-exposure reaching the green layer. |

#### Amount

| Parameter | Type | Range | Default | Description |
|---|---|---|---|---|
| Amount | float | 0.0 – 5.0 | 1.0 | Overall halation intensity. |
| Bloom | float | 0.0 – 5.0 | 0.0 | Neutral luminance glow intensity. Set to 0 to disable entirely. Bloom uses a wider, softer falloff than halation and has no colour bias. |
| Samples | int | 8 – 64 | 32 | Random sample count. Higher = smoother result. Lower = visible grain. 32 is a good balance between quality and performance. |

---

### How It Works

For each output pixel, the shader takes `Samples` random points within a disc of `Radius` pixels. For each sample it extracts the luminance excess above `Threshold`, then scatters it back to the output pixel weighted by distance falloff:

- **Red contribution**: wide falloff (`exp(-t × softness)`)
- **Green contribution**: tighter falloff (`exp(-t × softness × 3)`), scaled by `Hue`

The two different falloff rates mean the green fringe concentrates near the bright edge, while the red bleeds further out — matching the physical layering where the green layer is spatially closer to the bright source than the red layer.

The accumulated scatter is divided by sample count (not by total weight), which preserves the spatial gradient — pixels close to highlights receive more halation than pixels further away.

A source mask suppresses halation on bright pixels themselves, ensuring the glow bleeds into the dark surroundings rather than adding on top of already-bright areas.

---

### Notes

- All scattering is based on **luminance** (BT.709) rather than RGB channels — the halo colour is always reddish-orange regardless of the source colour. This matches the physical behaviour where halation is a film-layer property, not a colour-accurate blur of the original image.
- `Bloom` is a separate neutral glow with no colour bias — it is not halation but is commonly paired with it.
- Source alpha is passed through unchanged.
- At low sample counts, visible grain appears. This is stochastic and differs per pixel but is static per frame (deterministic hash). A temporal variation could be added via `adsk_time` if animated grain is desired.

---

## Dither — Combined Dither Shader

**Matchbox Shader for Autodesk Flame**
RGBa | v1.0

Six dither algorithms in one shader. All support multi-level quantization, colour or luma mode, and temporal animation.

---

### Algorithms

#### Bayer 2x2
The smallest ordered dither matrix — a 2×2 tile. At `Levels=2` it produces a hard checkerboard. At higher levels the geometric grid becomes a stylised posterize. Most aggressive of the Bayer options; best for a hard graphic look.

#### Bayer 4x4
Classic 4×4 ordered dither. Recognisable video-game / early desktop look. Coarser than 8×8 but with a clear repeating structure that reads as intentional retro style.

#### Bayer 8x8
The standard newspaper halftone grid. At `Levels=2` the screen is fine enough to read as a texture rather than individual cells. The most "correct" ordered dither for general use.

#### White Noise
Per-pixel random hash — no spatial structure whatsoever. Looks like film grain. Pairs well with high `Levels` for a subtle textured quantize. At `Levels=2` it reads as pure noise rather than a pattern.

#### IGN (Interleaved Gradient Noise)
Interleaved Gradient Noise: a screen-space noise function that covers frequencies more uniformly than white noise. Less structured than Bayer, smoother than white noise. Good general-purpose noise dither with a slightly organic character.

#### Error Diffusion
A GPU-feasible approximation of error-diffusion dithering (Floyd-Steinberg style). True error diffusion requires sequential pixel access — impossible in a parallel fragment shader. This approximation runs two independent 1D sweeps: one along the x-axis, one along the y-axis, each scanning a window of `Scan Size` pixels. The error carried out of each sweep is averaged and applied to the current pixel before its own quantization.

The result has the organic, ink-like character of real error diffusion — edges bleed and adapt to local contrast — without the horizontal streaking of a pure x-only sweep. Larger `Scan Size` values carry error further and produce a more connected appearance. Works in both colour and luma mode.

---

### Parameters

#### Dither
| Parameter | Type | Range | Default | Description |
|---|---|---|---|---|
| Algo | int | 0 – 5 | 2 | Dither algorithm. 0=Bayer 2x2, 1=Bayer 4x4, 2=Bayer 8x8, 3=White Noise, 4=IGN, 5=Error Diffusion. |
| Levels | int | 2 – 16 | 2 | Quantization steps. 2 = B&W or primary colours. Higher = colour posterize with intermediate steps. |
| Spread | float | 0 – 2 | 1.0 | Dither amplitude. 0 = flat quantize (no dither). 1 = standard. >1 = coarser, over-dithered texture. |
| Scan Size | int | 1 – 32 | 8 | Error diffusion only. Window of pixels scanned left and down. Larger = error travels further. |

#### Options
| Parameter | Type | Range | Default | Description |
|---|---|---|---|---|
| Color | bool | — | on | On: each RGB channel dithered independently (colour output). Off: BT.709 luminance dithered, output is B&W. |
| Temporal | bool | — | off | Shifts the threshold each frame by the golden ratio (0.618…). Smooths the dither pattern over time. |
| Error Carry | float | 0 – 1 | 0.85 | Error diffusion only. How much quantization error propagates from pixel to pixel. 0 = none. 1 = full carry. |

---

### Temporal Dithering

When **Temporal** is on, the dither threshold shifts each frame by 0.618… (the golden ratio). This is the most irrational number — subsequent frames never land on the same threshold positions until frame 144, and even then the coverage is near-perfect. Over a short sequence of frames, the dither pattern integrates toward a smooth gradient.

This works on all threshold-based modes (Bayer 2x2/4x4/8x8, White Noise, IGN). It has no effect on Error Diffusion.

Practical use: temporal dithering is most useful on static or slow-moving material where the eye can integrate across frames. On fast movement it reads as animating grain, which can also be intentional.

---

### Color vs Luma Mode

**Color off:** BT.709 luminance is computed (`0.2126R + 0.7152G + 0.0722B`), dithered as a single channel, and the output is greyscale. This is the classic high-contrast dither look — black and white output regardless of the source colour.

**Color on:** Each RGB channel is dithered independently with the same threshold offset. Source colour is preserved (quantized into bands). At `Levels=2` this gives a 3-bit-per-channel palette (8 possible colours). At `Levels=4` you get 4 steps per channel (64 colours).

---

### Notes

- Source alpha is passed through unchanged.
- Error diffusion is fundamentally a sequential algorithm. The 1D sweep approximation reads pixels that have already been processed by the GPU in screen order — the approximation is convincing but not identical to CPU-side Floyd-Steinberg.
- At `Levels=2, Spread=1, Color=off, Algo=2`: matches classic Bayer 8x8 B&W halftone.
- `Spread=0` disables dithering entirely and produces flat quantization — useful for comparing dithered vs undithered posterize.
