// ******************************************************************************
// Spine Runtimes Software License v2.5
//
// Copyright (c) 2013-2016, Esoteric Software
// All rights reserved.
//
// You are granted a perpetual, non-exclusive, non-sublicensable, and
// non-transferable license to use, install, execute, and perform the Spine
// Runtimes software and derivative works solely for personal or internal
// use. Without the written permission of Esoteric Software (see Section 2 of
// the Spine Software License Agreement), you may not (a) modify, translate,
// adapt, or develop new applications using the Spine Runtimes or otherwise
// create derivative works or improvements of the Spine Runtimes or (b) remove,
// delete, alter, or obscure any trademarks or any copyright, trademark, patent,
// or other intellectual property or proprietary rights notices on or in the
// Software, including any copy thereof. Redistributions in binary or source
// form must include this license and terms.
//
// THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
// EVENT SHALL ESOTERIC SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, BUSINESS INTERRUPTION, OR LOSS OF
// USE, DATA, OR PROFITS) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
// IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
// ******************************************************************************

part of spine_core;

class Animation {
  final String name;
  final List<Timeline> timelines;
  final double duration;

  const Animation(this.name, this.timelines, this.duration);

  void apply(Skeleton skeleton, double lastTime, double time, bool loop,
      List<Event?> events, double alpha, MixPose pose, MixDirection direction) {

    if (loop && duration != 0) {
      time %= duration;
      if (lastTime > 0) lastTime %= duration;
    }

    final int n = timelines.length;
    for (int i = 0; i < n; i++)
      timelines[i]
          .apply(skeleton, lastTime, time, events, alpha, pose, direction);
  }

  static int binarySearch(List<double> values, [double? target, int step = 1]) {
    int low = 0;
    int high = values.length ~/ step - 2;
    if (high == 0) return step;
    int current = high >> 1;
    for (;;) {
      if (values[(current + 1) * step] <= target!)
        low = current + 1;
      else
        high = current;
      if (low == high) return (low + 1) * step;
      current = (low + high) >> 1;
    }
  }

  static int linearSearch(List<double> values, [double? target, int step = 1]) {
    for (int i = 0; i <= values.length - step; i += step)
      if (values[i] > target!) return i;
    return -1;
  }
}

abstract class Timeline {
  void apply(Skeleton skeleton, double lastTime, double time,
      List<Event?> events, double alpha, MixPose pose, MixDirection direction);
  int getPropertyId();
}

enum MixPose { Setup, Current, CurrentLayered }

enum MixDirection { In, Out }

enum TimelineType {
  Rotate,
  Translate,
  Scale,
  Shear,
  Attachment,
  Color,
  Deform,
  Event,
  DrawOrder,
  IkConstraint,
  TransformConstraint,
  PathConstraintPosition,
  PathConstraintSpacing,
  PathConstraintMix,
  TwoColor
}

abstract class CurveTimeline implements Timeline {
  static const double linear = 0.0, stepped = 1.0, bezier = 2.0;
  static const int bezierSize = 10 * 2 - 1;

  final Float32List curves;

  CurveTimeline(int frameCount)
      : curves = Float32List((frameCount - 1) * CurveTimeline.bezierSize) {
    if (frameCount <= 0)
      throw ArgumentError('frameCount must be > 0: $frameCount');
  }

  int getFrameCount() => curves.length ~/ CurveTimeline.bezierSize + 1;

  void setLinear(int frameIndex) {
    curves[frameIndex * CurveTimeline.bezierSize] = CurveTimeline.linear;
  }

  void setStepped(int frameIndex) {
    curves[frameIndex * CurveTimeline.bezierSize] = CurveTimeline.stepped;
  }

  double getCurveType(int frameIndex) {
    final int index = frameIndex * CurveTimeline.bezierSize;
    if (index == curves.length) return CurveTimeline.linear;
    final double type = curves[index];
    if (type == CurveTimeline.linear) return CurveTimeline.linear;
    if (type == CurveTimeline.stepped) return CurveTimeline.stepped;
    return CurveTimeline.bezier;
  }

  void setCurve(
      int frameIndex, double cx1, double cy1, double cx2, double cy2) {
    final double tmpx = (-cx1 * 2 + cx2) * 0.03, tmpy = (-cy1 * 2 + cy2) * 0.03;
    final double dddfx = ((cx1 - cx2) * 3 + 1) * 0.006,
        dddfy = ((cy1 - cy2) * 3 + 1) * 0.006;
    double ddfx = tmpx * 2 + dddfx, ddfy = tmpy * 2 + dddfy;
    double dfx = cx1 * 0.3 + tmpx + dddfx * 0.16666667,
        dfy = cy1 * 0.3 + tmpy + dddfy * 0.16666667;

    int i = frameIndex * CurveTimeline.bezierSize;
    curves[i++] = CurveTimeline.bezier;

    double x = dfx, y = dfy;
    for (final int n = i + CurveTimeline.bezierSize - 1; i < n; i += 2) {
      curves[i] = x;
      curves[i + 1] = y;
      dfx += ddfx;
      dfy += ddfy;
      ddfx += dddfx;
      ddfy += dddfy;
      x += dfx;
      y += dfy;
    }
  }

  double getCurvePercent(int frameIndex, double percent) {
    percent = MathUtils.clamp(percent, 0.0, 1.0);
    int i = frameIndex * CurveTimeline.bezierSize;
    final double type = curves[i];
    if (type == CurveTimeline.linear) return percent;
    if (type == CurveTimeline.stepped) return 0.0;
    i++;
    double x = 0.0;
    for (final int start = i, n = i + CurveTimeline.bezierSize - 1;
        i < n;
        i += 2) {
      x = curves[i];
      if (x >= percent) {
        double prevX, prevY;
        if (i == start) {
          prevX = 0.0;
          prevY = 0.0;
        } else {
          prevX = curves[i - 2];
          prevY = curves[i - 1];
        }
        return prevY +
            (curves[i + 1] - prevY) * (percent - prevX) / (x - prevX);
      }
    }
    final double y = curves[i - 1];
    return y + (1 - y) * (percent - x) / (1 - x); // Last point is 1,1.
  }
}

class RotateTimeline extends CurveTimeline {
  static const int entries = 2;
  static const int prevTime = -2, prevRotation = -1;
  static const int rotation = 1;

  late int boneIndex;
  final Float32List frames; // time, degrees, ...

