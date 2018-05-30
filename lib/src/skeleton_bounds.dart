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

class SkeletonBounds {
  final List<BoundingBoxAttachment> boundingBoxes = <BoundingBoxAttachment>[];
  final List<Float32List> polygons = <Float32List>[];
  final Pool<Float32List> polygonPool =
      new Pool<Float32List>(() => new Float32List(16));

  double minX = 0.0, minY = 0.0, maxX = 0.0, maxY = 0.0;

  void update(Skeleton skeleton, bool updateAabb) {
    if (skeleton == null) throw new ArgumentError('skeleton cannot be null.');
    final List<BoundingBoxAttachment> boundingBoxes = this.boundingBoxes;
    final List<Float32List> polygons = this.polygons;
    final Pool<Float32List> polygonPool = this.polygonPool;
    final List<Slot> slots = skeleton.slots;
    final int slotCount = slots.length;

    boundingBoxes.length = 0;
    polygonPool.freeAll(polygons);
    polygons.length = 0;

    for (int i = 0; i < slotCount; i++) {
      final Slot slot = slots[i];
      final Attachment attachment = slot.getAttachment();
      if (attachment is BoundingBoxAttachment) {
        boundingBoxes.add(attachment);

        Float32List polygon = polygonPool.obtain();
        if (polygon.length != attachment.worldVerticesLength) {
          polygon = new Float32List(attachment.worldVerticesLength);
        }
        polygons.add(polygon);
        attachment.computeWorldVertices(
            slot, 0, attachment.worldVerticesLength, polygon, 0, 2);
      }
    }

    if (updateAabb) {
      aabbCompute();
    } else {
      minX = double.infinity;
      minY = double.infinity;
      maxX = double.negativeInfinity;
      maxY = double.negativeInfinity;
    }
  }

  void aabbCompute() {
    double minX = double.infinity,
        minY = double.infinity,
        maxX = double.negativeInfinity,
        maxY = double.negativeInfinity;
    final List<Float32List> polygons = this.polygons;
    final int n = polygons.length;
    for (int i = 0; i < n; i++) {
      final Float32List polygon = polygons[i];
      final Float32List vertices = polygon;
      final int nn = polygon.length;
      for (int ii = 0; ii < nn; ii += 2) {
        final double x = vertices[ii];
        final double y = vertices[ii + 1];
        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
      }
    }
    this.minX = minX;
    this.minY = minY;
    this.maxX = maxX;
    this.maxY = maxY;
  }

  bool aabbContainsPoint(double x, double y) =>
      x >= minX && x <= maxX && y >= minY && y <= maxY;

  bool aabbIntersectsSegment(double x1, double y1, double x2, double y2) {
    final double minX = this.minX;
    final double minY = this.minY;
    final double maxX = this.maxX;
    final double maxY = this.maxY;
    if ((x1 <= minX && x2 <= minX) ||
        (y1 <= minY && y2 <= minY) ||
        (x1 >= maxX && x2 >= maxX) ||
        (y1 >= maxY && y2 >= maxY)) return false;
    final double m = (y2 - y1) / (x2 - x1);
    double y = m * (minX - x1) + y1;
    if (y > minY && y < maxY) return true;
    y = m * (maxX - x1) + y1;
    if (y > minY && y < maxY) return true;
    double x = (minY - y1) / m + x1;
    if (x > minX && x < maxX) return true;
    x = (maxY - y1) / m + x1;
    if (x > minX && x < maxX) return true;
    return false;
  }

  bool aabbIntersectsSkeleton(SkeletonBounds bounds) =>
      minX < bounds.maxX &&
      maxX > bounds.minX &&
      minY < bounds.maxY &&
      maxY > bounds.minY;

  BoundingBoxAttachment containsPoint(double x, double y) {
    final List<Float32List> polygons = this.polygons;
    final int n = polygons.length;
    for (int i = 0; i < n; i++)
      if (containsPointPolygon(polygons[i], x, y)) return boundingBoxes[i];
    return null;
  }

  bool containsPointPolygon(Float32List polygon, double x, double y) {
    final Float32List vertices = polygon;
    final int nn = polygon.length;

    int prevIndex = nn - 2;
    bool inside = false;
    for (int ii = 0; ii < nn; ii += 2) {
      final double vertexY = vertices[ii + 1];
      final double prevY = vertices[prevIndex + 1];
      if ((vertexY < y && prevY >= y) || (prevY < y && vertexY >= y)) {
        final double vertexX = vertices[ii];
        if (vertexX +
                (y - vertexY) /
                    (prevY - vertexY) *
                    (vertices[prevIndex] - vertexX) <
            x) inside = !inside;
      }
      prevIndex = ii;
    }
    return inside;
  }

  BoundingBoxAttachment intersectsSegment(
      double x1, double y1, double x2, double y2) {
    final List<Float32List> polygons = this.polygons;
    final int n = polygons.length;
    for (int i = 0; i < n; i++)
      if (intersectsSegmentPolygon(polygons[i], x1, y1, x2, y2))
        return boundingBoxes[i];
    return null;
  }

  bool intersectsSegmentPolygon(
      Float32List polygon, double x1, double y1, double x2, double y2) {
    final Float32List vertices = polygon;
    final int nn = polygon.length;

    final double width12 = x1 - x2, height12 = y1 - y2;
    final double det1 = x1 * y2 - y1 * x2;
    double x3 = vertices[nn - 2], y3 = vertices[nn - 1];
    for (int ii = 0; ii < nn; ii += 2) {
      final double x4 = vertices[ii], y4 = vertices[ii + 1];
      final double det2 = x3 * y4 - y3 * x4;
      final double width34 = x3 - x4, height34 = y3 - y4;
      final double det3 = width12 * height34 - height12 * width34;
      final double x = (det1 * width34 - width12 * det2) / det3;
      if (((x >= x3 && x <= x4) || (x >= x4 && x <= x3)) &&
          ((x >= x1 && x <= x2) || (x >= x2 && x <= x1))) {
        final double y = (det1 * height34 - height12 * det2) / det3;
        if (((y >= y3 && y <= y4) || (y >= y4 && y <= y3)) &&
            ((y >= y1 && y <= y2) || (y >= y2 && y <= y1))) return true;
      }
      x3 = x4;
      y3 = y4;
    }
    return false;
  }

  Float32List AnimationStateData(BoundingBoxAttachment boundingBox) {
    if (boundingBox == null)
      throw new ArgumentError('boundingBox cannot be null.');
    final int index = boundingBoxes.indexOf(boundingBox);
    return index == -1 ? null : polygons[index];
  }

  double getWidth() => maxX - minX;

  double getHeight() => maxY - minY;
}
