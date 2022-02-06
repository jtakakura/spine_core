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

class PathConstraint extends Constraint {
  static const int none = -1, before = -2, after = -3;
  static const double epsilon = 0.00001;

  final PathConstraintData data;
  final List<Bone> bones = <Bone>[];
  Slot? target;
  double position = 0.0, spacing = 0.0, rotateMix = 0.0, translateMix = 0.0;

  Float32List spaces = Float32List(0), positions = Float32List(0);
  Float32List world = Float32List(0),
      curves = Float32List(0),
      lengths = Float32List(0);
  Float32List segments = Float32List(10);

  PathConstraint(this.data, Skeleton skeleton) {
    final int n = data.bones.length;
    for (int i = 0; i < n; i++) {
      bones.add(skeleton.findBone(data.bones[i].name)!);
    }
    target = skeleton.findSlot(data.target!.name);
    position = data.position;
    spacing = data.spacing;
    rotateMix = data.rotateMix;
    translateMix = data.translateMix;
  }

  void apply() {
    update();
  }

  @override
  void update() {
    if (target!.getAttachment() is! PathAttachment) return;
    final PathAttachment attachment = target!.getAttachment() as PathAttachment;

    final double rotateMix = this.rotateMix, translateMix = this.translateMix;
    final bool translate = translateMix > 0, rotate = rotateMix > 0;
    if (!translate && !rotate) return;

    final PathConstraintData data = this.data;
    final SpacingMode? spacingMode = data.spacingMode;
    final bool lengthSpacing = spacingMode == SpacingMode.length;
    final RotateMode? rotateMode = data.rotateMode;
    final bool tangents = rotateMode == RotateMode.tangent,
        scale = rotateMode == RotateMode.chainScale;
    final int boneCount = this.bones.length,
        spacesCount = tangents ? boneCount : boneCount + 1;
    final List<Bone> bones = this.bones;
    final Float32List spaces = ArrayUtils.copyWithNewArraySize(
        this.spaces, spacesCount, double.infinity) as Float32List;
    late Float32List lengths;
    final double spacing = this.spacing;
    if (scale || lengthSpacing) {
      if (scale) {
        lengths = ArrayUtils.copyWithNewArraySize(
            this.lengths, boneCount, double.infinity) as Float32List;
      }
      final int n = spacesCount - 1;
      for (int i = 0; i < n;) {
        final Bone bone = bones[i];
        final double setupLength = bone.data.length;
        if (setupLength < PathConstraint.epsilon) {
          if (scale) lengths[i] = 0.0;
          spaces[++i] = 0.0;
        } else {
          final double x = setupLength * bone.a, y = setupLength * bone.c;
          final double length = math.sqrt(x * x + y * y);
          if (scale) lengths[i] = length;
          spaces[++i] = (lengthSpacing ? setupLength + spacing : spacing) *
              length /
              setupLength;
        }
      }
    } else {
      for (int i = 1; i < spacesCount; i++) {
        spaces[i] = spacing;
      }
    }

    final Float32List positions = computeWorldPositions(
        attachment,
        spacesCount,
        tangents,
        data.positionMode == PositionMode.percent,
        spacingMode == SpacingMode.percent);
    double boneX = positions[0],
        boneY = positions[1],
        offsetRotation = data.offsetRotation;
    bool tip = false;
    if (offsetRotation == 0) {
      tip = rotateMode == RotateMode.chain;
    } else {
      tip = false;
      final Bone p = target!.bone;
      offsetRotation = offsetRotation *
          (p.a * p.d - p.b * p.c > 0 ? MathUtils.degRad : -MathUtils.degRad);
    }
    for (int i = 0, p = 3; i < boneCount; i++, p += 3) {
      final Bone bone = bones[i];
      bone
        ..worldX += (boneX - bone.worldX) * translateMix
        ..worldY += (boneY - bone.worldY) * translateMix;
      final double x = positions[p],
          y = positions[p + 1],
          dx = x - boneX,
          dy = y - boneY;
      if (scale) {
        final double length = lengths[i];
        if (length != 0) {
          final double s =
              (math.sqrt(dx * dx + dy * dy) / length - 1) * rotateMix + 1;
          bone
            ..a *= s
            ..c *= s;
        }
      }
      boneX = x;
      boneY = y;
      if (rotate) {
        final double a = bone.a, b = bone.b, c = bone.c, d = bone.d;
        double r = 0.0, cos = 0.0, sin = 0.0;
        if (tangents) {
          r = positions[p - 1];
        } else if (spaces[i + 1] == 0) {
          r = positions[p + 2];
        } else {
          r = math.atan2(dy, dx);
        }
        r -= math.atan2(c, a);
        if (tip) {
          cos = math.cos(r);
          sin = math.sin(r);
          final double length = bone.data.length;
          boneX += (length * (cos * a - sin * c) - dx) * rotateMix;
          boneY += (length * (sin * a + cos * c) - dy) * rotateMix;
        } else {
          r += offsetRotation;
        }
        if (r > math.pi) {
          r -= math.pi * 2;
        } else if (r < -math.pi) {
          r += math.pi * 2;
        }
        r *= rotateMix;
        cos = math.cos(r);
        sin = math.sin(r);
        bone
          ..a = cos * a - sin * c
          ..b = cos * b - sin * d
          ..c = sin * a + cos * c
          ..d = sin * b + cos * d;
      }
      bone.appliedValid = false;
    }
  }

