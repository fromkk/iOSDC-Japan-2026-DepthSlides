---
title: Comparing Depth Estimation Models to Give iPhone Photos Mirrorless-Grade Bokeh
published: false
description: How I compared MiDaS, Depth Anything V2/3 and Depth Pro on Core ML, and used Core Image blur filters to give iPhone photos a mirrorless-style bokeh. A write-up of my iOSDC Japan 2026 talk.
tags: ios, swift, coreml, machinelearning
cover_image: # TODO: cover image URL
canonical_url: # TODO: Medium URL after publishing there first (or leave empty if dev.to is the canonical)
---


*A write-up of my talk at iOSDC Japan 2026, the largest iOS developer conference in Japan.*

<!-- TODO: title slide image -->

- Slides: <!-- TODO: Speaker Deck URL -->
- Sample code: https://github.com/fromkk/iOSDC_DepthSlides <!-- TODO: keep only if the repo is public -->

## A quick question

<!-- TODO: side-by-side image of IMG_2569 (iPhone) and SDIM4295_2 (SIGMA fp) -->

Which of these two photos was shot on an iPhone?

The answer is the left one. It was taken with an iPhone 17 Pro. The right one was taken with a SIGMA fp and a 28–70mm F2.8 lens. They were shot the same way, but they feel different. The iPhone photo keeps the background sharp, so there is a lot going on, while the mirrorless photo makes it obvious what the subject is.

The goal of this talk is simple: take the iPhone photo on the left and, in post-processing, get it closer to the one on the right, where only the subject stands out.

## About me

I'm Kazuya Ueoka (@fromkk), an iOS developer based in Saitama, Japan. I love shooting photos with real cameras, and I build a photo color-grading and retouching app called ToneCraft.

## How a camera forms an image

Before we talk about bokeh, let's go back to the beginning.

### Camera obscura

The origin of the camera goes back to around 400 BC. The Chinese philosopher Mozi recorded that if you make a small hole in a dark box, light from outside enters and projects an inverted image. He even understood why: light travels in straight lines. This "small dark room" is the camera obscura.

Around the 15th century, Leonardo da Vinci is said to have used it for sketching. It wasn't for recording images; it was for projecting a scene onto translucent paper and tracing it.

### Lenses

A pinhole lets in very little light, so the image is dark. Lenses solved that. Early cameras used a simple convex lens, like a magnifying glass. Modern lenses combine many convex and concave elements.

A convex lens gathers light from a wide area into a single point, the focal point. That's the same point where a magnifying glass sets paper on fire. And if you change the distance between the lens and the object, the image no longer lands on the screen, and the object stops being sharp. That is what bokeh is.

<!-- TODO: screenshot of the convex lens simulator -->

### Aperture and f-number

Once a lens gathers plenty of light, a new problem appears: too much light. You get flare and aberrations, and the depth of field becomes so shallow that focusing is hard. So we add an aperture to limit the light. Stopping down makes the depth of field deeper and focusing easier.

The f-number expresses how far the aperture is open: **focal length ÷ aperture diameter**. A smaller number means a wider opening and more bokeh; a larger number means a smaller opening and less bokeh.

<!-- TODO: sequence of real photos from f/1.4 stopping down (ApertureSamples) -->

### Sensor size

A larger sensor gathers more light and has a shallower depth of field, so it blurs more easily.

The largest sensor in the iPhone 17 Pro is 1/1.28" (9.8×7.3mm). Compared with a full-frame sensor (36×24mm), that's roughly 1/12 of the area.

<!-- TODO: to-scale sensor size diagram (SensorSizeDiagramView) -->

## Why iPhone photos don't blur, and how to shoot around it

Putting all that together, iPhone photos have these characteristics:

- The sensor is small, so depth of field is deep and there is little bokeh to begin with
- The image processing aims to make everything sharp, as if everything were in focus
- As a result, the subject gets buried in the background and the photo looks busy

You can still earn some bokeh with technique:

1. **Get close to the subject.** Depth of field gets shallower as the subject gets closer.
2. **Separate the subject from the background.** The farther the background, the bigger the blur.
3. **Shoot with the telephoto lens (2x / 5x).** Longer focal lengths mean shallower depth of field.

### Portrait mode

