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

class Triangulator {
  final List<Float32List> convexPolygons = <Float32List>[];
  final List<Int16List> convexPolygonsIndices = <Int16List>[];

  final List<int> indicesArray = <int>[];
  final List<bool> isConcaveArray = <bool>[];
  final List<int> triangles = <int>[];

  final Pool<List<double>> polygonPool = Pool<List<double>>(() => <double>[]);
  final Pool<List<int>> polygonIndicesPool = Pool<List<int>>(() => <int>[]);

  Int16List triangulate(Float32List verticesArray) {
    final Float32List vertices = verticesArray;
    int vertexCount = verticesArray.length >> 1;

    final List<int> indices = indicesArray..length = 0;
    for (int i = 0; i < vertexCount; i++) indices[i] = i;

    final List<bool> isConcave = isConcaveArray..length = 0;
    final int n = vertexCount;
    for (int i = 0; i < n; ++i)
      isConcave[i] = Triangulator._isConcave(
          i, vertexCount, vertices, indices as Int16List);

    final List<int> triangles = this.triangles..length = 0;

    while (vertexCount > 3) {
      // Find ear tip.
      int previous = vertexCount - 1, i = 0, next = 1;
      for (;;) {
        outer:
        if (!isConcave[i]) {
          final int p1 = indices[previous] << 1,
              p2 = indices[i] << 1,
              p3 = indices[next] << 1;
          final double p1x = vertices[p1], p1y = vertices[p1 + 1];
          final double p2x = vertices[p2], p2y = vertices[p2 + 1];
          final double p3x = vertices[p3], p3y = vertices[p3 + 1];
          for (int ii = (next + 1) % vertexCount;
              ii != previous;
              ii = (ii + 1) % vertexCount) {
            if (!isConcave[ii]) continue;
            final int v = indices[ii] << 1;
            final double vx = vertices[v], vy = vertices[v + 1];
            if (Triangulator.positiveArea(p3x, p3y, p1x, p1y, vx, vy)) {
              if (Triangulator.positiveArea(p1x, p1y, p2x, p2y, vx, vy)) {
                if (Triangulator.positiveArea(p2x, p2y, p3x, p3y, vx, vy))
                  break outer;
              }
            }
          }
          break;
        }

        if (next == 0) {
          do {
            if (!isConcave[i]) break;
            i--;
          } while (i > 0);
          break;
        }

        previous = i;
        i = next;
        next = (next + 1) % vertexCount;
      }

      // Cut ear tip.
      triangles
        ..add(indices[(vertexCount + i - 1) % vertexCount])
        ..add(indices[i])
        ..add(indices[(i + 1) % vertexCount]);
      indices.removeAt(i);
      isConcave.removeAt(i);
      vertexCount--;

      final int previousIndex = (vertexCount + i - 1) % vertexCount;
      final int nextIndex = i == vertexCount ? 0 : i;
      isConcave[previousIndex] = Triangulator._isConcave(
          previousIndex, vertexCount, vertices, indices as Int16List);
      isConcave[nextIndex] =
          Triangulator._isConcave(nextIndex, vertexCount, vertices, indices);
    }

    if (vertexCount == 3) {
      triangles
        ..add(indices[2])
        ..add(indices[0])
        ..add(indices[1]);
    }

    return triangles as Int16List;
  }

