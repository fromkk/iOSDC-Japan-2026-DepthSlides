# 複数の深度推定モデルを比較して、iPhoneで撮影した写真のボケをミラーレス級に近づける（iOSDC Japan 2026 登壇まとめ）

<!-- TODO: 冒頭にタイトルスライドの画像 -->

iOSDC Japan 2026 で「複数の深度推定モデルを比較して、iPhoneで撮影した写真のボケをミラーレス級に近づける」というタイトルで登壇しました。この記事は、そのトークの内容を文章として読めるようにまとめ直したものです。

- スライド: <!-- TODO: Speaker Deck などの URL -->
- サンプルコード: https://github.com/fromkk/iOSDC_DepthSlides <!-- TODO: 公開リポジトリなら残す。非公開なら削除 -->

## いきなり質問です

<!-- TODO: IMG_2569（iPhone）と SDIM4295_2（SIGMA fp）を横並びにした画像 -->

どちらが iPhone で撮った写真でしょうか？

正解は左です。左が iPhone 17 Pro、右が SIGMA fp と 28–70mm F2.8 のレンズで撮ったものです。同じように撮った写真なのに、印象が違います。iPhone のほうは背景までくっきり写っているために情報量が多く、右のほうが「主題が何か」がはっきりしています。

今日のゴールは、左の iPhone で撮った写真を後処理で、右のミラーレスで撮ったような「主題だけが浮き上がる写真」に近づけることです。

## 自己紹介

植岡 和哉（@fromkk）と申します。iOS アプリを作る仕事をしていて、カメラで写真を撮るのが好きです。写真の色補正・レタッチアプリ「ToneCraft」を個人で開発しています。

## そもそもカメラはどうやって像を作っているのか

ボケの話をする前に、カメラの仕組みを原点から振り返ります。

### カメラ・オブスキュラ

カメラの原点は紀元前 400 年ごろにさかのぼります。戦国時代の思想家・墨子の著作『墨経』に、暗い箱に小さな穴をあけると外の光が入り、逆さに投影されることが記録されています。光がまっすぐ進むから像が逆さになる、という理由まで正しく理解していたそうです。この「小さな暗い部屋」がカメラ・オブスキュラです。

15 世紀ごろにはレオナルド・ダ・ヴィンチが写生に利用したとされていて、当初は記録用ではなく、半透明の紙に投影した像をなぞって絵を描くために使われていました。

### レンズ

針の穴だけのカメラ・オブスキュラは光量が少なくて暗い、という問題がありました。これを解決するために使われるようになったのがレンズで、当初は虫眼鏡のような凸レンズが一般的でした。現代のレンズは凸レンズ・凹レンズを何枚も組み合わせて作られています。

凸レンズは広い範囲の光を一箇所に集めることができます。虫眼鏡で太陽の光を集めて紙を燃やす、あの光が集まる点が焦点です。そして、レンズと物体の距離を変えると像を結ぶ位置がずれて、物体がはっきり写らなくなります。これがボケの正体です。

<!-- TODO: 凸レンズシミュレーターのスクリーンショット -->

### 絞りと f値

レンズで光を集められるようになると、今度は明るすぎるという問題が出てきます。にじみや収差が出たり、被写界深度が浅くなりすぎてピントを合わせるのが大変になったりします。そこで絞りで入ってくる光を制限します。絞ると被写界深度が深くなり、ピントが合わせやすくなります。

この絞り具合を表すのが f値で、**焦点距離 ÷ 絞りの直径** です。小さいほど開いていてボケる、大きいほど絞っていてボケない、という関係です。

<!-- TODO: f/1.4 → 絞っていく実写の連続写真（ApertureSamples） -->

### センサーサイズ

センサーが大きいほどたくさんの光を受け取れて、被写界深度が浅くなります。つまりボケやすくなります。

iPhone 17 Pro の一番大きなセンサーは 1/1.28 型（9.8×7.3mm）で、フルサイズ（36×24mm）と面積で比べると約 12 分の 1 しかありません。

<!-- TODO: センサーサイズ実寸比の図（SensorSizeDiagramView） -->

## iPhone の写真がボケにくい理由と、撮り方の工夫

ここまでの話を踏まえると、iPhone の写真には次の特徴があります。

- センサーが小さいので被写界深度が深く、そもそもボケにくい
- 全体をはっきり写す絵作りで、どこにもピントが合っているように見せにいく
- 結果として主題が背景に埋もれ、情報量の多い写真になりがち

とはいえ撮り方の工夫でボケを稼ぐことはできます。

1. **被写体に近づく**: 被写界深度は被写体までの距離が近いほど浅くなる
2. **被写体と背景を離す**: 背景が遠いほどボケは大きくなる
3. **望遠側（2x / 5x）で撮る**: 焦点距離が長いほど被写界深度は浅くなる

