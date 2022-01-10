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

class SkeletonClipping {
  final Triangulator triangulator = Triangulator();
  final List<double> clippingPolygon = <double>[];
  final List<double> clipOutput = <double>[];
  final List<double> clippedVertices = <double>[];
  final List<int> clippedTriangles = <int>[];
  final List<double> scratch = <double>[];

  ClippingAttachment? clipAttachment;
  List<Float32List>? clippingPolygons;

  int clipStart(Slot slot, ClippingAttachment clip) {
    if (clipAttachment != null) return 0;
    clipAttachment = clip;

    final int n = clip.worldVerticesLength;
    final Float32List vertices =
        ArrayUtils.setArraySize(this.clippingPolygon, n, 0.0) as Float32List;
    clip.computeWorldVertices(slot, 0, n, vertices, 0, 2);
    final Float32List clippingPolygon = this.clippingPolygon as Float32List;
    SkeletonClipping.makeClockwise(clippingPolygon);
    final List<Float32List> clippingPolygons = this.clippingPolygons =
        triangulator.decompose(
            clippingPolygon, triangulator.triangulate(clippingPolygon));

    final int nn = clippingPolygons.length;
    for (int i = 0; i < nn; i++) {
      final Float32List polygon = clippingPolygons[i];
      SkeletonClipping.makeClockwise(polygon);
      polygon..add(polygon[0])..add(polygon[1]);
    }

    return clippingPolygons.length;
  }

  void clipEndWithSlot(Slot slot) {
    if (clipAttachment != null && clipAttachment!.endSlot == slot.data)
      clipEnd();
  }

  void clipEnd() {
    if (clipAttachment == null) return;
    clipAttachment = null;
    clippingPolygons = null;
    clippedVertices.length = 0;
    clippedTriangles.length = 0;
    clippingPolygon.length = 0;
  }

  bool isClipping() => clipAttachment != null;

