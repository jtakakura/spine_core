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

class AnimationState {
  static const int subsequent = 0;
  static const int first = 1;
  static const int dip = 2;
  static const int dipMix = 3;

  static const Animation emptyAnimation =
      Animation('<empty>', <Timeline>[], 0.0);

  List<TrackEntry?> tracks = <TrackEntry?>[];
  final List<Event?> events = <Event?>[];
  final List<TrackEntryCallback> onStartCallbacks = <TrackEntryCallback>[];
  final List<TrackEntryCallback> onInterruptCallbacks = <TrackEntryCallback>[];
  final List<TrackEntryCallback> onEndCallbacks = <TrackEntryCallback>[];
  final List<TrackEntryCallback> onDisposeCallbacks = <TrackEntryCallback>[];
  final List<TrackEntryCallback> onCompleteCallbacks = <TrackEntryCallback>[];
  final List<TrackEntryEventCallback> onEventCallbacks =
      <TrackEntryEventCallback>[];
  final List<TrackEntry> mixingTo = <TrackEntry>[];
  final Set<int> propertyIDs = <int>{};
  final Pool<TrackEntry?> trackEntryPool = Pool<TrackEntry?>(TrackEntry.new);

  final AnimationStateData data;
  late EventQueue queue;
  bool animationsChanged = false;
  double timeScale = 1.0;

  AnimationState(this.data) {
    queue = EventQueue(this);
  }

  void update(double delta) {
    delta *= timeScale;
    final List<TrackEntry?> tracks = this.tracks;

    final int n = tracks.length;
    for (int i = 0; i < n; i++) {
      final TrackEntry? current = tracks[i];
      if (current == null) continue;

      current
        ..animationLast = current.nextAnimationLast
        ..trackLast = current.nextTrackLast;

      double currentDelta = delta * current.timeScale;

      if (current.delay > 0) {
        current.delay = current.delay - currentDelta;
        if (current.delay > 0) continue;
        currentDelta = -current.delay;
        current.delay = 0.0;
      }

      TrackEntry? next = current.next;
      if (next != null) {
        // When the next entry's delay is passed, change to the next entry, preserving leftover time.
        final double nextTime = current.trackLast - next.delay;
        if (nextTime >= 0) {
          next
            ..delay = 0.0
            ..trackTime = nextTime + delta * next.timeScale;
          current.trackTime = current.trackTime + currentDelta;
          setCurrent(i, next, true);
          while (next!.mixingFrom != null) {
            next.mixTime = next.mixTime + currentDelta;
            next = next.mixingFrom;
          }
          continue;
        }
      } else if (current.trackLast >= current.trackEnd &&
          current.mixingFrom == null) {
        tracks[i] = null;
        queue.end(current);
        disposeNext(current);
        continue;
      }
      if (current.mixingFrom != null && updateMixingFrom(current, delta)) {
        // End mixing from entries once all have completed.
        TrackEntry? from = current.mixingFrom;
        current.mixingFrom = null;
        while (from != null) {
          queue.end(from);
          from = from.mixingFrom;
        }
      }

      current.trackTime = current.trackTime + currentDelta;
    }

    queue.drain();
  }

  bool updateMixingFrom(TrackEntry to, double delta) {
    final TrackEntry? from = to.mixingFrom;
    if (from == null) return true;

    final bool finished = updateMixingFrom(from, delta);

    // Require mixTime > 0 to ensure the mixing from entry was applied at least once.
    if (to.mixTime > 0 && (to.mixTime >= to.mixDuration || to.timeScale == 0)) {
      // Require totalAlpha == 0 to ensure mixing is complete, unless mixDuration == 0 (the transition is a single frame).
      if (from.totalAlpha == 0 || to.mixDuration == 0) {
        to
          ..mixingFrom = from.mixingFrom
          ..interruptAlpha = from.interruptAlpha;
        queue.end(from);
      }
      return finished;
    }

    from
      ..animationLast = from.nextAnimationLast
      ..trackLast = from.nextTrackLast
      ..trackTime = from.trackTime + delta * from.timeScale;
    to.mixTime = to.mixTime + delta * to.timeScale;
    return false;
  }