### ポートレートモード

ボケにくさを補うために登場したのがポートレートモードです。2016 年 10 月配信の iOS 10.1 で iPhone 7 Plus 向けに初登場し、当初はデュアルカメラの視差から深度を推定して、対象以外にボケを生成していました。iPhone 12 Pro 以降は LiDAR スキャナも活用されて深度の精度が上がっています。最近は普通に撮影して、あとから f値を変更することもできます。

ただ、撮影した写真によってはボケに違和感があることもあります。

## 本題: 深度を手に入れて、深度をもとにぼかす

やることはポートレートモードと同じで、2 ステップです。

1. 写真から **深度** を手に入れる
2. 深度をもとに **背景をぼかす**

深度は「写真に埋め込まれた AVDepthData を使う方法」と「配布されている ML モデルで推定する方法」を試しました。ぼかすほうは Core Image のブラーフィルターを一通り比較しました。

## 深度 1: 写真に埋め込まれた深度情報を取得する

ポートレートモードで撮った HEIC には、AVDepthData が補助データとして埋め込まれていることがあります。ImageIO 経由で次のように取り出せます。

```swift
let source = CGImageSourceCreateWithData(data as CFData, nil)!
let info = [kCGImageAuxiliaryDataTypeDepth, kCGImageAuxiliaryDataTypeDisparity]
  .lazy
  .compactMap {
    CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, $0) as? [AnyHashable: Any]
  }
  .first!
let depthData = try AVDepthData(fromDictionaryRepresentation: info)

// 視差(disparity)形式に統一して取り出す（近い = 値が大きい = 明るい）
let converted = depthData.converting(
  toDepthDataType: kCVPixelFormatType_DisparityFloat32
)
var depthImage = CIImage(cvPixelBuffer: converted.depthDataMap)

// 深度マップはセンサーの生の向きで格納されているため、本体画像の
// EXIF Orientation を読み取って同じ回転を適用する
if let orientation = exifOrientation(from: source) {
  depthImage = depthImage.oriented(orientation)
}
```

<!-- TODO: IMG_1606 の元画像と AVDepthData の比較画像 -->

ただしこれは、iPhone のポートレートモードで撮った写真か、被写体と背景がいい感じに分離されている写真にしか入っていません。普通に撮った写真や他社のカメラの写真には深度がありません。そこで ML モデルの出番です。

## 深度 2: 配布されている ML モデルで深度を推定する

今回は次の 4 つを試しました。リリースの古い順に並べると、そのまま深度推定の進化の歴史になっています。

| | MiDaS Small | Depth Anything V2 Small | Depth Pro | Depth Anything 3 (DA3-SMALL) |
|---|---|---|---|---|
| 公開 | 2020年 | 2024年6月 | 2024年10月 | 2025年11月 |
| 開発元 | Intel ISL | HKU / TikTok | Apple | ByteDance |
| バックボーン | CNN | ViT-S | ViT-L ×2 | ViT-S 相当 |
| パラメーター数 | 約21M | 24.8M | 約504M | 公称 0.08B ※ |
| モデルサイズ | 32MB | 48MB | **1.8GB** | 61MB |
| 入力解像度 | 256×256 | 518×392 | 1536×1536 | 504×378 |
| 深度の種類 | 相対深度 | 相対深度 | **絶対深度（メートル）** | 相対深度 |
| ライセンス | MIT | Apache-2.0 | apple-amlr | Apache-2.0 |

※ 単眼深度推論に使う部分のみを Core ML 変換したもの（61MB / FP16）

2020 年の CNN ベースの MiDaS から、ViT ベースになった Depth Anything V2、高解像・高精度に振った Apple の Depth Pro、そして複数視点にも対応した 3D 基盤モデルの Depth Anything 3 という流れです。V2 は香港大学と TikTok の共同ですが、3 は ByteDance Seed 単独で、名前も V が取れて Depth Anything 3 になっています。

注目してほしいのはモデルサイズです。Depth Pro だけ 1.8GB と桁が 2 つ違います。他の 3 つは 32〜61MB に収まっているので、アプリに同梱することを考えるとこの差はかなり効きます。実際 Depth Pro は iOS の実行時メモリ上限に抵触して、今回は macOS でしか動かせませんでした。

### 深度の種類

MiDaS と Depth Anything は **相対深度** で、どこが手前でどこが奥か、という相対的な関係だけが分かります。ボケを作るだけならこれで十分です。一方 Depth Pro は **絶対深度** で、メートル単位の実距離を返してくれて、焦点距離の推定もできます。本物のレンズの被写界深度計算を再現したい場合はこちらが有効です。

### ライセンス

