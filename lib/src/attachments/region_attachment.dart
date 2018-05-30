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

class RegionAttachment extends VertexAttachment {
  static const int ox1 = 0;
  static const int oy1 = 1;
  static const int ox2 = 2;
  static const int oy2 = 3;
  static const int ox3 = 4;
  static const int oy3 = 5;
  static const int ox4 = 6;
  static const int oy4 = 7;

  static const int x1 = 0;
  static const int y1 = 1;
  static const int c1r = 2;
  static const int c1g = 3;
  static const int c1b = 4;
  static const int c1a = 5;
  static const int u1 = 6;
  static const int v1 = 7;

  static const int x2 = 8;
  static const int y2 = 9;
  static const int c2r = 10;
  static const int c2g = 11;
  static const int c2b = 12;
  static const int c2a = 13;
  static const int u2 = 14;
  static const int v2 = 15;

  static const int x3 = 16;
  static const int y3 = 17;
  static const int c3r = 18;
  static const int c3g = 19;
  static const int c3b = 20;
  static const int c3a = 21;
  static const int u3 = 22;
  static const int v3 = 23;

  static const int x4 = 24;
  static const int y4 = 25;
  static const int c4r = 26;
  static const int c4g = 27;
  static const int c4b = 28;
  static const int c4a = 29;
  static const int u4 = 30;
  static const int v4 = 31;

  final Color color = new Color(1.0, 1.0, 1.0, 1.0);
  final Color tempColor = new Color(1.0, 1.0, 1.0, 1.0);

  final Float32List offset = new Float32List(8);
  final Float32List uvs = new Float32List(8);

  double x = 0.0,
      y = 0.0,
      scaleX = 1.0,
      scaleY = 1.0,
      rotation = 0.0,
      width = 0.0,
      height = 0.0;
  String path;
  dynamic rendererObject;
  TextureRegion region;

  RegionAttachment(String name) : super(name);

  void updateOffset() {
    final double regionScaleX = width / region.originalWidth * scaleX;
    final double regionScaleY = height / region.originalHeight * scaleY;
    final double localX = -width / 2 * scaleX + region.offsetX * regionScaleX;
    final double localY = -height / 2 * scaleY + region.offsetY * regionScaleY;
    final double localX2 = localX + region.width * regionScaleX;
    final double localY2 = localY + region.height * regionScaleY;
    final double radians = rotation * math.pi / 180;
    final double cos = math.cos(radians);
    final double sin = math.sin(radians);
    final double localXCos = localX * cos + x;
    final double localXSin = localX * sin;
    final double localYCos = localY * cos + y;
    final double localYSin = localY * sin;
    final double localX2Cos = localX2 * cos + x;
    final double localX2Sin = localX2 * sin;
    final double localY2Cos = localY2 * cos + y;
    final double localY2Sin = localY2 * sin;
    final Float32List offset = this.offset;
    offset[RegionAttachment.ox1] = localXCos - localYSin;
    offset[RegionAttachment.oy1] = localYCos + localXSin;
    offset[RegionAttachment.ox2] = localXCos - localY2Sin;
    offset[RegionAttachment.oy2] = localY2Cos + localXSin;
    offset[RegionAttachment.ox3] = localX2Cos - localY2Sin;
    offset[RegionAttachment.oy3] = localY2Cos + localX2Sin;
    offset[RegionAttachment.ox4] = localX2Cos - localYSin;
    offset[RegionAttachment.oy4] = localYCos + localX2Sin;
  }

  void setRegion(TextureRegion region) {
    this.region = region;
    final Float32List uvs = this.uvs;
    if (region.rotate) {
      uvs[2] = region.u;
      uvs[3] = region.v2;
      uvs[4] = region.u;
      uvs[5] = region.v;
      uvs[6] = region.u2;
      uvs[7] = region.v;
      uvs[0] = region.u2;
      uvs[1] = region.v2;
    } else {
      uvs[0] = region.u;
      uvs[1] = region.v2;
      uvs[2] = region.u;
      uvs[3] = region.v;
      uvs[4] = region.u2;
      uvs[5] = region.v;
      uvs[6] = region.u2;
      uvs[7] = region.v2;
    }
  }

  void computeWorldVertices2(
      Bone bone, Float32List worldVertices, int offset, int stride) {
    final Float32List vertexOffset = this.offset;
    final double x = bone.worldX, y = bone.worldY;
    final double a = bone.a, b = bone.b, c = bone.c, d = bone.d;
    double offsetX = 0.0, offsetY = 0.0;

    offsetX = vertexOffset[RegionAttachment.ox1];
    offsetY = vertexOffset[RegionAttachment.oy1];
    worldVertices[offset] = offsetX * a + offsetY * b + x; // br
    worldVertices[offset + 1] = offsetX * c + offsetY * d + y;
    offset += stride;

    offsetX = vertexOffset[RegionAttachment.ox2];
    offsetY = vertexOffset[RegionAttachment.oy2];
    worldVertices[offset] = offsetX * a + offsetY * b + x; // bl
    worldVertices[offset + 1] = offsetX * c + offsetY * d + y;
    offset += stride;

    offsetX = vertexOffset[RegionAttachment.ox3];
    offsetY = vertexOffset[RegionAttachment.oy3];
    worldVertices[offset] = offsetX * a + offsetY * b + x; // ul
    worldVertices[offset + 1] = offsetX * c + offsetY * d + y;
    offset += stride;

    offsetX = vertexOffset[RegionAttachment.ox4];
    offsetY = vertexOffset[RegionAttachment.oy4];
    worldVertices[offset] = offsetX * a + offsetY * b + x; // ur
    worldVertices[offset + 1] = offsetX * c + offsetY * d + y;
  }
}