  RotateTimeline(int frameCount)
      : frames = Float32List(frameCount << 1),
        super(frameCount);

  @override
  int getPropertyId() => TimelineType.Rotate.index << 24 + boneIndex;

  void setFrame(int frameIndex, double time, double degrees) {
    frameIndex <<= 1;
    frames[frameIndex] = time;
    frames[frameIndex + RotateTimeline.rotation] = degrees;
  }

  @override
  void apply(Skeleton skeleton, double lastTime, double time,
      List<Event?> events, double alpha, MixPose pose, MixDirection direction) {
    final Bone bone = skeleton.bones[boneIndex];
    final Float32List frames = this.frames;
    if (time < frames[0]) {
      if (pose == MixPose.Setup) {
        bone.rotation = bone.data.rotation;
      } else if (pose == MixPose.Current) {
        double r = bone.data.rotation - bone.rotation;
        r -= (16384 - (16384.499999999996 - r / 360).toInt()) * 360;
        bone.rotation = bone.rotation + r * alpha;
      }
      return;
    }

    if (time >= frames[frames.length - RotateTimeline.entries]) {
      // Time is after last frame.
      if (pose == MixPose.Setup) {
        bone.rotation = bone.data.rotation +
            frames[frames.length + RotateTimeline.prevRotation] * alpha;
      } else {
        double r = bone.data.rotation +
            frames[frames.length + RotateTimeline.prevRotation] -
            bone.rotation;
        r -= (16384 - (16384.499999999996 - r / 360).toInt()) * 360;
        bone.rotation = bone.rotation + r * alpha;
      }
      return;
    }

    // Interpolate between the previous frame and the current frame.
    final int frame =
        Animation.binarySearch(frames, time, RotateTimeline.entries);
    final double prevRotation = frames[frame + RotateTimeline.prevRotation];
    final double frameTime = frames[frame];
    final double percent = getCurvePercent(
        (frame >> 1) - 1,
        1 -
            (time - frameTime) /
                (frames[frame + RotateTimeline.prevTime] - frameTime));

    double r = frames[frame + RotateTimeline.rotation] - prevRotation;
    r -= (16384 - (16384.499999999996 - r / 360).toInt()) * 360;
    r = prevRotation + r * percent;
    if (pose == MixPose.Setup) {
      r -= (16384 - (16384.499999999996 - r / 360).toInt()) * 360;
      bone.rotation = bone.data.rotation + r * alpha;
    } else {
      r = bone.data.rotation + r - bone.rotation;
      r -= (16384 - (16384.499999999996 - r / 360).toInt()) * 360;
      bone.rotation = bone.rotation + r * alpha;
    }
  }
}

class TranslateTimeline extends CurveTimeline {
  static const int entries = 3;
  static const int prevTime = -3, prevX = -2, prevY = -1;
  static const int x = 1, y = 2;

  final Float32List frames;
  late int boneIndex;

  TranslateTimeline(int frameCount)
      : frames = Float32List(frameCount * TranslateTimeline.entries),
        super(frameCount);

  @override
  int getPropertyId() => (TimelineType.Translate.index << 24) + boneIndex;

  void setFrame(int frameIndex, double time, double x, double y) {
    frameIndex *= TranslateTimeline.entries;
    frames[frameIndex] = time;
    frames[frameIndex + TranslateTimeline.x] = x;
    frames[frameIndex + TranslateTimeline.y] = y;
  }

  @override
  void apply(Skeleton skeleton, double lastTime, double time,
      List<Event?> events, double alpha, MixPose pose, MixDirection direction) {
    final Bone bone = skeleton.bones[boneIndex];
    final Float32List frames = this.frames;
    if (time < frames[0]) {
      if (pose == MixPose.Setup) {
        bone
          ..x = bone.data.x
          ..y = bone.data.y;
      } else if (pose == MixPose.Current) {
        bone
          ..x += (bone.data.x - bone.x) * alpha
          ..y += (bone.data.y - bone.y) * alpha;
      }
      return;
    }

    double x = 0.0, y = 0.0;
    if (time >= frames[frames.length - TranslateTimeline.entries]) {
      // Time is after last frame.
      x = frames[frames.length + TranslateTimeline.prevX];
      y = frames[frames.length + TranslateTimeline.prevY];
    } else {
      // Interpolate between the previous frame and the current frame.
      final int frame =
          Animation.binarySearch(frames, time, TranslateTimeline.entries);
      x = frames[frame + TranslateTimeline.prevX];
      y = frames[frame + TranslateTimeline.prevY];
      final double frameTime = frames[frame];
      final double percent = getCurvePercent(
          frame ~/ TranslateTimeline.entries - 1,
          1 -
              (time - frameTime) /
                  (frames[frame + TranslateTimeline.prevTime] - frameTime));

      x += (frames[frame + TranslateTimeline.x] - x) * percent;
      y += (frames[frame + TranslateTimeline.y] - y) * percent;
    }
    if (pose == MixPose.Setup) {
      bone
        ..x = bone.data.x + x * alpha
        ..y = bone.data.y + y * alpha;
    } else {
      bone
        ..x += (bone.data.x + x - bone.x) * alpha
        ..y += (bone.data.y + y - bone.y) * alpha;
    }
  }
}

class ScaleTimeline extends TranslateTimeline {
  ScaleTimeline(int frameCount) : super(frameCount);

  @override
  int getPropertyId() => (TimelineType.Scale.index << 24) + boneIndex;