  Float32List computeWorldPositions(PathAttachment path, int spacesCount,
      bool tangents, bool percentPosition, bool percentSpacing) {
    final Slot? target = this.target;
    double position = this.position;
    final Float32List spaces = this.spaces;
    final Float32List out = ArrayUtils.copyWithNewArraySize(
        positions, spacesCount * 3 + 2, double.infinity) as Float32List;
    Float32List world;
    final bool closed = path.closed;
    int verticesLength = path.worldVerticesLength,
        curveCount = verticesLength ~/ 6,
        prevCurve = PathConstraint.none;

    if (!path.constantSpeed) {
      final Float32List lengths = path.lengths;
      curveCount -= closed ? 1 : 2;
      final double pathLength = lengths[curveCount];
      if (percentPosition) position = position * pathLength;
      if (percentSpacing) {
        for (int i = 0; i < spacesCount; i++) {
          spaces[i] *= pathLength;
        }
      }
      world = ArrayUtils.copyWithNewArraySize(this.world, 8, double.infinity)
          as Float32List;
      for (int i = 0, o = 0, curve = 0; i < spacesCount; i++, o += 3) {
        final double space = spaces[i];
        position = position + space;
        double p = position;

        if (closed) {
          p %= pathLength;
          if (p < 0) p += pathLength;
          curve = 0;
        } else if (p < 0) {
          if (prevCurve != PathConstraint.before) {
            prevCurve = PathConstraint.before;
            path.computeWorldVertices(target!, 2, 4, world, 0, 2);
          }
          addBeforePosition(p, world, 0, out, o);
          continue;
        } else if (p > pathLength) {
          if (prevCurve != PathConstraint.after) {
            prevCurve = PathConstraint.after;
            path.computeWorldVertices(
                target!, verticesLength - 6, 4, world, 0, 2);
          }
          addAfterPosition(p - pathLength, world, 0, out, o);
          continue;
        }

        // Determine curve containing position.
        for (;; curve++) {
          final double length = lengths[curve];
          if (p > length) continue;
          if (curve == 0) {
            p /= length;
          } else {
            final double prev = lengths[curve - 1];
            p = (p - prev) / (length - prev);
          }
          break;
        }
        if (curve != prevCurve) {
          prevCurve = curve;
          if (closed && curve == curveCount) {
            path
              ..computeWorldVertices(
                  target!, verticesLength - 4, 4, world, 0, 2)
              ..computeWorldVertices(target, 0, 4, world, 4, 2);
          } else {
            path.computeWorldVertices(target!, curve * 6 + 2, 8, world, 0, 2);
          }
        }
        addCurvePosition(
            p,
            world[0],
            world[1],
            world[2],
            world[3],
            world[4],
            world[5],
            world[6],
            world[7],
            out,
            o,
            tangents || (i > 0 && space == 0));
      }
      return out;
    }

    // World vertices.
    if (closed) {
      verticesLength += 2;
      world = ArrayUtils.copyWithNewArraySize(
          this.world, verticesLength, double.infinity) as Float32List;
      path
        ..computeWorldVertices(target!, 2, verticesLength - 4, world, 0, 2)
        ..computeWorldVertices(target, 0, 2, world, verticesLength - 4, 2);
      world[verticesLength - 2] = world[0];
      world[verticesLength - 1] = world[1];
    } else {
      curveCount--;
      verticesLength -= 4;
      world = ArrayUtils.copyWithNewArraySize(
          this.world, verticesLength, double.infinity) as Float32List;
      path.computeWorldVertices(target!, 2, verticesLength, world, 0, 2);
    }

    // Curve lengths.
    final Float32List curves = ArrayUtils.copyWithNewArraySize(
        this.curves, curveCount, double.infinity) as Float32List;
    double pathLength = 0.0;
    double x1 = world[0],
        y1 = world[1],
        cx1 = 0.0,
        cy1 = 0.0,
        cx2 = 0.0,
        cy2 = 0.0,
        x2 = 0.0,
        y2 = 0.0;
    double tmpx = 0.0,
        tmpy = 0.0,
        dddfx = 0.0,
        dddfy = 0.0,
        ddfx = 0.0,
        ddfy = 0.0,
        dfx = 0.0,
        dfy = 0.0;
    for (int i = 0, w = 2; i < curveCount; i++, w += 6) {
      cx1 = world[w];
      cy1 = world[w + 1];
      cx2 = world[w + 2];
      cy2 = world[w + 3];
      x2 = world[w + 4];
      y2 = world[w + 5];
      tmpx = (x1 - cx1 * 2 + cx2) * 0.1875;
      tmpy = (y1 - cy1 * 2 + cy2) * 0.1875;
      dddfx = ((cx1 - cx2) * 3 - x1 + x2) * 0.09375;
      dddfy = ((cy1 - cy2) * 3 - y1 + y2) * 0.09375;
      ddfx = tmpx * 2 + dddfx;
      ddfy = tmpy * 2 + dddfy;
      dfx = (cx1 - x1) * 0.75 + tmpx + dddfx * 0.16666667;
      dfy = (cy1 - y1) * 0.75 + tmpy + dddfy * 0.16666667;
      pathLength += math.sqrt(dfx * dfx + dfy * dfy);
      dfx += ddfx;
      dfy += ddfy;
      ddfx += dddfx;
      ddfy += dddfy;
      pathLength += math.sqrt(dfx * dfx + dfy * dfy);
      dfx += ddfx;
      dfy += ddfy;
      pathLength += math.sqrt(dfx * dfx + dfy * dfy);
      dfx += ddfx + dddfx;
      dfy += ddfy + dddfy;
      pathLength += math.sqrt(dfx * dfx + dfy * dfy);
      curves[i] = pathLength;
      x1 = x2;
      y1 = y2;
    }
    if (percentPosition) position = position * pathLength;
    if (percentSpacing) {
      for (int i = 0; i < spacesCount; i++) {
        spaces[i] *= pathLength;
      }
    }

    final Float32List segments = this.segments;
    double curveLength = 0.0;
    for (int i = 0, o = 0, curve = 0, segment = 0;
        i < spacesCount;
        i++, o += 3) {
      final double space = spaces[i];
      position = position + space;
      double p = position;

      if (closed) {
        p %= pathLength;
        if (p < 0) p += pathLength;
        curve = 0;
      } else if (p < 0) {
        addBeforePosition(p, world, 0, out, o);
        continue;
      } else if (p > pathLength) {
        addAfterPosition(p - pathLength, world, verticesLength - 4, out, o);
        continue;
      }

      // Determine curve containing position.
      for (;; curve++) {
        final double length = curves[curve];
        if (p > length) continue;
        if (curve == 0) {
          p /= length;
        } else {
          final double prev = curves[curve - 1];
          p = (p - prev) / (length - prev);
        }
        break;
      }

      // Curve segment lengths.
      if (curve != prevCurve) {
        prevCurve = curve;
        int ii = curve * 6;
        x1 = world[ii];
        y1 = world[ii + 1];
        cx1 = world[ii + 2];
        cy1 = world[ii + 3];
        cx2 = world[ii + 4];
        cy2 = world[ii + 5];
        x2 = world[ii + 6];
        y2 = world[ii + 7];
        tmpx = (x1 - cx1 * 2 + cx2) * 0.03;
        tmpy = (y1 - cy1 * 2 + cy2) * 0.03;
        dddfx = ((cx1 - cx2) * 3 - x1 + x2) * 0.006;
        dddfy = ((cy1 - cy2) * 3 - y1 + y2) * 0.006;
        ddfx = tmpx * 2 + dddfx;
        ddfy = tmpy * 2 + dddfy;
        dfx = (cx1 - x1) * 0.3 + tmpx + dddfx * 0.16666667;
        dfy = (cy1 - y1) * 0.3 + tmpy + dddfy * 0.16666667;
        curveLength = math.sqrt(dfx * dfx + dfy * dfy);
        segments[0] = curveLength;
        for (ii = 1; ii < 8; ii++) {
          dfx += ddfx;
          dfy += ddfy;
          ddfx += dddfx;
          ddfy += dddfy;
          curveLength += math.sqrt(dfx * dfx + dfy * dfy);
          segments[ii] = curveLength;
        }
        dfx += ddfx;
        dfy += ddfy;
        curveLength += math.sqrt(dfx * dfx + dfy * dfy);
        segments[8] = curveLength;
        dfx += ddfx + dddfx;
        dfy += ddfy + dddfy;
        curveLength += math.sqrt(dfx * dfx + dfy * dfy);
        segments[9] = curveLength;
        segment = 0;
      }

      // Weight by segment length.
      p *= curveLength;
      for (;; segment++) {
        final double length = segments[segment];
        if (p > length) continue;
        if (segment == 0) {
          p /= length;
        } else {
          final double prev = segments[segment - 1];
          p = segment + (p - prev) / (length - prev);
        }
        break;
      }
      addCurvePosition(p * 0.1, x1, y1, cx1, cy1, cx2, cy2, x2, y2, out, o,
          tangents || (i > 0 && space == 0));
    }
    return out;
  }