見落としがちなのがライセンスです。Apache-2.0 なのは実は Small だけで、Depth Anything V2 は Base 以上、Depth Anything 3 は Large 以上が商用不可の CC-BY-NC-4.0 です。Depth Pro も Apple Machine Learning Research Model License という研究用ライセンスなので、商用アプリへの組み込みは不可と考えるのが安全です。

**精度が良いモデルがそのままアプリに使えるとは限らない**、というのは注意が必要なポイントです。

### 配布モデルを使う際の注意点

- **Core ML / Core AI 用に変換が必要**: Core AI は WWDC26 で発表された Core ML の後継フレームワーク <!-- TODO: 対応 SDK のバージョン表記をスライド（Xcode 27 / iOS 20 SDK）と確認 -->
- **モデルのサイズが大きい**: アプリに同梱するぶん、アプリのサイズも増える
- **Depth Pro は Mac 並みの性能が要る**: とくにメモリを要求する
- **ライセンスがモデルごとに違う**: 同じモデルでもサイズによって商用可否が変わる

### Core ML への変換と推論

Depth Anything V2 Small は Apple が変換済みの Core ML パッケージを公式配布しているので、ダウンロードするだけで使えます。

```python
from huggingface_hub import snapshot_download

snapshot_download(
    repo_id="apple/coreml-depth-anything-v2-small",
    allow_patterns=["DepthAnythingV2SmallF16.mlpackage/*"],
)
```

Depth Anything 3 は PyTorch から自前で変換しました。生出力の dict から depth テンソルだけを返す薄いラッパーを trace して coremltools に渡します。

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

Swift 側の推論はこうなります。DA3 の depth は「近いほど値が小さい」ので、min-max 正規化した上で反転して「近い = 明るい」に揃えています。

```swift
// (1, 1, 3, H, W) の5階テンソルに ImageNet 正規化を施して詰める
let inputArray = try normalizedImageNetTensor(from: pixelBuffer, width: width, height: height)
let provider = try MLDictionaryFeatureProvider(dictionary: ["image": inputArray])
let prediction = try model.prediction(from: provider)

// depth は近いほど値が小さい
let depth = prediction.featureValue(for: "depth")!.multiArrayValue!
let depthImage = try normalizedGrayscaleImage(from: depth, invertForNearBright: true)
```

モデルごとに入出力の名前や形が違う（変換時に自動生成されることもある）ので、4 モデル分の差分を吸収する層を 1 つ作って、出力を「近い = 明るいグレースケール画像」に統一しておくと、後段のボケ処理をモデルに依存せず書けます。

### モデルごとの深度の違い

<!-- TODO: シミュレーターで同じ写真を 埋め込み深度 / MiDaS / DA V2 / Depth Pro / DA3 で切り替えた比較画像 -->

写真に埋め込まれている深度は細かい情報が抜け落ちています。Depth Anything はそこそこ詳細な情報を持っていて、Depth Pro に至っては鮮明な深度になります。この精度が、そのままボケを加えるときの精度に繋がります。

## ぼかす: Core Image のブラーフィルターを比較する

深度が手に入ったので、次はボカし方です。深度をマスクにして、Core Image のブラーフィルターで背景だけをボカします。

Core Image には 7 種類のブラーがありますが、役割で分けると 4 グループになります。

- **一様にぼかす**: CIBoxBlur / CIDiscBlur / CIGaussianBlur。ぼかす範囲の形（正方形・円・ガウス分布）が違うだけ
- **場所ごとに強さを変える**: CIMaskedVariableBlur。グレースケールのマスクでボケの強さを変えられるので、深度マップをそのままマスクにできる
- **レンズ風**: CIBokehBlur。円形のボケにリング状の強調と柔らかさを加えられる、レンズのボケ味に一番近いフィルター
- **演出寄り**: CIZoomBlur / CIMotionBlur。ブレの表現なので今回の目的には合わない

### マスクの作り方

深度は「近い = 明るい」ですが、CIMaskedVariableBlur は「マスクが明るいほど強くぼかす」規約なので反転します。さらに、min-max 正規化した深度はシーン内で最も近い 1 点だけが 0 になり、被写体全体としては 0 付近にならないことが多いので、ガンマカーブで低め〜中間の値を 0 側に寄せて、被写体はシャープに、背景ほど急にボケが強まるようにしています。

```swift
import CoreImage.CIFilterBuiltins

// depth: 近い = 明るい / 遠い = 暗い
let invertedMask = CIImage(cgImage: depth).applyingFilter("CIColorInvert")
let contrastedMask = invertedMask.applyingFilter(
  "CIGammaAdjust", parameters: ["inputPower": 3.0])

let blur = CIFilter.maskedVariableBlur()
blur.inputImage = CIImage(cgImage: original)
blur.mask = contrastedMask     // 遠い(=明るい)ほど強くぼかす
blur.radius = 24
let cropped = blur.outputImage!.cropped(to: CIImage(cgImage: original).extent)
let blurredCGImage = CIContext().createCGImage(cropped, from: cropped.extent)
```