Portrait mode was Apple's answer to this. It first shipped in iOS 10.1 in October 2016 for the iPhone 7 Plus, estimating depth from the parallax between the two rear cameras and blurring everything except the subject. Since the iPhone 12 Pro, the LiDAR scanner has improved depth accuracy. These days you can shoot normally and change the f-number afterwards.

But depending on the photo, the blur can still look off.

## The main part: get depth, then blur with it

What we do is the same thing Portrait mode does, in two steps:

1. Get **depth** from the photo
2. Use the depth to **blur the background**

For depth, I tried both the AVDepthData embedded in the photo and publicly distributed ML models. For blur, I compared every blur filter Core Image has.

## Depth, option 1: read the depth embedded in the photo

A HEIC shot in Portrait mode may contain AVDepthData as auxiliary data. You can pull it out through ImageIO:

```swift
let source = CGImageSourceCreateWithData(data as CFData, nil)!
let info = [kCGImageAuxiliaryDataTypeDepth, kCGImageAuxiliaryDataTypeDisparity]
  .lazy
  .compactMap {
    CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, $0) as? [AnyHashable: Any]
  }
  .first!
let depthData = try AVDepthData(fromDictionaryRepresentation: info)

// Normalize to disparity (near = large value = bright)
let converted = depthData.converting(
  toDepthDataType: kCVPixelFormatType_DisparityFloat32
)
var depthImage = CIImage(cvPixelBuffer: converted.depthDataMap)

// The depth map is stored in the sensor's raw orientation, so apply
// the main image's EXIF orientation to it as well
if let orientation = exifOrientation(from: source) {
  depthImage = depthImage.oriented(orientation)
}
```

<!-- TODO: IMG_1606 original vs. AVDepthData comparison -->

The catch: this only exists in photos shot in Portrait mode, or where the subject and background were cleanly separable at capture time. A normal photo, or a photo from another camera, has no depth at all. That's where ML models come in.

## Depth, option 2: estimate it with a distributed ML model

I tried four models. Sorted by release date, they read like a history of monocular depth estimation.

| | MiDaS Small | Depth Anything V2 Small | Depth Pro | Depth Anything 3 (DA3-SMALL) |
|---|---|---|---|---|
| Released | 2020 | Jun 2024 | Oct 2024 | Nov 2025 |
| By | Intel ISL | HKU / TikTok | Apple | ByteDance |
| Backbone | CNN | ViT-S | ViT-L ×2 | ViT-S class |
| Parameters | ~21M | 24.8M | ~504M | 0.08B (nominal) * |
| Model size | 32MB | 48MB | **1.8GB** | 61MB |
| Input | 256×256 | 518×392 | 1536×1536 | 504×378 |
| Depth type | Relative | Relative | **Absolute (meters)** | Relative |
| License | MIT | Apache-2.0 | apple-amlr | Apache-2.0 |

\* Only the monocular depth part converted to Core ML (61MB, FP16)

From CNN-based MiDaS in 2020, to the ViT-based Depth Anything V2, to Apple's Depth Pro going all in on resolution and accuracy, to Depth Anything 3, a 3D foundation model that also handles multiple views. V2 was a joint effort by HKU and TikTok; version 3 is ByteDance Seed alone, and the "V" was dropped from the name.

Look at the model size row. Depth Pro is 1.8GB, two orders of magnitude larger than the others, which all fit in 32–61MB. If you're bundling a model into an app, that difference dominates. In practice, Depth Pro hit the iOS runtime memory limit, and I could only run it on macOS.

### Relative vs. absolute depth

MiDaS and Depth Anything return **relative depth**: you know what's nearer and what's farther, and nothing more. For bokeh, that's enough. Depth Pro returns **absolute depth** in meters and can even estimate the focal length, which is what you'd want to reproduce a real lens's depth-of-field math.

### Licenses

Licenses are easy to overlook. Only the Small variants are Apache-2.0. Depth Anything V2 Base and up, and Depth Anything 3 Large and up, are CC-BY-NC-4.0, which rules out commercial use. Depth Pro ships under the Apple Machine Learning Research Model License, so it's safest to assume you can't put it in a commercial app.

**The most accurate model isn't necessarily one you can ship.**

### Things to watch out for with distributed models

