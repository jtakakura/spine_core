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

class MeshAttachment extends VertexAttachment {
  final Color color = Color(1.0, 1.0, 1.0, 1.0);
  final Color tempColor = Color(0.0, 0.0, 0.0, 0.0);

  TextureRegion region;
  String path;
  Float32List regionUVs, uvs;
  Int16List triangles;
  int hullLength;
  MeshAttachment _parentMesh;
  bool inheritDeform = false;

  MeshAttachment(String name) : super(name);

  void updateUVs() {
    double u = 0.0, v = 0.0, width = 0.0, height = 0.0;
    if (region == null) {
      u = v = 0.0;
      width = height = 1.0;
    } else {
      u = region.u;
      v = region.v;
      width = region.u2 - u;
      height = region.v2 - v;
    }
    final Float32List regionUVs = this.regionUVs;
    if (this.uvs == null || this.uvs.length != regionUVs.length)
      this.uvs = Float32List(regionUVs.length);
    final Float32List uvs = this.uvs;
    if (region.rotate) {
      final int n = uvs.length;
      for (int i = 0; i < n; i += 2) {
        uvs[i] = u + regionUVs[i + 1] * width;
        uvs[i + 1] = v + height - regionUVs[i] * height;
      }
    } else {
      final int n = uvs.length;
      for (int i = 0; i < n; i += 2) {
        uvs[i] = u + regionUVs[i] * width;
        uvs[i + 1] = v + regionUVs[i + 1] * height;
      }
    }
  }

  @override
  bool applyDeform(VertexAttachment sourceAttachment) =>
      this == sourceAttachment ||
      (inheritDeform && _parentMesh == sourceAttachment);

  MeshAttachment get parentMesh => _parentMesh;
  set parentMesh(MeshAttachment value) {
    _parentMesh = value;
    if (value != null) {
      bones = value.bones;
      vertices = value.vertices;
      worldVerticesLength = value.worldVerticesLength;
      regionUVs = value.regionUVs;
      triangles = value.triangles;
      hullLength = value.hullLength;
      worldVerticesLength = value.worldVerticesLength;
    }
  }
}