  void clipTriangles(
      Float32List vertices,
      int verticesLength,
      Int16List triangles,
      int trianglesLength,
      Float32List uvs,
      Color light,
      Color dark,
      bool twoColor) {
    final Float32List clipOutput = this.clipOutput as Float32List,
        clippedVertices = this.clippedVertices as Float32List;
    final Int16List clippedTriangles = this.clippedTriangles as Int16List;
    final List<Float32List>? polygons = clippingPolygons;
    final int polygonsCount = clippingPolygons!.length;
    final int vertexSize = twoColor ? 12 : 8;

    int index = 0;
    clippedVertices.length = 0;
    clippedTriangles.length = 0;
    outer:
    for (int i = 0; i < trianglesLength; i += 3) {
      int vertexOffset = triangles[i] << 1;
      final double x1 = vertices[vertexOffset], y1 = vertices[vertexOffset + 1];
      final double u1 = uvs[vertexOffset], v1 = uvs[vertexOffset + 1];

      vertexOffset = triangles[i + 1] << 1;
      final double x2 = vertices[vertexOffset], y2 = vertices[vertexOffset + 1];
      final double u2 = uvs[vertexOffset], v2 = uvs[vertexOffset + 1];

      vertexOffset = triangles[i + 2] << 1;
      final double x3 = vertices[vertexOffset], y3 = vertices[vertexOffset + 1];
      final double u3 = uvs[vertexOffset], v3 = uvs[vertexOffset + 1];

      for (int p = 0; p < polygonsCount; p++) {
        int s = clippedVertices.length;
        if (clip(x1, y1, x2, y2, x3, y3, polygons![p], clipOutput)) {
          final int clipOutputLength = clipOutput.length;
          if (clipOutputLength == 0) continue;
          final double d0 = y2 - y3, d1 = x3 - x2, d2 = x1 - x3, d4 = y3 - y1;
          final double d = 1 / (d0 * d2 + d1 * (y1 - y3));

          int clipOutputCount = clipOutputLength >> 1;
          final Float32List clipOutputItems = this.clipOutput as Float32List;
          final Float32List clippedVerticesItems = ArrayUtils.setArraySize(
              clippedVertices, s + clipOutputCount * vertexSize, 0.0) as Float32List;
          for (int ii = 0; ii < clipOutputLength; ii += 2) {
            final double x = clipOutputItems[ii], y = clipOutputItems[ii + 1];
            clippedVerticesItems[s] = x;
            clippedVerticesItems[s + 1] = y;
            clippedVerticesItems[s + 2] = light.r;
            clippedVerticesItems[s + 3] = light.g;
            clippedVerticesItems[s + 4] = light.b;
            clippedVerticesItems[s + 5] = light.a;
            final double c0 = x - x3, c1 = y - y3;
            final double a = (d0 * c0 + d1 * c1) * d;
            final double b = (d4 * c0 + d2 * c1) * d;
            final double c = 1 - a - b;
            clippedVerticesItems[s + 6] = u1 * a + u2 * b + u3 * c;
            clippedVerticesItems[s + 7] = v1 * a + v2 * b + v3 * c;
            if (twoColor) {
              clippedVerticesItems[s + 8] = dark.r;
              clippedVerticesItems[s + 9] = dark.g;
              clippedVerticesItems[s + 10] = dark.b;
              clippedVerticesItems[s + 11] = dark.a;
            }
            s += vertexSize;
          }

          s = clippedTriangles.length;
          final Int16List clippedTrianglesItems = ArrayUtils.setArraySize(
              clippedTriangles, s + 3 * (clipOutputCount - 2), 0.0) as Int16List;
          clipOutputCount--;
          for (int ii = 1; ii < clipOutputCount; ii++) {
            clippedTrianglesItems[s] = index;
            clippedTrianglesItems[s + 1] = (index + ii);
            clippedTrianglesItems[s + 2] = (index + ii + 1);
            s += 3;
          }
          index += clipOutputCount + 1;
        } else {
          final Float32List clippedVerticesItems =
              ArrayUtils.setArraySize(clippedVertices, s + 3 * vertexSize, 0.0) as Float32List;
          clippedVerticesItems[s] = x1;
          clippedVerticesItems[s + 1] = y1;
          clippedVerticesItems[s + 2] = light.r;
          clippedVerticesItems[s + 3] = light.g;
          clippedVerticesItems[s + 4] = light.b;
          clippedVerticesItems[s + 5] = light.a;
          if (!twoColor) {
            clippedVerticesItems[s + 6] = u1;
            clippedVerticesItems[s + 7] = v1;

            clippedVerticesItems[s + 8] = x2;
            clippedVerticesItems[s + 9] = y2;
            clippedVerticesItems[s + 10] = light.r;
            clippedVerticesItems[s + 11] = light.g;
            clippedVerticesItems[s + 12] = light.b;
            clippedVerticesItems[s + 13] = light.a;
            clippedVerticesItems[s + 14] = u2;
            clippedVerticesItems[s + 15] = v2;

            clippedVerticesItems[s + 16] = x3;
            clippedVerticesItems[s + 17] = y3;
            clippedVerticesItems[s + 18] = light.r;
            clippedVerticesItems[s + 19] = light.g;
            clippedVerticesItems[s + 20] = light.b;
            clippedVerticesItems[s + 21] = light.a;
            clippedVerticesItems[s + 22] = u3;
            clippedVerticesItems[s + 23] = v3;
          } else {
            clippedVerticesItems[s + 6] = u1;
            clippedVerticesItems[s + 7] = v1;
            clippedVerticesItems[s + 8] = dark.r;
            clippedVerticesItems[s + 9] = dark.g;
            clippedVerticesItems[s + 10] = dark.b;
            clippedVerticesItems[s + 11] = dark.a;

            clippedVerticesItems[s + 12] = x2;
            clippedVerticesItems[s + 13] = y2;
            clippedVerticesItems[s + 14] = light.r;
            clippedVerticesItems[s + 15] = light.g;
            clippedVerticesItems[s + 16] = light.b;
            clippedVerticesItems[s + 17] = light.a;
            clippedVerticesItems[s + 18] = u2;
            clippedVerticesItems[s + 19] = v2;
            clippedVerticesItems[s + 20] = dark.r;
            clippedVerticesItems[s + 21] = dark.g;
            clippedVerticesItems[s + 22] = dark.b;
            clippedVerticesItems[s + 23] = dark.a;

            clippedVerticesItems[s + 24] = x3;
            clippedVerticesItems[s + 25] = y3;
            clippedVerticesItems[s + 26] = light.r;
            clippedVerticesItems[s + 27] = light.g;
            clippedVerticesItems[s + 28] = light.b;
            clippedVerticesItems[s + 29] = light.a;
            clippedVerticesItems[s + 30] = u3;
            clippedVerticesItems[s + 31] = v3;
            clippedVerticesItems[s + 32] = dark.r;
            clippedVerticesItems[s + 33] = dark.g;
            clippedVerticesItems[s + 34] = dark.b;
            clippedVerticesItems[s + 35] = dark.a;
          }

          s = clippedTriangles.length;
          final Int16List clippedTrianglesItems =
              ArrayUtils.setArraySize(clippedTriangles, s + 3, 0) as Int16List;
          clippedTrianglesItems[s] = index;
          clippedTrianglesItems[s + 1] = (index + 1);
          clippedTrianglesItems[s + 2] = (index + 2);
          index += 3;
          continue outer;
        }
      }
    }
  }