- **You need to convert them for Core ML / Core AI.** Core AI is the successor to Core ML announced at WWDC26. <!-- TODO: confirm SDK versions (slides say Xcode 27 / iOS 20 SDK) -->
- **The models are large.** Bundling one grows your app accordingly.
- **Depth Pro needs Mac-class hardware,** especially memory.
- **Licenses differ per model,** and even per size of the same model.

### Converting to Core ML and running inference

Apple distributes a pre-converted Core ML package for Depth Anything V2 Small, so you just download it:

```python
from huggingface_hub import snapshot_download

snapshot_download(
    repo_id="apple/coreml-depth-anything-v2-small",
    allow_patterns=["DepthAnythingV2SmallF16.mlpackage/*"],
)
```

For Depth Anything 3, I converted from PyTorch myself. A thin wrapper returns only the depth tensor from DA3's output dict, and that wrapper is traced and passed to coremltools:

```python
wrapper = DepthOnlyWrapper(da3.model, depth_key).eval()
traced = torch.jit.trace(wrapper, (imgs,), strict=False)

mlmodel = ct.convert(
    traced,
    inputs=[ct.TensorType(name="image", shape=imgs.shape)],
    outputs=[ct.TensorType(name="depth")],
    convert_to="mlprogram",
    compute_precision=ct.precision.FLOAT16,
    minimum_deployment_target=ct.target.iOS17,
)
mlmodel.save("DepthAnythingV3Small.mlpackage")
```

On the Swift side, inference looks like this. DA3's depth is "smaller = nearer", so after min-max normalization I invert it to "nearer = brighter":

```swift
// Pack a (1, 1, 3, H, W) rank-5 tensor with ImageNet normalization applied
let inputArray = try normalizedImageNetTensor(from: pixelBuffer, width: width, height: height)
let provider = try MLDictionaryFeatureProvider(dictionary: ["image": inputArray])
let prediction = try model.prediction(from: provider)

// depth: smaller value = nearer
let depth = prediction.featureValue(for: "depth")!.multiArrayValue!
let depthImage = try normalizedGrayscaleImage(from: depth, invertForNearBright: true)
```

Every model has different input/output names and shapes, some of them auto-generated during conversion. I put a single adapter layer in front of the four models that normalizes every output into a "nearer = brighter" grayscale image, so the blur stage never needs to know which model produced the depth.

### How the models differ

<!-- TODO: comparison image of the same photo through embedded depth / MiDaS / DA V2 / Depth Pro / DA3 -->

The depth embedded in the photo loses a lot of fine detail. Depth Anything holds a reasonable amount of detail, and Depth Pro produces a strikingly crisp depth map. That accuracy carries straight through to the quality of the blur.

## Blur: comparing Core Image's blur filters

With depth in hand, the next step is the blur. We use the depth as a mask and blur only the background with a Core Image filter.

Core Image has seven blur filters. By role, they fall into four groups:

- **Uniform blur**: CIBoxBlur / CIDiscBlur / CIGaussianBlur. They differ only in the kernel shape (square, disc, Gaussian).
- **Spatially varying blur**: CIMaskedVariableBlur. A grayscale mask controls the blur strength per pixel, so a depth map can be used as the mask directly.
- **Lens-like**: CIBokehBlur. A circular blur with adjustable ring highlight and softness, the closest to how a real lens renders bokeh.
- **Effect-oriented**: CIZoomBlur / CIMotionBlur. These express motion, not defocus, so they don't fit.

### Building the mask

Depth is "nearer = brighter", but CIMaskedVariableBlur treats "brighter = blur more", so we invert it. There's a subtlety: after min-max normalization, only the single nearest point is exactly 0, and the subject as a whole usually isn't near 0. So I apply a gamma curve that pushes low-to-mid values toward 0, keeping the subject sharp while the blur ramps up quickly with distance.

```swift
import CoreImage.CIFilterBuiltins

// depth: nearer = brighter / farther = darker
let invertedMask = CIImage(cgImage: depth).applyingFilter("CIColorInvert")
let contrastedMask = invertedMask.applyingFilter(
  "CIGammaAdjust", parameters: ["inputPower": 3.0])

let blur = CIFilter.maskedVariableBlur()
blur.inputImage = CIImage(cgImage: original)
blur.mask = contrastedMask     // farther (= brighter) blurs more
blur.radius = 24
let cropped = blur.outputImage!.cropped(to: CIImage(cgImage: original).extent)
let blurredCGImage = CIContext().createCGImage(cropped, from: cropped.extent)
```

