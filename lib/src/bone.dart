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

class Bone implements Updatable {
  final BoneData data;
  final Skeleton skeleton;
  final List<Bone> children = <Bone>[];

  Bone? parent;

  double x = 0.0,
      y = 0.0,
      rotation = 0.0,
      scaleX = 1.0,
      scaleY = 1.0,
      shearX = 0.0,
      shearY = 0.0;
  double ax = 0.0,
      ay = 0.0,
      arotation = 0.0,
      ascaleX = 0.0,
      ascaleY = 0.0,
      ashearX = 0.0,
      ashearY = 0.0;
  bool appliedValid = false;

  double a = 0.0, b = 0.0, worldX = 0.0;
  double c = 0.0, d = 0.0, worldY = 0.0;

  bool sorted = false;

  Bone(this.data, this.skeleton, this.parent) {
    setToSetupPose();
  }

  @override
  void update() {
    updateWorldTransformWith(x, y, rotation, scaleX, scaleY, shearX, shearY);
  }

  void updateWorldTransform() {
    updateWorldTransformWith(x, y, rotation, scaleX, scaleY, shearX, shearY);
  }

  void updateWorldTransformWith(double x, double y, double rotation,
      double scaleX, double scaleY, double shearX, double shearY) {
    ax = x;
    ay = y;
    arotation = rotation;
    ascaleX = scaleX;
    ascaleY = scaleY;
    ashearX = shearX;
    ashearY = shearY;
    appliedValid = true;

    if (parent == null) {
      // Root bone.
      final double rotationY = rotation + 90 + shearY;
      double la = MathUtils.cosDeg(rotation + shearX) * scaleX;
      double lb = MathUtils.cosDeg(rotationY) * scaleY;
      double lc = MathUtils.sinDeg(rotation + shearX) * scaleX;
      double ld = MathUtils.sinDeg(rotationY) * scaleY;
      final Skeleton skeleton = this.skeleton;
      if (skeleton.flipX) {
        x = -x;
        la = -la;
        lb = -lb;
      }
      if (skeleton.flipY) {
        y = -y;
        lc = -lc;
        ld = -ld;
      }
      a = la;
      b = lb;
      c = lc;
      d = ld;
      worldX = x + skeleton.x;
      worldY = y + skeleton.y;
      return;
    }

    double pa = parent!.a, pb = parent!.b, pc = parent!.c, pd = parent!.d;
    worldX = pa * x + pb * y + parent!.worldX;
    worldY = pc * x + pd * y + parent!.worldY;

    switch (data.transformMode) {
      case TransformMode.Normal:
        {
          final double rotationY = rotation + 90 + shearY;
          final double la = MathUtils.cosDeg(rotation + shearX) * scaleX;
          final double lb = MathUtils.cosDeg(rotationY) * scaleY;
          final double lc = MathUtils.sinDeg(rotation + shearX) * scaleX;
          final double ld = MathUtils.sinDeg(rotationY) * scaleY;
          a = pa * la + pb * lc;
          b = pa * lb + pb * ld;
          c = pc * la + pd * lc;
          d = pc * lb + pd * ld;
          return;
        }
      case TransformMode.OnlyTranslation:
        {
          final double rotationY = rotation + 90 + shearY;
          a = MathUtils.cosDeg(rotation + shearX) * scaleX;
          b = MathUtils.cosDeg(rotationY) * scaleY;
          c = MathUtils.sinDeg(rotation + shearX) * scaleX;
          d = MathUtils.sinDeg(rotationY) * scaleY;
          break;
        }
      case TransformMode.NoRotationOrReflection:
        {
          double s = pa * pa + pc * pc;
          double prx = 0.0;
          if (s > 0.0001) {
            s = (pa * pd - pb * pc).abs() / s;
            pb = pc * s;
            pd = pa * s;
            prx = math.atan2(pc, pa) * MathUtils.radDeg;
          } else {
            pa = 0.0;
            pc = 0.0;
            prx = 90 - math.atan2(pd, pb) * MathUtils.radDeg;
          }
          final double rx = rotation + shearX - prx;
          final double ry = rotation + shearY - prx + 90;
          final double la = MathUtils.cosDeg(rx) * scaleX;
          final double lb = MathUtils.cosDeg(ry) * scaleY;
          final double lc = MathUtils.sinDeg(rx) * scaleX;
          final double ld = MathUtils.sinDeg(ry) * scaleY;
          a = pa * la - pb * lc;
          b = pa * lb - pb * ld;
          c = pc * la + pd * lc;
          d = pc * lb + pd * ld;
          break;
        }
      case TransformMode.NoScale:
      case TransformMode.NoScaleOrReflection:
        {
          final double cosDeg = MathUtils.cosDeg(rotation);
          final double sinDeg = MathUtils.sinDeg(rotation);
          double za = pa * cosDeg + pb * sinDeg;
          double zc = pc * cosDeg + pd * sinDeg;
          double s = math.sqrt(za * za + zc * zc);
          if (s > 0.00001) s = 1 / s;
          za *= s;
          zc *= s;
          s = math.sqrt(za * za + zc * zc);
          final double r = math.pi / 2 + math.atan2(zc, za);
          double zb = math.cos(r) * s;
          double zd = math.sin(r) * s;
          final double la = MathUtils.cosDeg(shearX) * scaleX;
          final double lb = MathUtils.cosDeg(90 + shearY) * scaleY;
          final double lc = MathUtils.sinDeg(shearX) * scaleX;
          final double ld = MathUtils.sinDeg(90 + shearY) * scaleY;
          if (data.transformMode != TransformMode.NoScaleOrReflection
              ? pa * pd - pb * pc < 0
              : skeleton.flipX != skeleton.flipY) {
            zb = -zb;
            zd = -zd;
          }
          a = za * la + zb * lc;
          b = za * lb + zb * ld;
          c = zc * la + zd * lc;
          d = zc * lb + zd * ld;
          return;
        }
    }

    if (skeleton.flipX) {
      a = -a;
      b = -b;
    }

    if (skeleton.flipY) {
      c = -c;
      d = -d;
    }
  }