  bool apply(Skeleton skeleton) {
    if (animationsChanged) _animationsChanged();

    final List<Event?> events = this.events;
    final List<TrackEntry?> tracks = this.tracks;
    bool applied = false;

    final int n = tracks.length;
    for (int i = 0; i < n; i++) {
      final TrackEntry? current = tracks[i];
      if (current == null || current.delay > 0) continue;
      applied = true;
      final MixPose currentPose =
          i == 0 ? MixPose.Current : MixPose.CurrentLayered;

      // Apply mixing from entries first.
      double mix = current.alpha;
      if (current.mixingFrom != null)
        mix *= applyMixingFrom(current, skeleton, currentPose);
      else if (current.trackTime >= current.trackEnd && current.next == null)
        mix = 0.0;

      // Apply current entry.
      final double animationLast = current.animationLast,
          animationTime = current.getAnimationTime();
      final int timelineCount = current.animation!.timelines.length;
      final List<Timeline> timelines = current.animation!.timelines;
      if (mix == 1) {
        for (int ii = 0; ii < timelineCount; ii++)
          timelines[ii].apply(skeleton, animationLast, animationTime, events,
              1.0, MixPose.Setup, MixDirection.In);
      } else {
        final Int32List timelineData = current.timelineData as Int32List;

        final bool firstFrame = current.timelinesRotation.isEmpty;
        if (firstFrame)
          current.timelinesRotation = ArrayUtils.copyWithNewArraySize(
              current.timelinesRotation, timelineCount << 1, double.infinity);
        final Float32List timelinesRotation =
            Float32List.fromList(current.timelinesRotation);

        for (int ii = 0; ii < timelineCount; ii++) {
          final Timeline timeline = timelines[ii];
          final MixPose pose = timelineData[ii] >= AnimationState.first
              ? MixPose.Setup
              : currentPose;
          if (timeline is RotateTimeline) {
            applyRotateTimeline(timeline, skeleton, animationTime, mix, pose,
                timelinesRotation, ii << 1, firstFrame);
          } else {
            timeline.apply(skeleton, animationLast, animationTime, events, mix,
                pose, MixDirection.In);
          }
        }
      }
      queueEvents(current, animationTime);
      events.length = 0;
      current
        ..nextAnimationLast = animationTime
        ..nextTrackLast = current.trackTime;
    }

    queue.drain();
    return applied;
  }