  @override
  void apply(Skeleton skeleton, double lastTime, double time,
      List<Event?> events, double alpha, MixPose pose, MixDirection direction) {
    final Bone bone = skeleton.bones[boneIndex];
    final Float32List frames = this.frames;
    if (time < frames[0]) {
      if (pose == MixPose.Setup) {
        bone
          ..scaleX = bone.data.scaleX
          ..scaleY = bone.data.scaleY;
      } else if (pose == MixPose.Current) {
        bone
          ..scaleX += (bone.data.scaleX - bone.scaleX) * alpha
          ..scaleY += (bone.data.scaleY - bone.scaleY) * alpha;
      }
      return;
    }

    double x = 0.0, y = 0.0;
    if (time >= frames[frames.length - TranslateTimeline.entries]) {
      // Time is after last frame.
      x = frames[frames.length + TranslateTimeline.prevX] * bone.data.scaleX;
      y = frames[frames.length + TranslateTimeline.prevY] * bone.data.scaleY;
    } else {
      // Interpolate between the previous frame and the current frame.
      final int frame =
          Animation.binarySearch(frames, time, TranslateTimeline.entries);
      x = frames[frame + TranslateTimeline.prevX];
      y = frames[frame + TranslateTimeline.prevY];
      final double frameTime = frames[frame];
      final double percent = getCurvePercent(
          frame ~/ TranslateTimeline.entries - 1,
          1 -
              (time - frameTime) /
                  (frames[frame + TranslateTimeline.prevTime] - frameTime));

      x = (x + (frames[frame + TranslateTimeline.x] - x) * percent) *
          bone.data.scaleX;
      y = (y + (frames[frame + TranslateTimeline.y] - y) * percent) *
          bone.data.scaleY;
    }
    if (alpha == 1) {
      bone
        ..scaleX = x
        ..scaleY = y;
    } else {
      double? bx = 0.0, by = 0.0;
      if (pose == MixPose.Setup) {
        bx = bone.data.scaleX;
        by = bone.data.scaleY;
      } else {
        bx = bone.scaleX;
        by = bone.scaleY;
      }
      // Mixing out uses sign of setup or current pose, else use sign of key.
      if (direction == MixDirection.Out) {
        x = x.abs() * MathUtils.signum(bx);
        y = y.abs() * MathUtils.signum(by);
      } else {
        bx = bx.abs() * MathUtils.signum(x);
        by = by.abs() * MathUtils.signum(y);
      }
      bone
        ..scaleX = bx + (x - bx) * alpha
        ..scaleY = by + (y - by) * alpha;
    }
  }
}

class ShearTimeline extends TranslateTimeline {
  ShearTimeline(int frameCount) : super(frameCount);

  @override
  int getPropertyId() => (TimelineType.Shear.index << 24) + boneIndex;

  @override
  void apply(Skeleton skeleton, double lastTime, double time,
      List<Event?> events, double alpha, MixPose pose, MixDirection direction) {
    final Bone bone = skeleton.bones[boneIndex];
    final Float32List frames = this.frames;
    if (time < frames[0]) {
      if (pose == MixPose.Setup) {
        bone
          ..shearX = bone.data.shearX
          ..shearY = bone.data.shearY;
      } else if (pose == MixPose.Current) {
        bone
          ..shearX += (bone.data.shearX - bone.shearX) * alpha
          ..shearY += (bone.data.shearY - bone.shearY) * alpha;
      }
      return;
    }

    double x = 0.0, y = 0.0;
    if (time >= frames[frames.length - TranslateTimeline.entries]) {
      // Time is after last frame.
      x = frames[frames.length + TranslateTimeline.prevX];
      y = frames[frames.length + TranslateTimeline.prevY];
    } else {
      // Interpolate between the previous frame and the current frame.
      final int frame =
          Animation.binarySearch(frames, time, TranslateTimeline.entries);
      x = frames[frame + TranslateTimeline.prevX];
      y = frames[frame + TranslateTimeline.prevY];
      final double frameTime = frames[frame];
      final double percent = getCurvePercent(
          frame ~/ TranslateTimeline.entries - 1,
          1 -
              (time - frameTime) /
                  (frames[frame + TranslateTimeline.prevTime] - frameTime));

      x = x + (frames[frame + TranslateTimeline.x] - x) * percent;
      y = y + (frames[frame + TranslateTimeline.y] - y) * percent;
    }
    if (pose == MixPose.Setup) {
      bone
        ..shearX = bone.data.shearX + x * alpha
        ..shearY = bone.data.shearY + y * alpha;
    } else {
      bone
        ..shearX += (bone.data.shearX + x - bone.shearX) * alpha
        ..shearY += (bone.data.shearY + y - bone.shearY) * alpha;
    }
  }
}

class ColorTimeline extends CurveTimeline {
  static const int entries = 5;
  static const int prevTime = -5,
      prevR = -4,
      prevG = -3,
      prevB = -2,
      prevA = -1;
  static const int r = 1, g = 2, b = 3, a = 4;

  final Float32List frames;
  late int slotIndex;

  ColorTimeline(int frameCount)
      : frames = Float32List(frameCount * ColorTimeline.entries),
        super(frameCount);

  @override
  int getPropertyId() => (TimelineType.Color.index << 24) + slotIndex;

  void setFrame(
      int frameIndex, double time, double r, double g, double b, double a) {
    frameIndex *= ColorTimeline.entries;
    frames[frameIndex] = time;
    frames[frameIndex + ColorTimeline.r] = r;
    frames[frameIndex + ColorTimeline.g] = g;
    frames[frameIndex + ColorTimeline.b] = b;
    frames[frameIndex + ColorTimeline.a] = a;
  }

  @override
  void apply(Skeleton skeleton, double lastTime, double time,
      List<Event?> events, double alpha, MixPose pose, MixDirection direction) {
    final Slot slot = skeleton.slots[slotIndex];
    final Float32List frames = this.frames;
    if (time < frames[0]) {
      if (pose == MixPose.Setup) {
        slot.color.setFromColor(slot.data.color);
      } else if (pose == MixPose.Current) {
        final Color? color = slot.color, setup = slot.data.color;
        color!.add((setup!.r - color.r) * alpha, (setup.g - color.g) * alpha,
            (setup.b - color.b) * alpha, (setup.a - color.a) * alpha);
      }
      return;
    }

    double r = 0.0, g = 0.0, b = 0.0, a = 0.0;
    if (time >= frames[frames.length - ColorTimeline.entries]) {
      // Time is after last frame.
      final int i = frames.length;
      r = frames[i + ColorTimeline.prevR];
      g = frames[i + ColorTimeline.prevG];
      b = frames[i + ColorTimeline.prevB];
      a = frames[i + ColorTimeline.prevA];
    } else {
      // Interpolate between the previous frame and the current frame.
      final int frame =
          Animation.binarySearch(frames, time, ColorTimeline.entries);
      r = frames[frame + ColorTimeline.prevR];
      g = frames[frame + ColorTimeline.prevG];
      b = frames[frame + ColorTimeline.prevB];
      a = frames[frame + ColorTimeline.prevA];
      final double frameTime = frames[frame];
      final double percent = getCurvePercent(
          frame ~/ ColorTimeline.entries - 1,
          1 -
              (time - frameTime) /
                  (frames[frame + ColorTimeline.prevTime] - frameTime));

      r += (frames[frame + ColorTimeline.r] - r) * percent;
      g += (frames[frame + ColorTimeline.g] - g) * percent;
      b += (frames[frame + ColorTimeline.b] - b) * percent;
      a += (frames[frame + ColorTimeline.a] - a) * percent;
    }
    if (alpha == 1)
      slot.color.set(r, g, b, a);
    else {
      final Color color = slot.color;
      if (pose == MixPose.Setup) color.setFromColor(slot.data.color);
      color.add((r - color.r) * alpha, (g - color.g) * alpha,
          (b - color.b) * alpha, (a - color.a) * alpha);
    }
  }
}