  void setToSetupPose() {
    x = data.x;
    y = data.y;
    rotation = data.rotation;
    scaleX = data.scaleX;
    scaleY = data.scaleY;
    shearX = data.shearX;
    shearY = data.shearY;
  }

  double getWorldRotationX() => math.atan2(c, a) * MathUtils.radDeg;

  double getWorldRotationY() => math.atan2(d, b) * MathUtils.radDeg;

  double getWorldScaleX() => math.sqrt(a * a + c * c);

  double getWorldScaleY() => math.sqrt(b * b + d * d);

  void updateAppliedTransform() {
    appliedValid = true;
    final Bone? parent = this.parent;
    if (parent == null) {
      ax = worldX;
      ay = worldY;
      arotation = math.atan2(c, a) * MathUtils.radDeg;
      ascaleX = math.sqrt(a * a + c * c);
      ascaleY = math.sqrt(b * b + d * d);
      ashearX = 0.0;
      ashearY = math.atan2(a * b + c * d, a * d - b * c) * MathUtils.radDeg;
      return;
    }
    final double pa = parent.a, pb = parent.b, pc = parent.c, pd = parent.d;
    final double pid = 1 / (pa * pd - pb * pc);
    final double dx = worldX - parent.worldX, dy = worldY - parent.worldY;
    ax = (dx * pd * pid - dy * pb * pid);
    ay = (dy * pa * pid - dx * pc * pid);
    final double ia = pid * pd;
    final double id = pid * pa;
    final double ib = pid * pb;
    final double ic = pid * pc;
    final double ra = ia * a - ib * c;
    final double rb = ia * b - ib * d;
    final double rc = id * c - ic * a;
    final double rd = id * d - ic * b;
    ashearX = 0.0;
    ascaleX = math.sqrt(ra * ra + rc * rc);
    if (ascaleX > 0.0001) {
      final double det = ra * rd - rb * rc;
      ascaleY = det / ascaleX;
      ashearY = math.atan2(ra * rb + rc * rd, det) * MathUtils.radDeg;
      arotation = math.atan2(rc, ra) * MathUtils.radDeg;
    } else {
      ascaleX = 0.0;
      ascaleY = math.sqrt(rb * rb + rd * rd);
      ashearY = 0.0;
      arotation = 90 - math.atan2(rd, rb) * MathUtils.radDeg;
    }
  }

  Vector2 worldToLocal(Vector2 world) {
    final double a = this.a, b = this.b, c = this.c, d = this.d;
    final double invDet = 1 / (a * d - b * c);
    final double x = world.x! - worldX, y = world.y! - worldY;
    world
      ..x = (x * d * invDet - y * b * invDet)
      ..y = (y * a * invDet - x * c * invDet);
    return world;
  }

  Vector2 localToWorld(Vector2 local) {
    final double? x = local.x, y = local.y;
    local
      ..x = x! * a + y! * b + worldX
      ..y = x * c + y * d + worldY;
    return local;
  }

  double worldToLocalRotation(double worldRotation) {
    final double sin = MathUtils.sinDeg(worldRotation),
        cos = MathUtils.cosDeg(worldRotation);
    return math.atan2(a * sin - c * cos, d * cos - b * sin) * MathUtils.radDeg;
  }

  double localToWorldRotation(double localRotation) {
    final double sin = MathUtils.sinDeg(localRotation),
        cos = MathUtils.cosDeg(localRotation);
    return math.atan2(cos * c + sin * d, cos * a + sin * b) * MathUtils.radDeg;
  }

  void rotateWorld(double degrees) {
    final double a = this.a, b = this.b, c = this.c, d = this.d;
    final double cos = MathUtils.cosDeg(degrees),
        sin = MathUtils.sinDeg(degrees);
    this.a = cos * a - sin * c;
    this.b = cos * b - sin * d;
    this.c = sin * a + cos * c;
    this.d = sin * b + cos * d;
    appliedValid = false;
  }
}