  double applyMixingFrom(
      TrackEntry to, Skeleton skeleton, MixPose currentPose) {
    final TrackEntry from = to.mixingFrom!;
    if (from.mixingFrom != null) applyMixingFrom(from, skeleton, currentPose);

    double mix = 0.0;
    if (to.mixDuration == 0) {
      // Single frame mix to undo mixingFrom changes.
      mix = 1.0;
      currentPose = MixPose.Setup;
    } else {
      mix = to.mixTime / to.mixDuration;
      if (mix > 1) mix = 1.0;
    }

    final List<Event?> events = mix < from.eventThreshold ? this.events : <Event?>[];
    final bool attachments = mix < from.attachmentThreshold;
    final bool drawOrder = mix < from.drawOrderThreshold;
    final double animationLast = from.animationLast;
    final double animationTime = from.getAnimationTime();
    final List<Timeline> timelines = from.animation!.timelines;
    final Int32List timelineData = Int32List.fromList(from.timelineData);
    final int timelineCount = timelineData.length;
    final List<TrackEntry> timelineDipMix = from.timelineDipMix;

    final bool firstFrame = from.timelinesRotation.isEmpty;
    if (firstFrame)
      from.timelinesRotation = ArrayUtils.copyWithNewArraySize(
          from.timelinesRotation, timelineCount << 1, double.infinity);
    final Float32List timelinesRotation =
        Float32List.fromList(from.timelinesRotation);

    MixPose pose;
    final double alphaDip = from.alpha * to.interruptAlpha,
        alphaMix = alphaDip * (1 - mix);

    double alpha = 0.0;
    from.totalAlpha = 0.0;
    for (int i = 0; i < timelineCount; i++) {
      final Timeline timeline = timelines[i];
      switch (timelineData[i]) {
        case AnimationState.subsequent:
          if (!attachments && timeline is AttachmentTimeline) continue;
          if (!drawOrder && timeline is DrawOrderTimeline) continue;
          pose = currentPose;
          alpha = alphaMix;
          break;
        case AnimationState.first:
          pose = MixPose.Setup;
          alpha = alphaMix;
          break;
        case AnimationState.dip:
          pose = MixPose.Setup;
          alpha = alphaDip;
          break;
        default:
          pose = MixPose.Setup;
          alpha = alphaDip;
          final TrackEntry dipMix = timelineDipMix[i];
          alpha *= math.max(0, 1 - dipMix.mixTime / dipMix.mixDuration);
          break;
      }
      from.totalAlpha = from.totalAlpha + alpha;
      if (timeline is RotateTimeline)
        applyRotateTimeline(timeline, skeleton, animationTime, alpha, pose,
            timelinesRotation, i << 1, firstFrame);
      else {
        timeline.apply(skeleton, animationLast, animationTime, events, alpha,
            pose, MixDirection.Out);
      }
    }

    if (to.mixDuration > 0) queueEvents(from, animationTime);
    this.events.length = 0;
    from
      ..nextAnimationLast = animationTime
      ..nextTrackLast = from.trackTime;

    return mix;
  }

  void applyRotateTimeline(
      Timeline timeline,
      Skeleton skeleton,
      double time,
      double alpha,
      MixPose pose,
      List<double> timelinesRotation,
      int i,
      bool firstFrame) {
    if (firstFrame) timelinesRotation[i] = 0.0;

    if (alpha == 1) {
      timeline.apply(skeleton, 0.0, time, <Event?>[], 1.0, pose, MixDirection.In);
      return;
    }

    final RotateTimeline rotateTimeline = timeline as RotateTimeline;
    final Float32List frames = rotateTimeline.frames;
    final Bone bone = skeleton.bones[rotateTimeline.boneIndex];
    if (time < frames[0]) {
      if (pose == MixPose.Setup) bone.rotation = bone.data.rotation;
      return;
    }

    double r2 = 0.0;
    if (time >=
        frames[frames.length -
            RotateTimeline.entries]) // Time is after last frame.
      r2 = bone.data.rotation +
          frames[frames.length + RotateTimeline.prevRotation];
    else {
      // Interpolate between the previous frame and the current frame.
      final int frame =
          Animation.binarySearch(frames, time, RotateTimeline.entries);
      final double prevRotation = frames[frame + RotateTimeline.prevRotation];
      final double frameTime = frames[frame];
      final double percent = rotateTimeline.getCurvePercent(
          (frame >> 1) - 1,
          1 -
              (time - frameTime) /
                  (frames[frame + RotateTimeline.prevTime] - frameTime));

      r2 = frames[frame + RotateTimeline.rotation] - prevRotation;
      r2 -= (16384 - (16384.499999999996 - r2 / 360).toInt()) * 360;
      r2 = prevRotation + r2 * percent + bone.data.rotation;
      r2 -= (16384 - (16384.499999999996 - r2 / 360).toInt()) * 360;
    }

    // Mix between rotations using the direction of the shortest route on the first frame while detecting crosses.
    double r1 = pose == MixPose.Setup ? bone.data.rotation : bone.rotation;
    double total = 0.0, diff = r2 - r1;
    if (diff == 0) {
      total = timelinesRotation[i];
    } else {
      diff -= (16384 - (16384.499999999996 - diff / 360).toInt()) * 360;
      double lastTotal = 0.0, lastDiff = 0.0;
      if (firstFrame) {
        lastTotal = 0.0;
        lastDiff = diff;
      } else {
        lastTotal = timelinesRotation[
            i]; // Angle and direction of mix, including loops.
        lastDiff = timelinesRotation[i + 1]; // Difference between bones.
      }
      final bool current = diff > 0;
      bool dir = lastTotal >= 0;
      // Detect cross at 0 (not 180).
      if (MathUtils.signum(lastDiff) != MathUtils.signum(diff) &&
          lastDiff.abs() <= 90) {
        // A cross after a 360 rotation is a loop.
        if (lastTotal.abs() > 180)
          lastTotal += 360 * MathUtils.signum(lastTotal);
        dir = current;
      }
      total = diff +
          lastTotal -
          lastTotal % 360; // Store loops as part of lastTotal.
      if (dir != current) total += 360 * MathUtils.signum(lastTotal);
      timelinesRotation[i] = total;
    }
    timelinesRotation[i + 1] = diff;
    r1 += total * alpha;
    bone.rotation =
        r1 - (16384 - (16384.499999999996 - r1 / 360).toInt()) * 360;
  }