class TwoColorTimeline extends CurveTimeline {
  static const int entries = 8;
  static const int prevTime = -8,
      prevR = -7,
      prevG = -6,
      prevB = -5,
      prevA = -4;
  static const int prevR2 = -3, prevG2 = -2, prevB2 = -1;
  static const int r = 1, g = 2, b = 3, a = 4, r2 = 5, g2 = 6, b2 = 7;

  late int slotIndex;
  final Float32List frames;

  TwoColorTimeline(int frameCount)
      : frames = Float32List(frameCount * TwoColorTimeline.entries),
        super(frameCount);

  @override
  int getPropertyId() => (TimelineType.TwoColor.index << 24) + slotIndex;

  void setFrame(int frameIndex, double time, double r, double g, double b,
      double a, double r2, double g2, double b2) {
    frameIndex *= TwoColorTimeline.entries;
    frames[frameIndex] = time;
    frames[frameIndex + TwoColorTimeline.r] = r;
    frames[frameIndex + TwoColorTimeline.g] = g;
    frames[frameIndex + TwoColorTimeline.b] = b;
    frames[frameIndex + TwoColorTimeline.a] = a;
    frames[frameIndex + TwoColorTimeline.r2] = r2;
    frames[frameIndex + TwoColorTimeline.g2] = g2;
    frames[frameIndex + TwoColorTimeline.b2] = b2;
  }

  @override
  void apply(Skeleton skeleton, double lastTime, double time,
      List<Event?> events, double alpha, MixPose pose, MixDirection direction) {
    final Slot slot = skeleton.slots[slotIndex];
    final Float32List frames = this.frames;
    if (time < frames[0]) {
      if (pose == MixPose.Setup) {
        slot.color.setFromColor(slot.data.color);
        slot.darkColor!.setFromColor(slot.data.darkColor!);
      } else if (pose == MixPose.Current) {
        final Color? light = slot.color,
            dark = slot.darkColor,
            setupLight = slot.data.color,
            setupDark = slot.data.darkColor;
        light!.add(
            (setupLight!.r - light.r) * alpha,
            (setupLight.g - light.g) * alpha,
            (setupLight.b - light.b) * alpha,
            (setupLight.a - light.a) * alpha);
        dark!.add((setupDark!.r - dark.r) * alpha, (setupDark.g - dark.g) * alpha,
            (setupDark.b - dark.b) * alpha, 0.0);
      }
      return;
    }

    double r = 0.0, g = 0.0, b = 0.0, a = 0.0, r2 = 0.0, g2 = 0.0, b2 = 0.0;
    if (time >= frames[frames.length - TwoColorTimeline.entries]) {
      // Time is after last frame.
      final int i = frames.length;
      r = frames[i + TwoColorTimeline.prevR];
      g = frames[i + TwoColorTimeline.prevG];
      b = frames[i + TwoColorTimeline.prevB];
      a = frames[i + TwoColorTimeline.prevA];
      r2 = frames[i + TwoColorTimeline.prevR2];
      g2 = frames[i + TwoColorTimeline.prevG2];
      b2 = frames[i + TwoColorTimeline.prevB2];
    } else {
      // Interpolate between the previous frame and the current frame.
      final int frame =
          Animation.binarySearch(frames, time, TwoColorTimeline.entries);
      r = frames[frame + TwoColorTimeline.prevR];
      g = frames[frame + TwoColorTimeline.prevG];
      b = frames[frame + TwoColorTimeline.prevB];
      a = frames[frame + TwoColorTimeline.prevA];
      r2 = frames[frame + TwoColorTimeline.prevR2];
      g2 = frames[frame + TwoColorTimeline.prevG2];
      b2 = frames[frame + TwoColorTimeline.prevB2];
      final double frameTime = frames[frame];
      final double percent = getCurvePercent(
          frame ~/ TwoColorTimeline.entries - 1,
          1 -
              (time - frameTime) /
                  (frames[frame + TwoColorTimeline.prevTime] - frameTime));

      r += (frames[frame + TwoColorTimeline.r] - r) * percent;
      g += (frames[frame + TwoColorTimeline.g] - g) * percent;
      b += (frames[frame + TwoColorTimeline.b] - b) * percent;
      a += (frames[frame + TwoColorTimeline.a] - a) * percent;
      r2 += (frames[frame + TwoColorTimeline.r2] - r2) * percent;
      g2 += (frames[frame + TwoColorTimeline.g2] - g2) * percent;
      b2 += (frames[frame + TwoColorTimeline.b2] - b2) * percent;
    }
    if (alpha == 1) {
      slot.color.set(r, g, b, a);
      slot.darkColor!.set(r2, g2, b2, 1.0);
    } else {
      final Color? light = slot.color, dark = slot.darkColor;
      if (pose == MixPose.Setup) {
        light!.setFromColor(slot.data.color);
        dark!.setFromColor(slot.data.darkColor!);
      }
      light!.add((r - light.r) * alpha, (g - light.g) * alpha,
          (b - light.b) * alpha, (a - light.a) * alpha);
      dark!.add((r2 - dark.r) * alpha, (g2 - dark.g) * alpha,
          (b2 - dark.b) * alpha, 0.0);
    }
  }
}

class AttachmentTimeline implements Timeline {
  final Float32List frames;
  final List<String?> attachmentNames;
  int? slotIndex;

  AttachmentTimeline(int frameCount)
      : frames = Float32List(frameCount),
        attachmentNames = List<String?>.filled(frameCount, null, growable: false);

  @override
  int getPropertyId() => (TimelineType.Attachment.index << 24) + slotIndex!;

  int getFrameCount() => frames.length;

  void setFrame(int frameIndex, double time, String? attachmentName) {
    frames[frameIndex] = time;
    attachmentNames[frameIndex] = attachmentName;
  }

