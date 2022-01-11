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

class TransformConstraint extends Constraint {
  final TransformConstraintData data;
  final List<Bone> bones = <Bone>[];
  final Vector2 temp = Vector2();
  Bone? target;
  double rotateMix = 0.0, translateMix = 0.0, scaleMix = 0.0, shearMix = 0.0;

  TransformConstraint(this.data, Skeleton skeleton) {
    rotateMix = data.rotateMix;
    translateMix = data.translateMix;
    scaleMix = data.scaleMix;
    shearMix = data.shearMix;
    for (int i = 0; i < data.bones.length; i++)
      bones.add(skeleton.findBone(data.bones[i].name)!);
    target = skeleton.findBone(data.target!.name);
  }

  void apply() {
    update();
  }

  @override
  void update() {
    if (data.local) {
      if (data.relative)
        applyRelativeLocal();
      else
        applyAbsoluteLocal();
    } else {
      if (data.relative)
        applyRelativeWorld();
      else
        applyAbsoluteWorld();
    }
  }

  void applyAbsoluteWorld() {
    final double? rotateMix = this.rotateMix,
        translateMix = this.translateMix,
        scaleMix = this.scaleMix,
        shearMix = this.shearMix;
    final Bone target = this.target!;
    final double ta = target.a, tb = target.b, tc = target.c, td = target.d;
    final double degRadReflect =
        ta * td - tb * tc > 0 ? MathUtils.degRad : -MathUtils.degRad;
    final double offsetRotation = data.offsetRotation * degRadReflect;
    final double offsetShearY = data.offsetShearY * degRadReflect;
    final List<Bone> bones = this.bones;
    final int n = bones.length;
    for (int i = 0; i < n; i++) {
      final Bone bone = bones[i];
      bool modified = false;

      if (rotateMix != 0) {
        final double a = bone.a, b = bone.b, c = bone.c, d = bone.d;
        double r = math.atan2(tc, ta) - math.atan2(c, a) + offsetRotation;
        if (r > math.pi)
          r -= math.pi * 2;
        else if (r < -math.pi) r += math.pi * 2;
        r *= rotateMix!;
        final double cos = math.cos(r), sin = math.sin(r);
        bone
          ..a = cos * a - sin * c
          ..b = cos * b - sin * d
          ..c = sin * a + cos * c
          ..d = sin * b + cos * d;
        modified = true;
      }

      if (translateMix != 0) {
        final Vector2 temp = this.temp..set(data.offsetX, data.offsetY);
        target.localToWorld(temp);
        bone
          ..worldX += (temp.x - bone.worldX) * translateMix!
          ..worldY += (temp.y - bone.worldY) * translateMix;
        modified = true;
      }

      if (scaleMix! > 0) {
        double s = math.sqrt(bone.a * bone.a + bone.c * bone.c);
        double ts = math.sqrt(ta * ta + tc * tc);
        if (s > 0.00001) s = (s + (ts - s + data.offsetScaleX) * scaleMix) / s;
        bone
          ..a *= s
          ..c *= s;
        s = math.sqrt(bone.b * bone.b + bone.d * bone.d);
        ts = math.sqrt(tb * tb + td * td);
        if (s > 0.00001) s = (s + (ts - s + data.offsetScaleY) * scaleMix) / s;
        bone
          ..b *= s
          ..d *= s;
        modified = true;
      }

      if (shearMix! > 0) {
        final double b = bone.b, d = bone.d;
        final double by = math.atan2(d, b);
        double r = math.atan2(td, tb) -
            math.atan2(tc, ta) -
            (by - math.atan2(bone.c, bone.a));
        if (r > math.pi)
          r -= math.pi * 2;
        else if (r < -math.pi) r += math.pi * 2;
        r = by + (r + offsetShearY) * shearMix;
        final double s = math.sqrt(b * b + d * d);
        bone
          ..b = math.cos(r) * s
          ..d = math.sin(r) * s;
        modified = true;
      }

      if (modified) bone.appliedValid = false;
    }
  }