  void queueEvents(TrackEntry entry, double animationTime) {
    final double animationStart = entry.animationStart,
        animationEnd = entry.animationEnd;
    final double duration = animationEnd - animationStart;
    final double trackLastWrapped = entry.trackLast % duration;

    // Queue events before complete.
    final List<Event?> events = this.events;
    int i = 0;
    final int n = events.length;
    for (; i < n; i++) {
      final Event event = events[i]!;
      if (event.time < trackLastWrapped) break;
      if (event.time > animationEnd)
        continue; // Discard events outside animation start/end.
      queue.event(entry, event);
    }

    // Queue complete if completed a loop iteration or the animation.
    bool complete = false;
    if (entry.loop)
      complete = duration == 0 || trackLastWrapped > entry.trackTime % duration;
    else
      complete =
          animationTime >= animationEnd && entry.animationLast < animationEnd;
    if (complete) queue.complete(entry);

    // Queue events after complete.
    for (; i < n; i++) {
      final Event event = events[i]!;
      if (event.time < animationStart)
        continue; // Discard events outside animation start/end.
      queue.event(entry, events[i]);
    }
  }

  void clearTracks() {
    final bool oldDrainDisabled = queue.drainDisabled;
    queue.drainDisabled = true;

    final int n = tracks.length;
    for (int i = 0; i < n; i++) clearTrack(i);
    tracks.length = 0;
    queue
      ..drainDisabled = oldDrainDisabled
      ..drain();
  }

  void clearTrack(int trackIndex) {
    if (trackIndex >= tracks.length) return;
    final TrackEntry? current = tracks[trackIndex];
    if (current == null) return;

    queue.end(current);

    disposeNext(current);

    TrackEntry entry = current;
    for (;;) {
      final TrackEntry? from = entry.mixingFrom;
      if (from == null) break;
      queue.end(from);
      entry.mixingFrom = null;
      entry = from;
    }

    tracks[current.trackIndex] = null;

    queue.drain();
  }

  void setCurrent(int index, TrackEntry? current, bool interrupt) {
    final TrackEntry? from = expandToIndex(index);
    tracks[index] = current;

    if (from != null) {
      if (interrupt) queue.interrupt(from);
      current
        ?..mixingFrom = from
        ..mixTime = 0.0;

      // Store the interrupted mix percentage.
      if (from.mixingFrom != null && from.mixDuration > 0)
        current!.interruptAlpha = current.interruptAlpha * math.min(1, from.mixTime / from.mixDuration);

      // Reset rotation for mixing out, in case entry was mixed in.
      from.timelinesRotation.length = 0;
    }

    queue.start(current);
  }