  @override
  void apply(Skeleton skeleton, double lastTime, double time,
      List<Event?> events, double alpha, MixPose pose, MixDirection direction) {
    final Slot slot = skeleton.slots[slotIndex!];
    if (direction == MixDirection.Out && pose == MixPose.Setup) {
      final String? attachmentName = slot.data.attachmentName;
      slot.setAttachment(attachmentName == null
          ? null
          : skeleton.getAttachment(slotIndex, attachmentName));
      return;
    }

    final Float32List frames = this.frames;
    if (time < frames[0]) {
      if (pose == MixPose.Setup) {
        final String? attachmentName = slot.data.attachmentName;
        slot.setAttachment(attachmentName == null
            ? null
            : skeleton.getAttachment(slotIndex, attachmentName));
      }
      return;
    }

    int frameIndex = 0;
    if (time >= frames[frames.length - 1]) // Time is after last frame.
      frameIndex = frames.length - 1;
    else
      frameIndex = Animation.binarySearch(frames, time, 1) - 1;

    final String? attachmentName = attachmentNames[frameIndex];
    skeleton.slots[slotIndex!].setAttachment(attachmentName == null
        ? null
        : skeleton.getAttachment(slotIndex, attachmentName));
  }
}

class DeformTimeline extends CurveTimeline {
  final Float32List frames;
  final List<Float32List?> frameVertices;
  late int slotIndex;
  VertexAttachment? attachment;

  DeformTimeline(int frameCount)
      : frames = Float32List(frameCount),
        frameVertices = List<Float32List?>.filled(frameCount, null, growable: false),
        super(frameCount);

  @override
  int getPropertyId() =>
      (TimelineType.Deform.index << 27) + attachment!.id + slotIndex;

  void setFrame(int frameIndex, double time, Float32List? vertices) {
    frames[frameIndex] = time;
    frameVertices[frameIndex] = vertices;
  }

  @override
  void apply(Skeleton skeleton, double lastTime, double time,
      List<Event?> events, double alpha, MixPose pose, MixDirection direction) {
    final Slot slot = skeleton.slots[slotIndex];
    final Attachment? slotAttachment = slot.getAttachment();

    if (slotAttachment is! VertexAttachment) return;

    final VertexAttachment vertexAttachment = slotAttachment;
    if (vertexAttachment.applyDeform(attachment) == false) return;

    final List<double> verticesArray =
        List<double>.from(slot.attachmentVertices);
    if (verticesArray.isEmpty) alpha = 1.0;

    final List<Float32List?> frameVertices = this.frameVertices;
    final int vertexCount = frameVertices[0]!.length;

    final Float32List frames = this.frames;
    if (time < frames[0]) {
      if (pose == MixPose.Setup) {
        verticesArray.length = 0;
      } else if (pose == MixPose.Current) {
        if (alpha == 1) {
          verticesArray.length = 0;
          return;
        }
        final Float32List vertices = Float32List.fromList(
            ArrayUtils.copyWithNewArraySize(verticesArray, vertexCount, double.infinity));
        if (vertexAttachment.bones == null) {
          // Unweighted vertex positions.
          final Float32List setupVertices = vertexAttachment.vertices!;
          for (int i = 0; i < vertexCount; i++)
            vertices[i] += (setupVertices[i] - vertices[i]) * alpha;
        } else {
          // Weighted deform offsets.
          alpha = 1 - alpha;
          for (int i = 0; i < vertexCount; i++) vertices[i] *= alpha;
        }
      }
      return;
    }

    Float32List vertices = Float32List.fromList(
        ArrayUtils.copyWithNewArraySize(verticesArray, vertexCount, double.infinity));
    if (time >= frames[frames.length - 1]) {
      // Time is after last frame.
      final Float32List lastVertices = frameVertices[frames.length - 1]!;
      if (alpha == 1) {
        vertices = ArrayUtils.arrayCopyWithGrowth(
            lastVertices, 0, vertices, 0, vertexCount, double.infinity) as Float32List;
      } else if (pose == MixPose.Setup) {
        if (vertexAttachment.bones == null) {
          // Unweighted vertex positions, with alpha.
          final Float32List setupVertices = vertexAttachment.vertices!;
          for (int i = 0; i < vertexCount; i++) {
            final double setup = setupVertices[i];
            vertices[i] = setup + (lastVertices[i] - setup) * alpha;
          }
        } else {
          // Weighted deform offsets, with alpha.
          for (int i = 0; i < vertexCount; i++)
            vertices[i] = lastVertices[i] * alpha;
        }
      } else {
        for (int i = 0; i < vertexCount; i++)
          vertices[i] += (lastVertices[i] - vertices[i]) * alpha;
      }
      return;
    }

    // Interpolate between the previous frame and the current frame.
    final int frame = Animation.binarySearch(frames, time);
    final Float32List? prevVertices = frameVertices[frame - 1];
    final Float32List? nextVertices = frameVertices[frame];
    final double frameTime = frames[frame];
    final double percent = getCurvePercent(
        frame - 1, 1 - (time - frameTime) / (frames[frame - 1] - frameTime));

    if (alpha == 1) {
      for (int i = 0; i < vertexCount; i++) {
        final double prev = prevVertices![i];
        vertices[i] = prev + (nextVertices![i] - prev) * percent;
      }
    } else if (pose == MixPose.Setup) {
      if (vertexAttachment.bones == null) {
        // Unweighted vertex positions, with alpha.
        final Float32List? setupVertices = vertexAttachment.vertices;
        for (int i = 0; i < vertexCount; i++) {
          final double prev = prevVertices![i], setup = setupVertices![i];
          vertices[i] = setup +
              (prev + (nextVertices![i] - prev) * percent - setup) * alpha;
        }
      } else {
        // Weighted deform offsets, with alpha.
        for (int i = 0; i < vertexCount; i++) {
          final double prev = prevVertices![i];
          vertices[i] = (prev + (nextVertices![i] - prev) * percent) * alpha;
        }
      }
    } else {
      // Vertex positions or deform offsets, with alpha.
      for (int i = 0; i < vertexCount; i++) {
        final double prev = prevVertices![i];
        vertices[i] +=
            (prev + (nextVertices![i] - prev) * percent - vertices[i]) * alpha;
      }
    }
  }
}

class EventTimeline extends Timeline {
  final Float32List frames;
  final List<Event?> events;

  EventTimeline(int frameCount)
      : frames = Float32List(frameCount),
        events = List<Event?>.filled(frameCount, null, growable: false);

  @override
  int getPropertyId() => TimelineType.Event.index << 24;