### CIMaskedVariableBlur 以外のフィルターの使い方

CIMaskedVariableBlur 以外の 6 つは画素ごとに変化するボケ半径を持てません。そこで画像全体に一様にボケをかけてから、同じマスクで CIBlendWithMask 合成します。

```swift
let f = CIFilter.bokehBlur()
f.inputImage = CIImage(cgImage: original).clampedToExtent()  // 端が透明にならないように
f.radius = 24
f.ringAmount = 0
f.ringSize = 0.1
f.softness = 1

let blend = CIFilter.blendWithMask()
blend.inputImage = f.outputImage        // ボケ済み
blend.backgroundImage = CIImage(cgImage: original)
blend.maskImage = mask                  // 明るい(=遠い)ほどボケ済みを採用
```

### ピント位置を指定する

「一番近いところにピント」ではなく、タップした位置にピントを合わせたい場合は、その位置の深度値との絶対差をマスクにします。差が大きいほど強くぼけるので、手前・奥のどちらも指定位置から離れていればボケる、実際のカメラのピント面に近い挙動になります。

実装でハマったのは色空間です。焦点の深度値を `CIImage(color:)` で塗りつぶした定数画像と `CIColorAbsoluteDifference` で比較すると、`CIColor` が暗黙に作業色空間を持つせいで、同じ数値のはずの焦点値がガンマ変換を受けて食い違い、タップした真下のピクセルでさえ薄くぼけてしまいました。深度画像を `colorSpace: NSNull()` で読み込んだ上で、`CIColorMatrix` のバイアス項で焦点値を引き、符号反転したものとの `CIMaximumCompositing` で絶対値を取る、という形にして回避しています。

また、被写体の表面内でも深度は微妙に変化するので、焦点距離との差がある範囲内なら完全にシャープなままにするデッドゾーン（実カメラの被写界深度に相当）を設けないと不自然に見えます。

### フィルターごとの違い

<!-- TODO: 7 フィルターのグリッド比較画像（BokehFilterResultGridView） -->

今回は CIBokehBlur を選びました。

## 作例

DA3-SMALL で深度を推定して CIBokehBlur をかけた結果です。左が元の写真、右が処理後です。

<!-- TODO: result_01〜07 の Before / After（Media.xcassets の result_0N_before / result_0N_after） -->

ボケだけでなく色味も変わって見えますが、これは ToneCraft で色補正をしています。

## まとめ

今日やったこと

- カメラの歴史と仕組みを振り返る
- 写真に埋め込まれた深度情報を取得する
- 配布されているモデルで深度を推定する
- ボケのフィルターを比較する

今回の選択

- モデル: **Depth Anything 3 (DA3-SMALL)**
- フィルター: **CIBokehBlur**

「精度」と「モデルサイズ・動作環境・ライセンス」はトレードオフで、精度の良いモデルがそのままアプリに使えるとは限りません。現時点では、軽量で Apache-2.0 で iOS 実機でも動く DA3-SMALL が、実用の落としどころだと考えています。

## ToneCraft の「フォーカスぼかし」

今回話した深度推定とボケは、自作の写真編集アプリ ToneCraft の v1.5 に「フォーカスぼかし（f ツール）」として入れてあります。写真をタップしてピント位置を決めて、スライダーでボケ量を調整するだけです。処理はすべて端末の中で完結します。

- App Store: https://apps.apple.com/jp/app/id6760603749

<!-- TODO: tone_craft_shot の画像 or 操作動画の GIF -->

## 余談: 深度が分かると他にもできること

深度が分かると、ボケ以外にもいろいろできます。

- 手前だけ残して背景を削除する
- タップした位置と近い深度の領域をオブジェクトとして選択する
- 左右の視差を作って、Vision Pro で見られる空間写真にする
- 奥ほど霞ませるフォグ、光を当て直すリライティング
- 1 枚の写真から点群やメッシュを起こす
- AR で仮想オブジェクトの前後関係を正しく描く

背景削除は、CIColorMatrix で深度マップを閾値処理してマスクを作り、CIBlendWithMask で合成するだけなので、ボケのときとほとんど同じ仕組みで実装できます。

<!-- TODO: 背景削除デモのスクリーンショット -->

## 参考

- 安藤幸司『カメラとレンズのしくみがわかる光学入門』（インプレス） https://amzn.to/4gWqVue
- Depth Anything V2 (Core ML): https://huggingface.co/apple/coreml-depth-anything-v2-small
- Depth Anything 3: https://huggingface.co/depth-anything/DA3-SMALL
- Depth Pro (Core ML): https://huggingface.co/coreml-projects/DepthPro-coreml
- MiDaS: https://github.com/isl-org/MiDaS