  TrackEntry? setAnimation(int trackIndex, String animationName, bool loop) {
    final Animation? animation = data.skeletonData.findAnimation(animationName);
    if (animation == null)
      throw StateError('Animation not found: $animationName');
    return setAnimationWith(trackIndex, animation, loop);
  }

  TrackEntry? setAnimationWith(int trackIndex, Animation animation, bool loop) {
    bool interrupt = true;
    TrackEntry? current = expandToIndex(trackIndex);
    if (current != null) {
      if (current.nextTrackLast == -1) {
        // Don't mix from an entry that was never applied.
        tracks[trackIndex] = current.mixingFrom;
        queue
          ..interrupt(current)
          ..end(current);
        disposeNext(current);
        current = current.mixingFrom;
        interrupt = false;
      } else
        disposeNext(current);
    }
    final TrackEntry? entry = trackEntry(trackIndex, animation, loop, current);
    setCurrent(trackIndex, entry, interrupt);
    queue.drain();
    return entry;
  }

  TrackEntry addAnimation(
      int trackIndex, String animationName, bool loop, double delay) {
    final Animation? animation = data.skeletonData.findAnimation(animationName);
    if (animation == null)
      throw ArgumentError('Animation not found: $animationName');
    return addAnimationWith(trackIndex, animation, loop, delay);
  }

  TrackEntry addAnimationWith(
      int trackIndex, Animation animation, bool loop, double delay) {
    TrackEntry? last = expandToIndex(trackIndex);
    if (last != null) {
      while (last!.next != null) last = last.next;
    }

    final TrackEntry entry = trackEntry(trackIndex, animation, loop, last)!;

    if (last == null) {
      setCurrent(trackIndex, entry, true);
      queue.drain();
    } else {
      last.next = entry;
      if (delay <= 0) {
        final double duration = last.animationEnd - last.animationStart;
        if (duration != 0) {
          if (last.loop)
            delay += duration * (1 + (last.trackTime ~/ duration));
          else
            delay += duration;
          delay -= data.getMix(last.animation!, animation);
        } else
          delay = 0.0;
      }
    }

    entry.delay = delay;
    return entry;
  }

  TrackEntry? setEmptyAnimation(int trackIndex, double mixDuration) {
    final TrackEntry? entry =
        setAnimationWith(trackIndex, AnimationState.emptyAnimation, false)
          ?..mixDuration = mixDuration
          ..trackEnd = mixDuration;
    return entry;
  }

  TrackEntry addEmptyAnimation(
      int trackIndex, double mixDuration, double delay) {
    if (delay <= 0) delay -= mixDuration;
    final TrackEntry entry = addAnimationWith(
        trackIndex, AnimationState.emptyAnimation, false, delay)
      ..mixDuration = mixDuration
      ..trackEnd = mixDuration;
    return entry;
  }

  void setEmptyAnimations(double mixDuration) {
    final bool oldDrainDisabled = queue.drainDisabled;
    queue.drainDisabled = true;

    final int n = tracks.length;
    for (int i = 0; i < n; i++) {
      final TrackEntry? current = tracks[i];
      if (current != null) setEmptyAnimation(current.trackIndex, mixDuration);
    }
    queue
      ..drainDisabled = oldDrainDisabled
      ..drain();
  }

  TrackEntry? expandToIndex(int index) {
    if (index < tracks.length) return tracks[index];
    tracks = ArrayUtils.ensureArrayCapacity(
        tracks, index - tracks.length + 1, null);
    tracks.length = index + 1;
    return null;
  }