### Using the other filters

The six filters other than CIMaskedVariableBlur can't vary the blur radius per pixel. So I blur the whole image uniformly first, then composite with CIBlendWithMask using the same mask:

```swift
let f = CIFilter.bokehBlur()
f.inputImage = CIImage(cgImage: original).clampedToExtent()  // avoid transparent edges
f.radius = 24
f.ringAmount = 0
f.ringSize = 0.1
f.softness = 1

let blend = CIFilter.blendWithMask()
blend.inputImage = f.outputImage        // blurred
blend.backgroundImage = CIImage(cgImage: original)
blend.maskImage = mask                  // brighter (= farther) picks the blurred image
```

### Choosing a focus point

Instead of "focus on the nearest thing", you usually want "focus where the user tapped". For that, the mask becomes the absolute difference between each pixel's depth and the depth at the tap point. The bigger the difference, the stronger the blur, so both nearer and farther regions blur, just like a real focal plane.

The gotcha here was color spaces. My first version filled a constant image with the focus depth via `CIImage(color:)` and compared with `CIColorAbsoluteDifference`. But `CIColor` implicitly carries a working color space, so the "same" focus value got gamma-converted on its way in, and even the pixel directly under the tap ended up slightly blurred. The fix was to load the depth image with `colorSpace: NSNull()`, subtract the focus value through the bias term of `CIColorMatrix`, and take the absolute value with `CIMaximumCompositing` against the negated copy, never creating a second image with its own color space.

You also need a dead zone: a range around the focus depth that stays perfectly sharp, the equivalent of a real camera's depth of field. Real subjects aren't flat, so without it, even the area right next to the tap picks up a faint blur and looks wrong.

### Filter comparison

<!-- TODO: 7-filter grid image (BokehFilterResultGridView) -->

I went with CIBokehBlur.

## Results

Here are photos processed with DA3-SMALL for depth and CIBokehBlur for the blur. Left is the original, right is the result.

<!-- TODO: result_01–07 before/after pairs (Media.xcassets result_0N_before / result_0N_after) -->

The colors change too, but that's color grading done in ToneCraft.

## Takeaways

What we covered:

- The history and mechanics of cameras
- Reading depth embedded in photos
- Estimating depth with distributed models
- Comparing blur filters

What I chose:

- Model: **Depth Anything 3 (DA3-SMALL)**
- Filter: **CIBokehBlur**

Accuracy trades off against model size, runtime constraints, and licensing, and the best model isn't necessarily one you can ship. Right now, DA3-SMALL, which is small, Apache-2.0, and runs on an actual iPhone, is the practical sweet spot.

## This shipped in ToneCraft

Everything above is in ToneCraft v1.5 as the "Focus Blur" (f) tool. Tap to set the focus point, drag a slider for the amount, and all processing happens on-device.

- App Store: https://apps.apple.com/app/id6760603749

<!-- TODO: tone_craft_shot image or a GIF of the tool in use -->

## Bonus: what else depth gives you

Once you have depth, bokeh is just the start:

- Remove the background, keeping only the foreground
- Select the region with depth similar to the tapped point as an object
- Generate left/right parallax to make a spatial photo viewable on Vision Pro
- Depth-based fog, or relighting
- Build a point cloud or mesh from a single photo
- Correct occlusion between virtual and real objects in AR

Background removal in particular is almost the same pipeline as bokeh: threshold the depth map with CIColorMatrix to build a mask, then composite with CIBlendWithMask.

<!-- TODO: background removal demo screenshot -->

## References

- Depth Anything V2 (Core ML): https://huggingface.co/apple/coreml-depth-anything-v2-small
- Depth Anything 3: https://huggingface.co/depth-anything/DA3-SMALL
- Depth Pro (Core ML): https://huggingface.co/coreml-projects/DepthPro-coreml
- MiDaS: https://github.com/isl-org/MiDaS
- Koji Ando, *カメラとレンズのしくみがわかる光学入門* (Impress, Japanese): https://amzn.to/4gWqVue