  bool clip(double x1, double y1, double x2, double y2, double x3, double y3,
      Float32List clippingArea, Float32List output) {
    final Float32List originalOutput = output;
    bool clipped = false;

    // Avoid copy at the end.
    Float32List input;
    if (clippingArea.length % 4 >= 2) {
      input = output;
      output = scratch as Float32List;
    } else
      input = scratch as Float32List;

    input
      ..length = 0
      ..add(x1)
      ..add(y1)
      ..add(x2)
      ..add(y2)
      ..add(x3)
      ..add(y3)
      ..add(x1)
      ..add(y1);
    output.length = 0;

    final Float32List clippingVertices = clippingArea;
    final int clippingVerticesLast = clippingArea.length - 4;
    for (int i = 0;; i += 2) {
      final double edgeX = clippingVertices[i], edgeY = clippingVertices[i + 1];
      final double edgeX2 = clippingVertices[i + 2],
          edgeY2 = clippingVertices[i + 3];
      final double deltaX = edgeX - edgeX2, deltaY = edgeY - edgeY2;

      final Float32List inputVertices = input;
      final int inputVerticesLength = input.length - 2,
          outputStart = output.length;
      for (int ii = 0; ii < inputVerticesLength; ii += 2) {
        final double inputX = inputVertices[ii], inputY = inputVertices[ii + 1];
        final double inputX2 = inputVertices[ii + 2],
            inputY2 = inputVertices[ii + 3];
        final bool side2 =
            deltaX * (inputY2 - edgeY2) - deltaY * (inputX2 - edgeX2) > 0;
        if (deltaX * (inputY - edgeY2) - deltaY * (inputX - edgeX2) > 0) {
          if (side2) {
            // v1 inside, v2 inside
            output..add(inputX2)..add(inputY2);
            continue;
          }
          // v1 inside, v2 outside
          final double c0 = inputY2 - inputY, c2 = inputX2 - inputX;
          final double ua = (c2 * (edgeY - inputY) - c0 * (edgeX - inputX)) /
              (c0 * (edgeX2 - edgeX) - c2 * (edgeY2 - edgeY));
          output
            ..add(edgeX + (edgeX2 - edgeX) * ua)
            ..add(edgeY + (edgeY2 - edgeY) * ua);
        } else if (side2) {
          // v1 outside, v2 inside
          final double c0 = inputY2 - inputY, c2 = inputX2 - inputX;
          final double ua = (c2 * (edgeY - inputY) - c0 * (edgeX - inputX)) /
              (c0 * (edgeX2 - edgeX) - c2 * (edgeY2 - edgeY));
          output
            ..add(edgeX + (edgeX2 - edgeX) * ua)
            ..add(edgeY + (edgeY2 - edgeY) * ua)
            ..add(inputX2)
            ..add(inputY2);
        }
        clipped = true;
      }

      if (outputStart == output.length) {
        // All edges outside.
        originalOutput.length = 0;
        return true;
      }

      output..add(output[0])..add(output[1]);

      if (i == clippingVerticesLast) break;
      final Float32List temp = output;
      output = input..length = 0;
      input = temp;
    }

    if (originalOutput != output) {
      originalOutput.length = 0;
      final int n = output.length - 2;
      for (int i = 0; i < n; i++) originalOutput[i] = output[i];
    } else
      originalOutput.length = originalOutput.length - 2;

    return clipped;
  }

  static void makeClockwise(Float32List polygon) {
    final Float32List vertices = polygon;
    final int verticeslength = polygon.length;

    double area = vertices[verticeslength - 2] * vertices[1] -
            vertices[0] * vertices[verticeslength - 1],
        p1x = 0.0,
        p1y = 0.0,
        p2x = 0.0,
        p2y = 0.0;
    final int n = verticeslength - 3;
    for (int i = 0; i < n; i += 2) {
      p1x = vertices[i];
      p1y = vertices[i + 1];
      p2x = vertices[i + 2];
      p2y = vertices[i + 3];
      area += p1x * p2y - p2x * p1y;
    }
    if (area < 0) return;
    final int lastX = verticeslength - 2, nn = verticeslength >> 1;
    for (int i = 0; i < nn; i += 2) {
      final double x = vertices[i], y = vertices[i + 1];
      final int other = lastX - i;
      vertices[i] = vertices[other];
      vertices[i + 1] = vertices[other + 1];
      vertices[other] = x;
      vertices[other + 1] = y;
    }
  }
}