  TrackEntry? trackEntry(
      int trackIndex, Animation animation, bool loop, TrackEntry? last) {
    final TrackEntry? entry = trackEntryPool.obtain()
      ?..trackIndex = trackIndex
      ..animation = animation
      ..loop = loop
      ..eventThreshold = 0.0
      ..attachmentThreshold = 0.0
      ..drawOrderThreshold = 0.0
      ..animationStart = 0.0
      ..animationEnd = animation.duration
      ..animationLast = -1.0
      ..nextAnimationLast = -1.0
      ..delay = 0.0
      ..trackTime = 0.0
      ..trackLast = -1.0
      ..nextTrackLast = -1.0
      ..trackEnd = double.infinity
      ..timeScale = 1.0
      ..alpha = 1.0
      ..interruptAlpha = 1.0
      ..mixTime = 0.0
      ..mixDuration =
          last == null ? 0.0 : data.getMix(last.animation!, animation);
    return entry;
  }

  void disposeNext(TrackEntry entry) {
    TrackEntry? next = entry.next;
    while (next != null) {
      queue.dispose(next);
      next = next.next;
    }
    entry.next = null;
  }

  void _animationsChanged() {
    animationsChanged = false;

    final Set<int> propertyIDs = this.propertyIDs..clear();
    final List<TrackEntry> mixingTo = this.mixingTo;

    final int n = tracks.length;
    for (int i = 0; i < n; i++) {
      final TrackEntry? entry = tracks[i];
      if (entry != null) entry.setTimelineData(null, mixingTo, propertyIDs);
    }
  }

  TrackEntry? getCurrent(int trackIndex) {
    if (trackIndex >= tracks.length) return null;
    return tracks[trackIndex];
  }

  void addOnStartCallback(TrackEntryCallback callback) {
    onStartCallbacks.add(callback);
  }

  void removeOnStartCallback(TrackEntryCallback callback) {
    final int index = onStartCallbacks.indexOf(callback);
    if (index >= 0) onStartCallbacks.removeAt(index);
  }

  void clearOnStartCallbacks(TrackEntryCallback callback) =>
      onStartCallbacks.length = 0;

  void addOnInterruptCallback(TrackEntryCallback callback) {
    onInterruptCallbacks.add(callback);
  }

  void removeOnInterruptCallback(TrackEntryCallback callback) {
    final int index = onInterruptCallbacks.indexOf(callback);
    if (index >= 0) onInterruptCallbacks.removeAt(index);
  }

  void clearOnInterruptCallbacks(TrackEntryCallback callback) =>
      onInterruptCallbacks.length = 0;

  void addOnEndCallback(TrackEntryCallback callback) {
    onEndCallbacks.add(callback);
  }

  void removeOnEndCallback(TrackEntryCallback callback) {
    final int index = onEndCallbacks.indexOf(callback);
    if (index >= 0) onEndCallbacks.removeAt(index);
  }

  void clearonEndCallbacks(TrackEntryCallback callback) =>
      onEndCallbacks.length = 0;

  void addOnDisposeCallback(TrackEntryCallback callback) {
    onDisposeCallbacks.add(callback);
  }

  void removeOnDisposeCallback(TrackEntryCallback callback) {
    final int index = onDisposeCallbacks.indexOf(callback);
    if (index >= 0) onDisposeCallbacks.removeAt(index);
  }

  void clearOnDisposeCallbacks(TrackEntryCallback callback) =>
      onDisposeCallbacks.length = 0;

  void addOnCompleteCallback(TrackEntryCallback callback) {
    onCompleteCallbacks.add(callback);
  }

  void removeOnCompleteCallback(TrackEntryCallback callback) {
    final int index = onCompleteCallbacks.indexOf(callback);
    if (index >= 0) onCompleteCallbacks.removeAt(index);
  }

  void clearOnCompleteCallbacks(TrackEntryCallback callback) =>
      onCompleteCallbacks.length = 0;

  void addOnEventCallback(TrackEntryEventCallback callback) {
    onEventCallbacks.add(callback);
  }