  int getFrameCount() => frames.length;

  void setFrame(int frameIndex, Event event) {
    frames[frameIndex] = event.time!;
    events[frameIndex] = event;
  }

  @override
  void apply(
      Skeleton skeleton,
      double lastTime,
      double time,
      List<Event?> firedEvents,
      double alpha,
      MixPose pose,
      MixDirection direction) {
    if (firedEvents.isEmpty) return;
    final Float32List frames = this.frames;
    final int frameCount = this.frames.length;

    if (lastTime > time) {
      // Fire events after last time for looped animations.
      apply(skeleton, lastTime, double.maxFinite, firedEvents, alpha, pose,
          direction);
      lastTime = -1.0;
    } else if (lastTime >= frames[frameCount - 1])
      // Last time is after last frame.
      return;
    if (time < frames[0]) return; // Time is before first frame.
    int frame = 0;
    if (lastTime < frames[0])
      frame = 0;
    else {
      frame = Animation.binarySearch(frames, lastTime);
      final double frameTime = frames[frame];
      while (frame > 0) {
        // Fire multiple events with the same frame.
        if (frames[frame - 1] != frameTime) break;
        frame--;
      }
    }
    for (; frame < frameCount && time >= frames[frame]; frame++)
      firedEvents.add(events[frame]);
  }
}

class DrawOrderTimeline implements Timeline {
  final Float32List frames;
  final List<Int32List?> drawOrders;

  DrawOrderTimeline(int frameCount)
      : frames = Float32List(frameCount),
        drawOrders = List<Int32List?>.filled(frameCount, null, growable: false);

  @override
  int getPropertyId() => TimelineType.DrawOrder.index << 24;

  int getFrameCount() => frames.length;

  void setFrame(int frameIndex, double time, Int32List? drawOrder) {
    frames[frameIndex] = time;
    drawOrders[frameIndex] = drawOrder;
  }

  @override
  void apply(
      Skeleton skeleton,
      double lastTime,
      double time,
      List<Event?> firedEvents,
      double alpha,
      MixPose pose,
      MixDirection direction) {
    List<Slot> drawOrder = skeleton.drawOrder;
    final List<Slot> slots = skeleton.slots;
    if (direction == MixDirection.Out && pose == MixPose.Setup) {
      skeleton.drawOrder = ArrayUtils.arrayCopyWithGrowth(skeleton.slots, 0,
          skeleton.drawOrder, 0, skeleton.slots.length, Slot.empty());
      return;
    }

    final Float32List frames = this.frames;
    if (time < frames[0]) {
      if (pose == MixPose.Setup)
        skeleton.drawOrder = ArrayUtils.arrayCopyWithGrowth(skeleton.slots, 0,
            skeleton.drawOrder, 0, skeleton.slots.length, Slot.empty());
      return;
    }

    int frame = 0;
    if (time >= frames[frames.length - 1]) // Time is after last frame.
      frame = frames.length - 1;
    else
      frame = Animation.binarySearch(frames, time) - 1;

    final Int32List? drawOrderToSetupIndex = drawOrders[frame];
    if (drawOrderToSetupIndex == null)
      drawOrder = ArrayUtils.arrayCopyWithGrowth(
          slots, 0, drawOrder, 0, slots.length, Slot.empty());
    else {
      final int n = drawOrderToSetupIndex.length;
      for (int i = 0; i < n; i++)
        drawOrder[i] = slots[drawOrderToSetupIndex[i]];
    }
  }
}

class IkConstraintTimeline extends CurveTimeline {
  static const int entries = 3;
  static const int prevTime = -3, prevMix = -2, prevBendDirection = -1;
  static const int mix = 1, bendDirection = 2;

  final Float32List frames;
  late int ikConstraintIndex;

  IkConstraintTimeline(int frameCount)
      : frames = Float32List(frameCount * IkConstraintTimeline.entries),
        super(frameCount);

  @override
  int getPropertyId() =>
      (TimelineType.IkConstraint.index << 24) + ikConstraintIndex;

  void setFrame(int frameIndex, double time, double mix, int bendDirection) {
    frameIndex *= IkConstraintTimeline.entries;
    frames[frameIndex] = time;
    frames[frameIndex + IkConstraintTimeline.mix] = mix;
    frames[frameIndex + IkConstraintTimeline.bendDirection] =
        bendDirection.toDouble();
  }

  @override
  void apply(
      Skeleton skeleton,
      double lastTime,
      double time,
      List<Event?> firedEvents,
      double alpha,
      MixPose pose,
      MixDirection direction) {
    final Float32List frames = this.frames;
    final IkConstraint constraint = skeleton.ikConstraints[ikConstraintIndex];
    if (time < frames[0]) {
      if (pose == MixPose.Setup) {
        constraint
          ..mix = constraint.data.mix
          ..bendDirection = constraint.data.bendDirection;
      } else if (pose == MixPose.Current) {
        constraint
          ..mix += (constraint.data.mix - constraint.mix) * alpha
          ..bendDirection = constraint.data.bendDirection;
      }
      return;
    }

    if (time >= frames[frames.length - IkConstraintTimeline.entries]) {
      // Time is after last frame.
      if (pose == MixPose.Setup) {
        constraint
          ..mix = constraint.data.mix +
              (frames[frames.length + IkConstraintTimeline.prevMix] -
                      constraint.data.mix) *
                  alpha
          ..bendDirection = direction == MixDirection.Out
              ? constraint.data.bendDirection
              : frames[frames.length + IkConstraintTimeline.prevBendDirection] as int;
      } else {
        constraint.mix = constraint.mix +
            (frames[frames.length + IkConstraintTimeline.prevMix] -
                    constraint.mix) *
                alpha;
        if (direction == MixDirection.In)
          constraint.bendDirection =
              frames[frames.length + IkConstraintTimeline.prevBendDirection]
                  .toInt();
      }
      return;
    }

    // Interpolate between the previous frame and the current frame.
    final int frame =
        Animation.binarySearch(frames, time, IkConstraintTimeline.entries);
    final double mix = frames[frame + IkConstraintTimeline.prevMix];
    final double frameTime = frames[frame];
    final double percent = getCurvePercent(
        frame ~/ IkConstraintTimeline.entries - 1,
        1 -
            (time - frameTime) /
                (frames[frame + IkConstraintTimeline.prevTime] - frameTime));

    if (pose == MixPose.Setup) {
      constraint
        ..mix = constraint.data.mix +
            (mix +
                    (frames[frame + IkConstraintTimeline.mix] - mix) * percent -
                    constraint.data.mix) *
                alpha
        ..bendDirection = direction == MixDirection.Out
            ? constraint.data.bendDirection
            : frames[frame + IkConstraintTimeline.prevBendDirection] as int;
    } else {
      constraint.mix = constraint.mix + (mix +
              (frames[frame + IkConstraintTimeline.mix] - mix) * percent -
              constraint.mix) *
          alpha;
      if (direction == MixDirection.In)
        constraint.bendDirection =
            frames[frame + IkConstraintTimeline.prevBendDirection].toInt();
    }
  }
}

