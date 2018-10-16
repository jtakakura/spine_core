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

abstract class Attachment {
  final String name;

  Attachment(this.name) {
    if (name == null) throw ArgumentError('name cannot be null.');
  }
}

abstract class VertexAttachment extends Attachment {
  static int _nextID = 0;

  final int id = (_nextID++ & 65535) << 11;
  Int32List bones;
  Float32List vertices;
  int worldVerticesLength = 0;

  VertexAttachment(String name) : super(name);

  void computeWorldVertices(Slot slot, int start, int count,
      Float32List worldVertices, int offset, int stride) {
    count = offset + (count >> 1) * stride;
    final Skeleton skeleton = slot.bone.skeleton;
    final Float32List deformArray = slot.attachmentVertices;
    Float32List vertices = this.vertices;
    final Int32List bones = this.bones;
    if (bones == null) {
      if (deformArray.isNotEmpty) vertices = deformArray;
      final Bone bone = slot.bone;
      final double x = bone.worldX;
      final double y = bone.worldY;
      final double a = bone.a, b = bone.b, c = bone.c, d = bone.d;
      for (int v = start, w = offset; w < count; v += 2, w += stride) {
        final double vx = vertices[v], vy = vertices[v + 1];
        worldVertices[w] = vx * a + vy * b + x;
        worldVertices[w + 1] = vx * c + vy * d + y;
      }
      return;
    }
    int v = 0, skip = 0;
    for (int i = 0; i < start; i += 2) {
      final int n = bones[v];
      v += n + 1;
      skip += n;
    }
    final List<Bone> skeletonBones = skeleton.bones;
    if (deformArray.isEmpty) {
      for (int w = offset, b = skip * 3; w < count; w += stride) {
        double wx = 0.0, wy = 0.0;
        int n = bones[v++];
        n += v;
        for (; v < n; v++, b += 3) {
          final Bone bone = skeletonBones[bones[v]];
          final double vx = vertices[b],
              vy = vertices[b + 1],
              weight = vertices[b + 2];
          wx += (vx * bone.a + vy * bone.b + bone.worldX) * weight;
          wy += (vx * bone.c + vy * bone.d + bone.worldY) * weight;
        }
        worldVertices[w] = wx;
        worldVertices[w + 1] = wy;
      }
    } else {
      final Float32List deform = deformArray;
      for (int w = offset, b = skip * 3, f = skip << 1;
          w < count;
          w += stride) {
        double wx = 0.0, wy = 0.0;
        int n = bones[v++];
        n += v;
        for (; v < n; v++, b += 3, f += 2) {
          final Bone bone = skeletonBones[bones[v]];
          final double vx = vertices[b] + deform[f],
              vy = vertices[b + 1] + deform[f + 1],
              weight = vertices[b + 2];
          wx += (vx * bone.a + vy * bone.b + bone.worldX) * weight;
          wy += (vx * bone.c + vy * bone.d + bone.worldY) * weight;
        }
        worldVertices[w] = wx;
        worldVertices[w + 1] = wy;
      }
    }
  }

  bool applyDeform(VertexAttachment sourceAttachment) =>
      this == sourceAttachment;
}