  void removeOnEventCallback(TrackEntryEventCallback callback) {
    final int index = onEventCallbacks.indexOf(callback);
    if (index >= 0) onEventCallbacks.removeAt(index);
  }

  void clearOnEventCallbacks(TrackEntryEventCallback callback) =>
      onEventCallbacks.length = 0;

  void clearListenerNotifications() {
    queue.clear();
  }
}

class TrackEntry implements Poolable {
  final List<TrackEntry> timelineDipMix = <TrackEntry>[];
  final List<int> timelineData = <int>[];
  List<double> timelinesRotation = <double>[];

  Animation? animation;
  TrackEntry? next, mixingFrom;
  TrackEntryCallback? onStartCallback;
  TrackEntryCallback? onInterruptCallback;
  TrackEntryCallback? onEndCallback;
  TrackEntryCallback? onDisposeCallback;
  TrackEntryCallback? onCompleteCallback;
  TrackEntryEventCallback? onEventCallback;
  late int trackIndex;
  late bool loop;
  late double eventThreshold, attachmentThreshold, drawOrderThreshold;
  late double animationStart, animationEnd, animationLast, nextAnimationLast;
  late double delay, trackTime, trackLast, nextTrackLast, trackEnd, timeScale;
  late double alpha, mixTime, mixDuration, interruptAlpha, totalAlpha;

  @override
  void reset() {
    next = null;
    mixingFrom = null;
    animation = null;
    onStartCallback = null;
    onInterruptCallback = null;
    onEndCallback = null;
    onDisposeCallback = null;
    onCompleteCallback = null;
    onEventCallback = null;
    timelineData.length = 0;
    timelineDipMix.length = 0;
    timelinesRotation.length = 0;
  }

  TrackEntry setTimelineData(
      TrackEntry? to, List<TrackEntry> mixingToArray, Set<int> propertyIDs) {
    if (to != null) mixingToArray.add(to);
    final TrackEntry lastEntry = mixingFrom != null
        ? mixingFrom!.setTimelineData(this, mixingToArray, propertyIDs)
        : this;
    if (to != null) mixingToArray.removeLast();

    final List<TrackEntry> mixingTo = mixingToArray;
    final int mixingToLast = mixingToArray.length - 1;
    final List<Timeline> timelines = animation!.timelines;
    final int timelinesCount = animation!.timelines.length;
    final Int32List timelineData = Int32List.fromList(
        ArrayUtils.copyWithNewArraySize(this.timelineData, timelinesCount, -1));
    this.timelineDipMix.length = 0;
    final List<TrackEntry?> timelineDipMix = ArrayUtils.copyWithNewArraySize(
        this.timelineDipMix, timelinesCount, null);

    outer:
    for (int i = 0; i < timelinesCount; i++) {
      final int id = timelines[i].getPropertyId();
      if (!propertyIDs.add(id))
        timelineData[i] = AnimationState.subsequent;
      else if (to == null || !to.hasTimeline(id))
        timelineData[i] = AnimationState.first;
      else {
        for (int ii = mixingToLast; ii >= 0; ii--) {
          final TrackEntry entry = mixingTo[ii];
          if (!entry.hasTimeline(id)) {
            if (entry.mixDuration > 0) {
              timelineData[i] = AnimationState.dipMix;
              timelineDipMix[i] = entry;
              continue outer;
            }
          }
        }
        timelineData[i] = AnimationState.dip;
      }
    }
    return lastEntry;
  }

  bool hasTimeline(int id) {
    final List<Timeline> timelines = animation!.timelines;
    final int n = timelines.length;
    for (int i = 0; i < n; i++)
      if (timelines[i].getPropertyId() == id) return true;
    return false;
  }

  double getAnimationTime() {
    if (loop) {
      final double duration = animationEnd - animationStart;
      if (duration == 0) return animationStart;
      return (trackTime % duration) + animationStart;
    }
    return math.min(trackTime + animationStart, animationEnd);
  }