  void addBeforePosition(
      double p, Float32List temp, int i, Float32List out, int o) {
    final double x1 = temp[i],
        y1 = temp[i + 1],
        dx = temp[i + 2] - x1,
        dy = temp[i + 3] - y1,
        r = math.atan2(dy, dx);
    out[o] = x1 + p * math.cos(r);
    out[o + 1] = y1 + p * math.sin(r);
    out[o + 2] = r;
  }

  void addAfterPosition(
      double p, Float32List temp, int i, Float32List out, int o) {
    final double x1 = temp[i + 2],
        y1 = temp[i + 3],
        dx = x1 - temp[i],
        dy = y1 - temp[i + 1],
        r = math.atan2(dy, dx);
    out[o] = x1 + p * math.cos(r);
    out[o + 1] = y1 + p * math.sin(r);
    out[o + 2] = r;
  }

  void addCurvePosition(
      double p,
      double x1,
      double y1,
      double cx1,
      double cy1,
      double cx2,
      double cy2,
      double x2,
      double y2,
      Float32List out,
      int o,
      bool tangents) {
    if (p == 0 || p.isNaN) p = 0.0001;
    final double tt = p * p, ttt = tt * p, u = 1 - p, uu = u * u, uuu = uu * u;
    final double ut = u * p, ut3 = ut * 3, uut3 = u * ut3, utt3 = ut3 * p;
    final double x = x1 * uuu + cx1 * uut3 + cx2 * utt3 + x2 * ttt,
        y = y1 * uuu + cy1 * uut3 + cy2 * utt3 + y2 * ttt;
    out[o] = x;
    out[o + 1] = y;
    if (tangents) {
      out[o + 2] = math.atan2(y - (y1 * uu + cy1 * ut * 2 + cy2 * tt),
          x - (x1 * uu + cx1 * ut * 2 + cx2 * tt));
    }
  }

  @override
  int getOrder() => data.order;
}