class TransformConstraintTimeline extends CurveTimeline {
  static const int entries = 5;
  static const int prevTime = -5,
      prevRotate = -4,
      prevTranslate = -3,
      prevScale = -2,
      prevShear = -1;
  static const int rotate = 1, translate = 2, scale = 3, shear = 4;

  final Float32List frames;
  late int transformConstraintIndex;

  TransformConstraintTimeline(int frameCount)
      : frames = Float32List(frameCount * TransformConstraintTimeline.entries),
        super(frameCount);

  @override
  int getPropertyId() =>
      (TimelineType.TransformConstraint.index << 24) + transformConstraintIndex;

  void setFrame(int frameIndex, double time, double rotateMix,
      double translateMix, double scaleMix, double shearMix) {
    frameIndex *= TransformConstraintTimeline.entries;
    frames[frameIndex] = time;
    frames[frameIndex + TransformConstraintTimeline.rotate] = rotateMix;
    frames[frameIndex + TransformConstraintTimeline.translate] = translateMix;
    frames[frameIndex + TransformConstraintTimeline.scale] = scaleMix;
    frames[frameIndex + TransformConstraintTimeline.shear] = shearMix;
  }

  @override
  void apply(
      Skeleton skeleton,
      double lastTime,
      double time,
      List<Event?> firedEvents,
      double alpha,
      MixPose pose,
      MixDirection direction) {
    final Float32List frames = this.frames;

    final TransformConstraint constraint =
        skeleton.transformConstraints[transformConstraintIndex];

    if (time < frames[0]) {
      final TransformConstraintData data = constraint.data;
      if (pose == MixPose.Setup) {
        constraint
          ..rotateMix = data.rotateMix
          ..translateMix = data.translateMix
          ..scaleMix = data.scaleMix
          ..shearMix = data.shearMix;
      } else if (pose == MixPose.Current) {
        constraint
          ..rotateMix += (data.rotateMix - constraint.rotateMix) * alpha
          ..translateMix +=
              (data.translateMix - constraint.translateMix) * alpha
          ..scaleMix += (data.scaleMix - constraint.scaleMix) * alpha
          ..shearMix += (data.shearMix - constraint.shearMix) * alpha;
      }
      return;
    }

    double rotate = 0.0, translate = 0.0, scale = 0.0, shear = 0.0;
    if (time >= frames[frames.length - TransformConstraintTimeline.entries]) {
      // Time is after last frame.
      final int i = frames.length;
      rotate = frames[i + TransformConstraintTimeline.prevRotate];
      translate = frames[i + TransformConstraintTimeline.prevTranslate];
      scale = frames[i + TransformConstraintTimeline.prevScale];
      shear = frames[i + TransformConstraintTimeline.prevShear];
    } else {
      // Interpolate between the previous frame and the current frame.
      final int frame = Animation.binarySearch(
          frames, time, TransformConstraintTimeline.entries);
      rotate = frames[frame + TransformConstraintTimeline.prevRotate];
      translate = frames[frame + TransformConstraintTimeline.prevTranslate];
      scale = frames[frame + TransformConstraintTimeline.prevScale];
      shear = frames[frame + TransformConstraintTimeline.prevShear];
      final double frameTime = frames[frame];
      final double percent = getCurvePercent(
          frame ~/ TransformConstraintTimeline.entries - 1,
          1 -
              (time - frameTime) /
                  (frames[frame + TransformConstraintTimeline.prevTime] -
                      frameTime));

      rotate += (frames[frame + TransformConstraintTimeline.rotate] - rotate) *
          percent;
      translate +=
          (frames[frame + TransformConstraintTimeline.translate] - translate) *
              percent;
      scale +=
          (frames[frame + TransformConstraintTimeline.scale] - scale) * percent;
      shear +=
          (frames[frame + TransformConstraintTimeline.shear] - shear) * percent;
    }
    if (pose == MixPose.Setup) {
      final TransformConstraintData data = constraint.data;
      constraint
        ..rotateMix = data.rotateMix + (rotate - data.rotateMix) * alpha
        ..translateMix =
            data.translateMix + (translate - data.translateMix) * alpha
        ..scaleMix = data.scaleMix + (scale - data.scaleMix) * alpha
        ..shearMix = data.shearMix + (shear - data.shearMix) * alpha;
    } else {
      constraint
        ..rotateMix += (rotate - constraint.rotateMix) * alpha
        ..translateMix += (translate - constraint.translateMix) * alpha
        ..scaleMix += (scale - constraint.scaleMix) * alpha
        ..shearMix += (shear - constraint.shearMix) * alpha;
    }
  }
}

class PathConstraintPositionTimeline extends CurveTimeline {
  static const int entries = 2;
  static const int prevTime = -2, prevValue = -1;
  static const int value = 1;

  final Float32List frames;
  late int pathConstraintIndex;

  PathConstraintPositionTimeline(int frameCount)
      : frames =
            Float32List(frameCount * PathConstraintPositionTimeline.entries),
        super(frameCount);

  @override
  int getPropertyId() =>
      (TimelineType.PathConstraintPosition.index << 24) + pathConstraintIndex;

  void setFrame(int frameIndex, double time, double value) {
    frameIndex *= PathConstraintPositionTimeline.entries;
    frames[frameIndex] = time;
    frames[frameIndex + PathConstraintPositionTimeline.value] = value;
  }

