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

abstract class Disposable {
  void dispose();
}

abstract class Poolable {
  void reset();
}

abstract class Restorable {
  void restore();
}

abstract class Enum<T> {
  final T _value;

  const Enum(this._value);

  T get value => _value;
}

class Color {
  static final Color WHITE = Color(1.0, 1.0, 1.0, 1.0);
  static final Color RED = Color(1.0, 0.0, 0.0, 1.0);
  static final Color GREEN = Color(0.0, 1.0, 0.0, 1.0);
  static final Color BLUE = Color(0.0, 0.0, 1.0, 1.0);
  static final Color MAGENTA = Color(1.0, 0.0, 1.0, 1.0);

  double r, g, b, a;

  Color([this.r = 0.0, this.g = 0.0, this.b = 0.0, this.a = 0.0]);

  void set(double r, double g, double b, double a) {
    this.r = r;
    this.g = g;
    this.b = b;
    this.a = a;
    clamp();
  }

  void setFromColor(Color c) {
    r = c.r;
    g = c.g;
    b = c.b;
    a = c.a;
  }

  void setFromString(String hex) {
    hex = hex[0] == '#' ? hex.substring(1) : hex;
    r = int.parse(hex.substring(0, 2), radix: 16) / 255.0;
    g = int.parse(hex.substring(2, 4), radix: 16) / 255.0;
    b = int.parse(hex.substring(4, 6), radix: 16) / 255.0;
    a = (hex.length != 8 ? 255 : int.parse(hex.substring(6, 8), radix: 16)) /
        255.0;
  }

  void add(double r, double g, double b, double a) {
    this.r += r;
    this.g += g;
    this.b += b;
    this.a += a;
    clamp();
  }

  void clamp() {
    if (r < 0.0)
      r = 0.0;
    else if (r > 1) r = 1.0;

    if (g < 0.0)
      g = 0.0;
    else if (g > 1) g = 1.0;

    if (b < 0.0)
      b = 0.0;
    else if (b > 1) b = 1.0;

    if (a < 0.0)
      a = 0.0;
    else if (a > 1) a = 1.0;
  }
}

class MathUtils {
  static double radiansToDegrees = 180 / math.pi;
  static double radDeg = MathUtils.radiansToDegrees;
  static double degreesToRadians = math.pi / 180;
  static double degRad = MathUtils.degreesToRadians;

  static double clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static double cosDeg(double degrees) => math.cos(degrees * MathUtils.degRad);

  static double sinDeg(double degrees) => math.sin(degrees * MathUtils.degRad);

  static double signum(double value) =>
      value > 0 ? 1.0 : value < 0 ? -1.0 : 0.0;

  static int toInt(double x) => x > 0 ? x.floor() : x.ceil();

  static double cbrt(double x) {
    final double y = math.pow(x.abs(), 1 / 3);
    return x < 0 ? -y : y;
  }

  static double randomTriangular(double min, double max) =>
      MathUtils.randomTriangularWith(min, max, (min + max) * 0.5);

  static double randomTriangularWith(double min, double max, double mode) {
    final double u = (math.Random()).nextDouble();
    final double d = max - min;
    if (u <= (mode - min) / d) return min + math.sqrt(u * d * (mode - min));
    return max - math.sqrt((1 - u) * d * (max - mode));
  }
}

abstract class Interpolation {
  double applyInternal(double a);
  double apply(double start, double end, double a) =>
      start + (end - start) * applyInternal(a);
}

class Pow extends Interpolation {
  double power = 2.0;

  Pow(this.power);

  @override
  double applyInternal(double a) {
    if (a <= 0.5) return math.pow(a * 2, power) / 2;
    return math.pow((a - 1) * 2, power) / (power % 2 == 0 ? -2 : 2) + 1;
  }
}

class PowOut extends Pow {
  PowOut(double power) : super(power);

  @override
  double applyInternal(double a) =>
      math.pow(a - 1, power) * (power % 2 == 0 ? -1 : 1) + 1;
}

class ArrayUtils {
  static void arrayCopy<T>(List<T> source, int sourceStart, List<T> dest,
      int destStart, int numElements) {
    for (int i = sourceStart, j = destStart;
        i < sourceStart + numElements;
        i++, j++) {
      setArrayValue(dest, j, source[i]);
    }
  }

  static void setArrayValue<T>(List<T> array, int index, T value) {
    if (index + 1 > array.length) {
      array.length = index + 1;
    }
    array[index] = value;
  }

  static List<T> setArraySize<T>(List<T> array, int size, T value) {
    final int oldSize = array.length;
    if (oldSize == size) return array;
    array.length = size;
    if (oldSize < size && value != null) {
      for (int i = oldSize; i < size; i++) setArrayValue(array, i, value);
    }
    return array;
  }

  static List<T> ensureArrayCapacity<T>(List<T> array, int size, T value) {
    if (array.length >= size) return array;
    return ArrayUtils.setArraySize(array, size, value);
  }
}

typedef T Instantiator<T>();

class Pool<T> {
  final List<T> items = <T>[];
  final Instantiator<T> instantiator;

  Pool(this.instantiator);

  T obtain() => items.isNotEmpty ? items.removeLast() : instantiator();

  void free(T item) {
    if (item is Poolable) item.reset();
    items.add(item);
  }

  void freeAll(List<T> items) {
    for (int i = 0; i < items.length; i++) {
      final T item = items[i];
      if (item is Poolable) item.reset();
      items[i] = item;
    }
  }

  void clear() {
    items.length = 0;
  }
}

class Vector2 {
  double x, y;

  Vector2([this.x = 0.0, this.y = 0.0]);

  void set(double x, double y) {
    this.x = x;
    this.y = y;
  }

  double length() {
    final double x = this.x;
    final double y = this.y;
    return math.sqrt(x * x + y * y);
  }

  void normalize() {
    final double len = length();
    if (len != 0) {
      x /= len;
      y /= len;
    }
  }
}

class Bounds {
  final Vector2 offset;
  final Vector2 size;

  Bounds(this.offset, this.size);
}

class TimeKeeper {
  static const double maxDelta = 0.064;
  double framesPerSecond = 0.0;
  double delta = 0.0;
  double totalTime = 0.0;

  double _lastTime = DateTime.now().millisecond / 1000;
  int _frameCount = 0;
  double _frameTime = 0.0;

  void update() {
    final double now = DateTime.now().millisecond / 1000;
    delta = now - _lastTime;
    _frameTime += delta;
    totalTime += delta;
    if (delta > maxDelta) delta = maxDelta;
    _lastTime = now;

    _frameCount++;
    if (_frameTime > 1) {
      framesPerSecond = _frameCount / _frameTime;
      _frameTime = 0.0;
      _frameCount = 0;
    }
  }
}
