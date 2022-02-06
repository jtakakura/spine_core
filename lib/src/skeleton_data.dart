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

class SkeletonData {
  final List<BoneData> bones = <BoneData>[]; // Ordered parents first.
  final List<SlotData> slots = <SlotData>[]; // Setup pose draw order.
  final List<Skin> skins = <Skin>[];
  final List<EventData> events = <EventData>[];
  final List<Animation> animations = <Animation>[];
  final List<IkConstraintData?> ikConstraints = <IkConstraintData?>[];
  final List<TransformConstraintData?> transformConstraints =
      <TransformConstraintData?>[];
  final List<PathConstraintData> pathConstraints = <PathConstraintData>[];

  final String name;
  Skin? defaultSkin;
  double width = 0.0, height = 0.0;
  String version = '', hash = '';

  // Nonessential
  double fps = 0.0;
  String? imagesPath;

  SkeletonData(this.name);

  BoneData? findBone(String boneName) {
    final List<BoneData> bones = this.bones;
    final int n = bones.length;
    for (int i = 0; i < n; i++) {
      if (bones[i].name == boneName) return bones[i];
    }
    return null;
  }

  int findBoneIndex(String boneName) {
    final List<BoneData> bones = this.bones;
    final int n = bones.length;
    for (int i = 0; i < n; i++) {
      if (bones[i].name == boneName) return i;
    }
    return -1;
  }

  SlotData? findSlot(String slotName) {
    if (slotName.isEmpty) throw ArgumentError('slotName cannot be empty.');
    final List<SlotData> slots = this.slots;
    final int n = slots.length;
    for (int i = 0; i < n; i++) {
      if (slots[i].name == slotName) return slots[i];
    }
    return null;
  }

  int findSlotIndex(String slotName) {
    if (slotName.isEmpty) throw ArgumentError('slotName cannot be empty.');
    final List<SlotData> slots = this.slots;
    final int n = slots.length;
    for (int i = 0; i < n; i++) {
      if (slots[i].name == slotName) return i;
    }
    return -1;
  }

  Skin? findSkin(String skinName) {
    if (skinName.isEmpty) throw ArgumentError('skinName cannot be empty.');
    final List<Skin> skins = this.skins;
    final int n = skins.length;
    for (int i = 0; i < n; i++) {
      if (skins[i].name == skinName) return skins[i];
    }
    return null;
  }

  EventData? findEvent(String eventDataName) {
    if (eventDataName.isEmpty) {
      throw ArgumentError('eventDataName cannot be empty.');
    }
    final List<EventData> events = this.events;
    final int n = events.length;
    for (int i = 0; i < n; i++) {
      if (events[i].name == eventDataName) return events[i];
    }
    return null;
  }

  Animation? findAnimation(String animationName) {
    final List<Animation> animations = this.animations;
    final int n = animations.length;
    for (int i = 0; i < n; i++) {
      if (animations[i].name == animationName) return animations[i];
    }
    return null;
  }

  IkConstraintData? findIkConstraint(String constraintName) {
    final List<IkConstraintData?> ikConstraints = this.ikConstraints;
    final int n = ikConstraints.length;
    for (int i = 0; i < n; i++) {
      if (ikConstraints[i]!.name == constraintName) return ikConstraints[i];
    }
    return null;
  }

  TransformConstraintData? findTransformConstraint(String constraintName) {
    final List<TransformConstraintData?> transformConstraints =
        this.transformConstraints;
    final int n = transformConstraints.length;
    for (int i = 0; i < n; i++) {
      if (transformConstraints[i]!.name == constraintName) {
        return transformConstraints[i];
      }
    }
    return null;
  }

  PathConstraintData? findPathConstraint(String constraintName) {
    final List<PathConstraintData> pathConstraints = this.pathConstraints;
    final int n = pathConstraints.length;
    for (int i = 0; i < n; i++) {
      if (pathConstraints[i].name == constraintName) return pathConstraints[i];
    }
    return null;
  }

  int findPathConstraintIndex(String pathConstraintName) {
    final List<PathConstraintData> pathConstraints = this.pathConstraints;
    final int n = pathConstraints.length;
    for (int i = 0; i < n; i++) {
      if (pathConstraints[i].name == pathConstraintName) return i;
    }
    return -1;
  }
}
