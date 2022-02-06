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

abstract class Texture {
  dynamic image;

  Texture(this.image);

  void setFilters(TextureFilter minFilter, TextureFilter magFilter);
  void setWraps(TextureWrap uWrap, TextureWrap vWrap);
  void dispose();

  static TextureFilter filterFromString(String text) {
    switch (text.toLowerCase()) {
      case 'nearest':
        return TextureFilter.nearest;
      case 'linear':
        return TextureFilter.linear;
      case 'mipmap':
        return TextureFilter.mipMap;
      case 'mipmapnearestnearest':
        return TextureFilter.mipMapNearestNearest;
      case 'mipmaplinearnearest':
        return TextureFilter.mipMapLinearNearest;
      case 'mipmapnearestlinear':
        return TextureFilter.mipMapNearestLinear;
      case 'mipmaplinearlinear':
        return TextureFilter.mipMapLinearLinear;
      default:
        throw ArgumentError('Unknown texture filter $text');
    }
  }

  static TextureWrap wrapFromString(String text) {
    switch (text.toLowerCase()) {
      case 'mirroredtepeat':
        return TextureWrap.mirroredRepeat;
      case 'clamptoedge':
        return TextureWrap.clampToEdge;
      case 'repeat':
        return TextureWrap.repeat;
      default:
        throw ArgumentError('Unknown texture wrap $text');
    }
  }
}

class TextureFilter extends Enum<int> {
  const TextureFilter(int value) : super(value);

  static const TextureFilter nearest = TextureFilter(9728);
  static const TextureFilter linear = TextureFilter(9729);
  static const TextureFilter mipMap = TextureFilter(9987);
  static const TextureFilter mipMapNearestNearest = TextureFilter(9984);
  static const TextureFilter mipMapLinearNearest = TextureFilter(9985);
  static const TextureFilter mipMapNearestLinear = TextureFilter(9986);
  static const TextureFilter mipMapLinearLinear = TextureFilter(9987);
}

class TextureWrap extends Enum<int> {
  const TextureWrap(int value) : super(value);

  static const TextureWrap mirroredRepeat = TextureWrap(33648);
  static const TextureWrap clampToEdge = TextureWrap(33071);
  static const TextureWrap repeat = TextureWrap(10497);
}

class TextureRegion {
  dynamic renderObject;
  double u = 0.0, v = 0.0;
  double u2 = 0.0, v2 = 0.0;
  int width = 0, height = 0;
  bool rotate = false;
  int offsetX = 0, offsetY = 0;
  int originalWidth = 0, originalHeight = 0;
}

class FakeTexture extends Texture {
  FakeTexture([dynamic image]) : super(image);
  @override
  void setFilters(TextureFilter minFilter, TextureFilter magFilter) {}
  @override
  void setWraps(TextureWrap uWrap, TextureWrap vWrap) {}
  @override
  void dispose() {}
}
