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

typedef Texture TextureLoader(String path);

class TextureAtlas implements Disposable {
  List<TextureAtlasPage> pages = <TextureAtlasPage>[];
  List<TextureAtlasRegion> regions = <TextureAtlasRegion>[];

  TextureAtlas(String atlasText, TextureLoader textureLoader) {
    _load(atlasText, textureLoader);
  }

  void _load(String atlasText, TextureLoader textureLoader) {
    if (textureLoader == null)
      throw ArgumentError('textureLoader cannot be null.');

    final TextureAtlasReader reader = TextureAtlasReader(atlasText);
    final List<String> tuple = <String>[];
    TextureAtlasPage page;
    for (;;) {
      String line = reader.readLine();
      if (line == null) break;
      line = line.trim();
      if (line.isEmpty)
        page = null;
      else if (page == null) {
        page = TextureAtlasPage()..name = line;

        if (reader.readTuple(tuple) == 2) {
          // size is only optional for an atlas packed with an old TexturePacker.
          page
            ..width = int.parse(tuple[0])
            ..height = int.parse(tuple[1]);
          reader.readTuple(tuple);
        }
        reader.readTuple(tuple);
        page
          ..minFilter = Texture.filterFromString(tuple[0])
          ..magFilter = Texture.filterFromString(tuple[1]);

        final String direction = reader.readValue();
        page
          ..uWrap = TextureWrap.ClampToEdge
          ..vWrap = TextureWrap.ClampToEdge;
        if (direction == 'x')
          page.uWrap = TextureWrap.Repeat;
        else if (direction == 'y')
          page.vWrap = TextureWrap.Repeat;
        else if (direction == 'xy')
          page.uWrap = page.vWrap = TextureWrap.Repeat;

        page
          ..texture = textureLoader(line)
          ..texture.setFilters(page.minFilter, page.magFilter)
          ..texture.setWraps(page.uWrap, page.vWrap)
          ..width = page.texture.image.width
          ..height = page.texture.image.height;
        pages.add(page);
      } else {
        final TextureAtlasRegion region = TextureAtlasRegion()
          ..name = line
          ..page = page
          ..rotate = reader.readValue() == 'true';

        reader.readTuple(tuple);
        final int x = int.parse(tuple[0]);
        final int y = int.parse(tuple[1]);

        reader.readTuple(tuple);
        final int width = int.parse(tuple[0]);
        final int height = int.parse(tuple[1]);

        region
          ..u = x / page.width
          ..v = y / page.height;
        if (region.rotate) {
          region
            ..u2 = (x + height) / page.width
            ..v2 = (y + width) / page.height;
        } else {
          region
            ..u2 = (x + width) / page.width
            ..v2 = (y + height) / page.height;
        }
        region
          ..x = x
          ..y = y
          ..width = width.abs()
          ..height = height.abs();

        if (reader.readTuple(tuple) == 4) {
          if (reader.readTuple(tuple) == 4) {
            reader.readTuple(tuple);
          }
        }

        region
          ..originalWidth = int.parse(tuple[0])
          ..originalHeight = int.parse(tuple[1]);

        reader.readTuple(tuple);
        region
          ..offsetX = int.parse(tuple[0])
          ..offsetY = int.parse(tuple[1])
          ..index = int.parse(reader.readValue())
          ..texture = page.texture;

        regions.add(region);
      }
    }
  }

  TextureAtlasRegion findRegion(String name) {
    for (int i = 0; i < regions.length; i++) {
      if (regions[i].name == name) {
        return regions[i];
      }
    }
    return null;
  }

  @override
  void dispose() {
    for (int i = 0; i < pages.length; i++) {
      pages[i].texture.dispose();
    }
  }
}

class TextureAtlasReader {
  List<String> lines;
  int index = 0;

  TextureAtlasReader(String text) {
    lines = text.split(RegExp(r'\r\n|\r|\n'));
  }

  String readLine() {
    if (index >= lines.length) return null;
    return lines[index++];
  }

  String readValue() {
    final String line = readLine();
    final int colon = line.indexOf(':');
    if (colon == -1) throw StateError('Invalid line: $line');
    return line.substring(colon + 1).trim();
  }

  int readTuple(List<String> tuple) {
    final String line = readLine();
    final int colon = line.indexOf(':');
    if (colon == -1) throw StateError('Invalid line: $line');
    int i = 0, lastMatch = colon + 1;
    for (; i < 3; i++) {
      final int comma = line.indexOf(',', lastMatch);
      if (comma == -1) break;
      //  tuple[i] = line.substring(lastMatch, comma).trim();
      ArrayUtils.setArrayValue(
          tuple, i, line.substring(lastMatch, comma).trim());
      lastMatch = comma + 1;
    }
    ArrayUtils.setArrayValue(tuple, i, line.substring(lastMatch).trim());
    // tuple[i] = line.substring(lastMatch).trim();
    return i + 1;
  }
}

class TextureAtlasPage {
  String name;
  TextureFilter minFilter;
  TextureFilter magFilter;
  TextureWrap uWrap;
  TextureWrap vWrap;
  Texture texture;
  int width;
  int height;
}

class TextureAtlasRegion extends TextureRegion {
  TextureAtlasPage page;
  String name;
  int x;
  int y;
  int index;
  Texture texture;
}
