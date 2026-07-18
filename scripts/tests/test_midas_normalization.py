"""convert_midas_v3_small.py の ImageNet 正規化 (scale/bias) 計算のテスト。

MiDaS small (ONNX) は `(x/255 - mean) / std` の正規化を前提とした入力を
取るが、Core ML の ct.ImageType は scale がチャンネル共通のスカラーしか
取れないため、std の平均で近似している。この近似の妥当性を確認する。
"""

import math

import convert_midas_v3_small as midas

MEAN = [0.485, 0.456, 0.406]
STD = [0.229, 0.224, 0.225]


def test_imagenet_scale_bias_scale_uses_average_std():
  scale, _bias = midas.imagenet_scale_bias(MEAN, STD)
  avg_std = sum(STD) / len(STD)
  assert math.isclose(scale, (1.0 / 255.0) / avg_std)


def test_imagenet_scale_bias_bias_is_exact_per_channel():
  _scale, bias = midas.imagenet_scale_bias(MEAN, STD)
  assert len(bias) == 3
  for b, m, s in zip(bias, MEAN, STD):
    assert math.isclose(b, -m / s)


def test_imagenet_scale_bias_approximates_exact_per_channel_normalization():
  # x_raw * scale + bias ≈ (x_raw/255 - mean) / std。
  # 誤差は3チャンネルの std のばらつき（0.224〜0.229、最大で約2%）に起因する
  # 分のみに収まるはず（許容誤差は緩め: 0.1）。
  scale, bias = midas.imagenet_scale_bias(MEAN, STD)

  for pixel in (0, 64, 128, 200, 255):
    for m, s, b in zip(MEAN, STD, bias):
      approx = pixel * scale + b
      exact = (pixel / 255.0 - m) / s
      assert abs(approx - exact) < 0.1, (pixel, approx, exact)


def test_imagenet_scale_bias_identical_std_gives_exact_result():
  # 全チャンネルの std が同じであれば平均近似の誤差は完全にゼロになるはず。
  uniform_std = [0.226, 0.226, 0.226]
  scale, bias = midas.imagenet_scale_bias(MEAN, uniform_std)

  for pixel in (0, 128, 255):
    for m, s, b in zip(MEAN, uniform_std, bias):
      approx = pixel * scale + b
      exact = (pixel / 255.0 - m) / s
      assert math.isclose(approx, exact, abs_tol=1e-9)