  @override
  void apply(
      Skeleton skeleton,
      double lastTime,
      double time,
      List<Event?> firedEvents,
      double alpha,
      MixPose pose,
      MixDirection direction) {
    final Float32List frames = this.frames;
    final PathConstraint constraint =
        skeleton.pathConstraints[pathConstraintIndex];
    if (time < frames[0]) {
      if (pose == MixPose.Setup) {
        constraint.position = constraint.data.position;
      } else if (pose == MixPose.Current) {
        constraint.position = constraint.position +
            (constraint.data.position - constraint.position) * alpha;
      }
      return;
    }

    double position = 0.0;
    if (time >= frames[frames.length - PathConstraintPositionTimeline.entries])
      position =
          frames[frames.length + PathConstraintPositionTimeline.prevValue];
    else {
      // Interpolate between the previous frame and the current frame.
      final int frame = Animation.binarySearch(
          frames, time, PathConstraintPositionTimeline.entries);
      position = frames[frame + prevValue];
      final double frameTime = frames[frame];
      final double percent = getCurvePercent(
          frame ~/ PathConstraintPositionTimeline.entries - 1,
          1 -
              (time - frameTime) /
                  (frames[frame + PathConstraintPositionTimeline.prevTime] -
                      frameTime));

      position +=
          (frames[frame + PathConstraintPositionTimeline.value] - position) *
              percent;
    }
    if (pose == MixPose.Setup)
      constraint.position = constraint.data.position +
          (position - constraint.data.position) * alpha;
    else
      constraint.position = constraint.position + (position - constraint.position) * alpha;
  }
}

class PathConstraintSpacingTimeline extends PathConstraintPositionTimeline {
  PathConstraintSpacingTimeline(int frameCount) : super(frameCount);

  @override
  int getPropertyId() =>
      (TimelineType.PathConstraintSpacing.index << 24) + pathConstraintIndex;

  @override
  void apply(
      Skeleton skeleton,
      double lastTime,
      double time,
      List<Event?> firedEvents,
      double alpha,
      MixPose pose,
      MixDirection direction) {
    final Float32List frames = this.frames;
    final PathConstraint constraint =
        skeleton.pathConstraints[pathConstraintIndex];
    if (time < frames[0]) {
      if (pose == MixPose.Setup) {
        constraint.spacing = constraint.data.spacing;
      } else if (pose == MixPose.Current) {
        constraint.spacing = constraint.spacing +
            (constraint.data.spacing - constraint.spacing) * alpha;
      }
      return;
    }

    double spacing = 0.0;
    if (time >= frames[frames.length - PathConstraintPositionTimeline.entries])
      spacing =
          frames[frames.length + PathConstraintPositionTimeline.prevValue];
    else {
      // Interpolate between the previous frame and the current frame.
      final int frame = Animation.binarySearch(
          frames, time, PathConstraintPositionTimeline.entries);
      spacing = frames[frame + PathConstraintPositionTimeline.prevValue];
      final double frameTime = frames[frame];
      final double percent = getCurvePercent(
          frame ~/ PathConstraintPositionTimeline.entries - 1,
          1 -
              (time - frameTime) /
                  (frames[frame + PathConstraintPositionTimeline.prevTime] -
                      frameTime));

      spacing +=
          (frames[frame + PathConstraintPositionTimeline.value] - spacing) *
              percent;
    }

    if (pose == MixPose.Setup)
      constraint.spacing =
          constraint.data.spacing + (spacing - constraint.data.spacing) * alpha;
    else
      constraint.spacing = constraint.spacing + (spacing - constraint.spacing) * alpha;
  }
}

class PathConstraintMixTimeline extends CurveTimeline {
  static const int entries = 3;
  static const int prevTime = -3, prevRotate = -2, prevTranslate = -1;
  static const int rotate = 1, translate = 2;

  final Float32List frames;
  late int pathConstraintIndex;

  PathConstraintMixTimeline(int frameCount)
      : frames = Float32List(frameCount * PathConstraintMixTimeline.entries),
        super(frameCount);

  @override
  int getPropertyId() =>
      (TimelineType.PathConstraintMix.index << 24) + pathConstraintIndex;

  void setFrame(
      int frameIndex, double time, double rotateMix, double translateMix) {
    frameIndex *= PathConstraintMixTimeline.entries;
    frames[frameIndex] = time;
    frames[frameIndex + PathConstraintMixTimeline.rotate] = rotateMix;
    frames[frameIndex + PathConstraintMixTimeline.translate] = translateMix;
  }

  @override
  void apply(
      Skeleton skeleton,
      double lastTime,
      double time,
      List<Event?> firedEvents,
      double alpha,
      MixPose pose,
      MixDirection direction) {
    final Float32List frames = this.frames;
    final PathConstraint constraint =
        skeleton.pathConstraints[pathConstraintIndex];

    if (time < frames[0]) {
      if (pose == MixPose.Setup) {
        constraint
          ..rotateMix = constraint.data.rotateMix
          ..translateMix = constraint.data.translateMix;
      } else if (pose == MixPose.Current) {
        constraint
          ..rotateMix +=
              (constraint.data.rotateMix - constraint.rotateMix) * alpha
          ..translateMix +=
              (constraint.data.translateMix - constraint.translateMix) * alpha;
      }
      return;
    }

    double rotate = 0.0, translate = 0.0;
    if (time >= frames[frames.length - PathConstraintMixTimeline.entries]) {
      // Time is after last frame.
      rotate = frames[frames.length + PathConstraintMixTimeline.prevRotate];
      translate =
          frames[frames.length + PathConstraintMixTimeline.prevTranslate];
    } else {
      // Interpolate between the previous frame and the current frame.
      final int frame = Animation.binarySearch(
          frames, time, PathConstraintMixTimeline.entries);
      rotate = frames[frame + PathConstraintMixTimeline.prevRotate];
      translate = frames[frame + PathConstraintMixTimeline.prevTranslate];
      final double frameTime = frames[frame];
      final double percent = getCurvePercent(
          frame ~/ PathConstraintMixTimeline.entries - 1,
          1 -
              (time - frameTime) /
                  (frames[frame + PathConstraintMixTimeline.prevTime] -
                      frameTime));

      rotate +=
          (frames[frame + PathConstraintMixTimeline.rotate] - rotate) * percent;
      translate +=
          (frames[frame + PathConstraintMixTimeline.translate] - translate) *
              percent;
    }

    if (pose == MixPose.Setup) {
      constraint
        ..rotateMix = constraint.data.rotateMix +
            (rotate - constraint.data.rotateMix) * alpha
        ..translateMix = constraint.data.translateMix +
            (translate - constraint.data.translateMix) * alpha;
    } else {
      constraint
        ..rotateMix += (rotate - constraint.rotateMix) * alpha
        ..translateMix += (translate - constraint.translateMix) * alpha;
    }
  }
}