  void setAnimationLast(double animationLast) {
    this.animationLast = animationLast;
    nextAnimationLast = animationLast;
  }

  bool isComplete() => trackTime >= animationEnd - animationStart;

  void resetRotationDirections() {
    timelinesRotation.length = 0;
  }
}

class EventQueue {
  final List<dynamic> objects = <dynamic>[];
  bool drainDisabled = false;
  AnimationState animState;

  EventQueue(this.animState);

  void start(TrackEntry? entry) {
    objects..add(EventType.Start)..add(entry);
    animState.animationsChanged = true;
  }

  void interrupt(TrackEntry entry) {
    objects..add(EventType.Interrupt)..add(entry);
  }

  void end(TrackEntry entry) {
    objects..add(EventType.End)..add(entry);
    animState.animationsChanged = true;
  }

  void dispose(TrackEntry entry) {
    objects..add(EventType.Dispose)..add(entry);
  }

  void complete(TrackEntry entry) {
    objects..add(EventType.Complete)..add(entry);
  }

  void event(TrackEntry entry, Event? event) {
    objects..add(EventType.Event)..add(entry)..add(event);
  }

  void drain() {
    if (drainDisabled) return;
    drainDisabled = true;

    final List<dynamic> objects = this.objects;
    final List<TrackEntryCallback> onStartCallbacks =
        animState.onStartCallbacks;
    final List<TrackEntryCallback> onInterruptCallbacks =
        animState.onInterruptCallbacks;
    final List<TrackEntryCallback> onEndCallbacks = animState.onEndCallbacks;
    final List<TrackEntryCallback> onDisposeCallbacks =
        animState.onDisposeCallbacks;
    final List<TrackEntryCallback> onCompleteCallbacks =
        animState.onCompleteCallbacks;
    final List<TrackEntryEventCallback> onEventCallbacks =
        animState.onEventCallbacks;

    for (int i = 0; i < objects.length; i += 2) {
      final EventType? type = objects[i] as EventType?;
      final TrackEntry? entry = objects[i + 1] as TrackEntry?;
      switch (type) {
        case null:
        case EventType.Start:
          if (entry!.onStartCallback != null) entry.onStartCallback!(entry);
          onStartCallbacks
              .forEach((TrackEntryCallback callback) => callback(entry));
          break;
        case EventType.Interrupt:
          if (entry!.onInterruptCallback != null)
            entry.onInterruptCallback!(entry);
          onInterruptCallbacks
              .forEach((TrackEntryCallback callback) => callback(entry));
          break;
        case EventType.End:
        case EventType.Dispose:
          if (type == EventType.End) {
            if (entry!.onEndCallback != null) entry.onEndCallback!(entry);
            onEndCallbacks
                .forEach((TrackEntryCallback callback) => callback(entry));
          }
          if (entry!.onDisposeCallback != null) entry.onDisposeCallback!(entry);
          onDisposeCallbacks
              .forEach((TrackEntryCallback callback) => callback(entry));
          animState.trackEntryPool.free(entry);
          break;
        case EventType.Complete:
          if (entry!.onCompleteCallback != null) entry.onCompleteCallback!(entry);
          onCompleteCallbacks
              .forEach((TrackEntryCallback callback) => callback(entry));
          break;
        case EventType.Event:
          final Event? event = objects[i++ + 2] as Event?;

          if (entry!.onEventCallback != null)
            entry.onEventCallback!(entry, event);
          onEventCallbacks.forEach(
              (TrackEntryEventCallback callback) => callback(entry, event));
          break;
      }
    }
    clear();

    drainDisabled = false;
  }

  void clear() {
    objects.length = 0;
  }
}

enum EventType { Start, Interrupt, End, Dispose, Complete, Event }

typedef void TrackEntryCallback(TrackEntry? entry);
typedef void TrackEntryEventCallback(TrackEntry? entry, Event? event);