  void applyRelativeWorld() {
    final double? rotateMix = this.rotateMix,
        translateMix = this.translateMix,
        scaleMix = this.scaleMix,
        shearMix = this.shearMix;
    final Bone target = this.target!;
    final double ta = target.a, tb = target.b, tc = target.c, td = target.d;
    final double degRadReflect =
        ta * td - tb * tc > 0 ? MathUtils.degRad : -MathUtils.degRad;
    final double offsetRotation = data.offsetRotation * degRadReflect,
        offsetShearY = data.offsetShearY * degRadReflect;
    final List<Bone> bones = this.bones;
    final int n = bones.length;
    for (int i = 0; i < n; i++) {
      final Bone bone = bones[i];
      bool modified = false;

      if (rotateMix != 0) {
        final double a = bone.a, b = bone.b, c = bone.c, d = bone.d;
        double r = math.atan2(tc, ta) + offsetRotation;
        if (r > math.pi)
          r -= math.pi * 2;
        else if (r < -math.pi) r += math.pi * 2;
        r *= rotateMix!;
        final double cos = math.cos(r), sin = math.sin(r);
        bone
          ..a = cos * a - sin * c
          ..b = cos * b - sin * d
          ..c = sin * a + cos * c
          ..d = sin * b + cos * d;
        modified = true;
      }

      if (translateMix != 0) {
        final Vector2 temp = this.temp..set(data.offsetX, data.offsetY);
        target.localToWorld(temp);
        bone
          ..worldX += temp.x * translateMix!
          ..worldY += temp.y * translateMix;
        modified = true;
      }

      if (scaleMix! > 0) {
        double s =
            (math.sqrt(ta * ta + tc * tc) - 1 + data.offsetScaleX) * scaleMix +
                1;
        bone
          ..a *= s
          ..c *= s;
        s = (math.sqrt(tb * tb + td * td) - 1 + data.offsetScaleY) * scaleMix +
            1;
        bone
          ..b *= s
          ..d *= s;
        modified = true;
      }

      if (shearMix! > 0) {
        double r = math.atan2(td, tb) - math.atan2(tc, ta);
        if (r > math.pi)
          r -= math.pi * 2;
        else if (r < -math.pi) r += math.pi * 2;
        final double b = bone.b, d = bone.d;
        r = math.atan2(d, b) + (r - math.pi / 2 + offsetShearY) * shearMix;
        final double s = math.sqrt(b * b + d * d);
        bone
          ..b = math.cos(r) * s
          ..d = math.sin(r) * s;
        modified = true;
      }

      if (modified) bone.appliedValid = false;
    }
  }

  void applyAbsoluteLocal() {
    final double? rotateMix = this.rotateMix,
        translateMix = this.translateMix,
        scaleMix = this.scaleMix,
        shearMix = this.shearMix;
    final Bone target = this.target!;
    if (!target.appliedValid) target.updateAppliedTransform();
    final List<Bone> bones = this.bones;
    final int n = bones.length;
    for (int i = 0; i < n; i++) {
      final Bone bone = bones[i];
      if (!bone.appliedValid) bone.updateAppliedTransform();

      double? rotation = bone.arotation;
      if (rotateMix != 0) {
        double r = target.arotation - rotation + data.offsetRotation;
        r -= (16384 - (16384.499999999996 - r / 360).toInt()) * 360;
        rotation += r * rotateMix!;
      }

      double? x = bone.ax, y = bone.ay;
      if (translateMix != 0) {
        x = x + (target.ax - x + data.offsetX) * translateMix!;
        y = y + (target.ay - y + data.offsetY) * translateMix;
      }

      double scaleX = bone.ascaleX, scaleY = bone.ascaleY;
      if (scaleMix! > 0) {
        if (scaleX > 0.00001)
          scaleX = (scaleX +
                  (target.ascaleX - scaleX + data.offsetScaleX) * scaleMix) /
              scaleX;
        if (scaleY > 0.00001)
          scaleY = (scaleY +
                  (target.ascaleY - scaleY + data.offsetScaleY) * scaleMix) /
              scaleY;
      }

      final double shearY = bone.ashearY;
      if (shearMix! > 0) {
        double r = target.ashearY - shearY + data.offsetShearY;
        r -= (16384 - (16384.499999999996 - r / 360).toInt()) * 360;
        bone.shearY = bone.shearY + r * shearMix;
      }

      bone.updateWorldTransformWith(
          x, y, rotation, scaleX, scaleY, bone.ashearX, shearY);
    }
  }

  void applyRelativeLocal() {
    final double? rotateMix = this.rotateMix,
        translateMix = this.translateMix,
        scaleMix = this.scaleMix,
        shearMix = this.shearMix;
    final Bone target = this.target!;
    if (!target.appliedValid) target.updateAppliedTransform();
    final List<Bone> bones = this.bones;
    final int n = bones.length;
    for (int i = 0; i < n; i++) {
      final Bone bone = bones[i];
      if (!bone.appliedValid) bone.updateAppliedTransform();

      double rotation = bone.arotation;
      if (rotateMix != 0)
        rotation = rotation + (target.arotation + data.offsetRotation) * rotateMix!;

      double x = bone.ax, y = bone.ay;
      if (translateMix != 0) {
        x = x + (target.ax + data.offsetX) * translateMix!;
        y = y + (target.ay + data.offsetY) * translateMix;
      }

      double scaleX = bone.ascaleX, scaleY = bone.ascaleY;
      if (scaleMix! > 0) {
        if (scaleX > 0.00001)
          scaleX *= ((target.ascaleX - 1 + data.offsetScaleX) * scaleMix) + 1;
        if (scaleY > 0.00001)
          scaleY *= ((target.ascaleY - 1 + data.offsetScaleY) * scaleMix) + 1;
      }

      double shearY = bone.ashearY;
      if (shearMix! > 0)
        shearY = shearY + (target.ashearY + data.offsetShearY) * shearMix;

      bone.updateWorldTransformWith(
          x, y, rotation, scaleX, scaleY, bone.ashearX, shearY);
    }
  }

  @override
  int getOrder() => data.order;
}