  List<Float32List> decompose(Float32List verticesArray, Int16List triangles) {
    final Float32List vertices = verticesArray;
    final List<Float32List> convexPolygons = this.convexPolygons;
    polygonPool.freeAll(convexPolygons);
    convexPolygons.length = 0;

    final List<Int16List> convexPolygonsIndices = this.convexPolygonsIndices;
    polygonIndicesPool.freeAll(convexPolygonsIndices);
    convexPolygonsIndices.length = 0;

    List<int> polygonIndices = polygonIndicesPool.obtain()..length = 0;

    List<double> polygon = polygonPool.obtain()..length = 0;

    // Merge subsequent triangles if they form a triangle fan.
    int fanBaseIndex = -1, lastWinding = 0;
    final int n = triangles.length;
    for (int i = 0; i < n; i += 3) {
      final int t1 = triangles[i] << 1,
          t2 = triangles[i + 1] << 1,
          t3 = triangles[i + 2] << 1;
      final double x1 = vertices[t1], y1 = vertices[t1 + 1];
      final double x2 = vertices[t2], y2 = vertices[t2 + 1];
      final double x3 = vertices[t3], y3 = vertices[t3 + 1];

      // If the base of the last triangle is the same as this triangle, check if they form a convex polygon (triangle fan).
      bool merged = false;
      if (fanBaseIndex == t1) {
        final int o = polygon.length - 4;
        final int winding1 = Triangulator.winding(
            polygon[o], polygon[o + 1], polygon[o + 2], polygon[o + 3], x3, y3);
        final int winding2 = Triangulator.winding(
            x3, y3, polygon[0], polygon[1], polygon[2], polygon[3]);
        if (winding1 == lastWinding && winding2 == lastWinding) {
          polygon
            ..add(x3)
            ..add(y3);
          polygonIndices.add(t3);
          merged = true;
        }
      }

      // Otherwise make this triangle the new base.
      if (!merged) {
        if (polygon.isEmpty) {
          convexPolygons.add(polygon as Float32List);
          convexPolygonsIndices.add(polygonIndices as Int16List);
        } else {
          polygonPool.free(polygon);
          polygonIndicesPool.free(polygonIndices);
        }
        polygon = polygonPool.obtain()
          ..length = 0
          ..add(x1)
          ..add(y1)
          ..add(x2)
          ..add(y2)
          ..add(x3)
          ..add(y3);
        polygonIndices = polygonIndicesPool.obtain()
          ..length = 0
          ..add(t1)
          ..add(t2)
          ..add(t3);
        lastWinding = Triangulator.winding(x1, y1, x2, y2, x3, y3);
        fanBaseIndex = t1;
      }
    }

    if (polygon.isNotEmpty) {
      convexPolygons.add(polygon as Float32List);
      convexPolygonsIndices.add(polygonIndices as Int16List);
    }

    final int nn = convexPolygons.length;
    // Go through the list of polygons and try to merge the remaining triangles with the found triangle fans.
    for (int i = 0; i < nn; i++) {
      polygonIndices = convexPolygonsIndices[i];
      if (polygonIndices.isEmpty) continue;
      final int firstIndex = polygonIndices[0];
      final int lastIndex = polygonIndices[polygonIndices.length - 1];

      polygon = convexPolygons[i];
      final int o = polygon.length - 4;
      double prevPrevX = polygon[o], prevPrevY = polygon[o + 1];
      double prevX = polygon[o + 2], prevY = polygon[o + 3];
      final double firstX = polygon[0], firstY = polygon[1];
      final double secondX = polygon[2], secondY = polygon[3];
      final int winding = Triangulator.winding(
          prevPrevX, prevPrevY, prevX, prevY, firstX, firstY);

      for (int ii = 0; ii < n; ii++) {
        if (ii == i) continue;
        final Int16List otherIndices = convexPolygonsIndices[ii];
        if (otherIndices.length != 3) continue;
        final int otherFirstIndex = otherIndices[0];
        final int otherSecondIndex = otherIndices[1];
        final int otherLastIndex = otherIndices[2];

        final Float32List otherPoly = convexPolygons[ii];
        final double x3 = otherPoly[otherPoly.length - 2],
            y3 = otherPoly[otherPoly.length - 1];

        if (otherFirstIndex != firstIndex || otherSecondIndex != lastIndex)
          continue;
        final int winding1 =
            Triangulator.winding(prevPrevX, prevPrevY, prevX, prevY, x3, y3);
        final int winding2 =
            Triangulator.winding(x3, y3, firstX, firstY, secondX, secondY);
        if (winding1 == winding && winding2 == winding) {
          otherPoly.length = 0;
          otherIndices.length = 0;
          polygon
            ..add(x3)
            ..add(y3);
          polygonIndices.add(otherLastIndex);
          prevPrevX = prevX;
          prevPrevY = prevY;
          prevX = x3;
          prevY = y3;
          ii = 0;
        }
      }
    }

    // Remove empty polygons that resulted from the merge step above.
    for (int i = convexPolygons.length - 1; i >= 0; i--) {
      polygon = convexPolygons[i];
      if (polygon.isEmpty) {
        convexPolygons.removeAt(i);
        polygonPool.free(polygon);
        polygonIndices = convexPolygonsIndices[i];
        convexPolygonsIndices.removeAt(i);
        polygonIndicesPool.free(polygonIndices);
      }
    }

    return convexPolygons;
  }

  static bool _isConcave(
      int index, int vertexCount, Float32List vertices, Int16List indices) {
    final int previous = indices[(vertexCount + index - 1) % vertexCount] << 1;
    final int current = indices[index] << 1;
    final int next = indices[(index + 1) % vertexCount] << 1;
    return !Triangulator.positiveArea(
        vertices[previous],
        vertices[previous + 1],
        vertices[current],
        vertices[current + 1],
        vertices[next],
        vertices[next + 1]);
  }

  static bool positiveArea(double p1x, double p1y, double p2x, double p2y,
          double p3x, double p3y) =>
      p1x * (p3y - p2y) + p2x * (p1y - p3y) + p3x * (p2y - p1y) >= 0;

  static int winding(
      double p1x, double p1y, double p2x, double p2y, double p3x, double p3y) {
    final double px = p2x - p1x, py = p2y - p1y;
    return p3x * py - p3y * px + px * p1y - p1x * py >= 0 ? 1 : -1;
  }
}
