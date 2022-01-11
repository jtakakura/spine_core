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

class Skeleton {
  final SkeletonData data;
  final List<Bone> bones = <Bone>[];
  final List<Slot> slots = <Slot>[];
  List<Slot> drawOrder = <Slot>[];
  final List<IkConstraint> ikConstraints = <IkConstraint>[];
  final List<TransformConstraint> transformConstraints =
      <TransformConstraint>[];
  final List<PathConstraint> pathConstraints = <PathConstraint>[];
  final List<Updatable> _updateCache = <Updatable>[];
  final List<Updatable?> _updateCacheReset = <Updatable?>[];
  Skin? skin;
  Color color = Color(1.0, 1.0, 1.0, 1.0);
  double time = 0.0;
  bool flipX = false, flipY = false;
  double x = 0.0, y = 0.0;

  Skeleton(this.data) {
    for (int i = 0; i < data.bones.length; i++) {
      final BoneData boneData = data.bones[i];
      Bone bone;
      if (boneData.parent == null)
        bone = Bone(boneData, this, null);
      else {
        final Bone parent = bones[boneData.parent!.index];
        bone = Bone(boneData, this, parent);
        parent.children.add(bone);
      }
      bones.add(bone);
    }

    for (int i = 0; i < data.slots.length; i++) {
      final SlotData slotData = data.slots[i];
      final Bone bone = bones[slotData.boneData.index];
      final Slot slot = Slot(slotData, bone);
      slots.add(slot);
      drawOrder.add(slot);
    }

    for (int i = 0; i < data.ikConstraints.length; i++) {
      final IkConstraintData? ikConstraintData = data.ikConstraints[i];
      if (ikConstraintData != null) {
        ikConstraints.add(IkConstraint(ikConstraintData, this));
      }
    }

    for (int i = 0; i < data.transformConstraints.length; i++) {
      final TransformConstraintData? transformConstraintData =
          data.transformConstraints[i];
      if (transformConstraintData != null) {
        transformConstraints
            .add(TransformConstraint(transformConstraintData, this));
      }
    }

    for (int i = 0; i < data.pathConstraints.length; i++) {
      final PathConstraintData pathConstraintData = data.pathConstraints[i];
      pathConstraints.add(PathConstraint(pathConstraintData, this));
    }

    color = Color(1.0, 1.0, 1.0, 1.0);
    updateCache();
  }

  factory Skeleton.empty() => Skeleton(SkeletonData(''));

  void updateCache() {
    _updateCache.length = 0;
    _updateCacheReset.length = 0;

    final List<Bone> bones = this.bones;
    final int n = bones.length;
    for (int i = 0; i < n; i++) bones[i].sorted = false;

    // IK first, lowest hierarchy depth first.
    final List<IkConstraint> ikConstraints = this.ikConstraints;
    final List<TransformConstraint> transformConstraints =
        this.transformConstraints;
    final List<PathConstraint> pathConstraints = this.pathConstraints;
    final int ikCount = ikConstraints.length,
        transformCount = transformConstraints.length,
        pathCount = pathConstraints.length;
    final int constraintCount = ikCount + transformCount + pathCount;

    outer:
    for (int i = 0; i < constraintCount; i++) {
      for (int ii = 0; ii < ikCount; ii++) {
        final IkConstraint constraint = ikConstraints[ii];
        if (constraint.data.order == i) {
          sortIkConstraint(constraint);
          continue outer;
        }
      }
      for (int ii = 0; ii < transformCount; ii++) {
        final TransformConstraint constraint = transformConstraints[ii];
        if (constraint.data.order == i) {
          sortTransformConstraint(constraint);
          continue outer;
        }
      }
      for (int ii = 0; ii < pathCount; ii++) {
        final PathConstraint constraint = pathConstraints[ii];
        if (constraint.data.order == i) {
          sortPathConstraint(constraint);
          continue outer;
        }
      }
    }

    final int nn = bones.length;
    for (int i = 0; i < nn; i++) sortBone(bones[i]);
  }

  void sortIkConstraint(IkConstraint constraint) {
    final Bone target = constraint.target!;
    sortBone(target);

    final List<Bone> constrained = constraint.bones;
    final Bone parent = constrained[0];
    sortBone(parent);

    if (constrained.length > 1) {
      final Bone child = constrained[constrained.length - 1];
      if (!_updateCache.contains(child)) _updateCacheReset.add(child);
    }

    _updateCache.add(constraint);

    sortReset(parent.children);
    constrained[constrained.length - 1].sorted = true;
  }

  void sortPathConstraint(PathConstraint constraint) {
    final Slot slot = constraint.target!;
    final int slotIndex = slot.data.index;
    final Bone slotBone = slot.bone;
    if (skin != null) sortPathConstraintAttachment(skin!, slotIndex, slotBone);
    if (data.defaultSkin != null && data.defaultSkin != skin)
      sortPathConstraintAttachment(data.defaultSkin!, slotIndex, slotBone);
    final int n = data.skins.length;
    for (int i = 0; i < n; i++)
      sortPathConstraintAttachment(data.skins[i], slotIndex, slotBone);

    final Attachment? attachment = slot.getAttachment();
    if (attachment is PathAttachment)
      sortPathConstraintAttachmentWith(attachment, slotBone);

    final List<Bone> constrained = constraint.bones;
    final int boneCount = constrained.length;
    for (int i = 0; i < boneCount; i++) sortBone(constrained[i]);

    _updateCache.add(constraint);

    for (int i = 0; i < boneCount; i++) sortReset(constrained[i].children);
    for (int i = 0; i < boneCount; i++) constrained[i].sorted = true;
  }

  void sortTransformConstraint(TransformConstraint constraint) {
    sortBone(constraint.target!);

    final List<Bone> constrained = constraint.bones;
    final int boneCount = constrained.length;
    if (constraint.data.local) {
      for (int i = 0; i < boneCount; i++) {
        final Bone child = constrained[i];
        sortBone(child.parent!);
        if (!_updateCache.contains(child)) _updateCacheReset.add(child);
      }
    } else {
      for (int i = 0; i < boneCount; i++) {
        sortBone(constrained[i]);
      }
    }

    _updateCache.add(constraint);

    for (int ii = 0; ii < boneCount; ii++) sortReset(constrained[ii].children);
    for (int ii = 0; ii < boneCount; ii++) constrained[ii].sorted = true;
  }

  void sortPathConstraintAttachment(Skin skin, int slotIndex, Bone slotBone) {
    (skin.attachments[slotIndex]!).forEach((String key, Attachment value) {
      sortPathConstraintAttachmentWith(value, slotBone);
    });
  }

  void sortPathConstraintAttachmentWith(Attachment attachment, Bone slotBone) {
    if (attachment is! PathAttachment) return;
    final PathAttachment pathAttachment = attachment;
    final Int32List? pathBones = pathAttachment.bones;
    if (pathBones == null)
      sortBone(slotBone);
    else {
      final List<Bone> bones = this.bones;
      int i = 0;
      while (i < pathBones.length) {
        final int boneCount = pathBones[i++];
        final int n = i + boneCount;
        for (; i < n; i++) {
          final int boneIndex = pathBones[i];
          sortBone(bones[boneIndex]);
        }
      }
    }
  }

  void sortBone(Bone bone) {
    if (bone.sorted) return;
    final Bone? parent = bone.parent;
    if (parent != null) sortBone(parent);
    bone.sorted = true;
    _updateCache.add(bone);
  }

  void sortReset(List<Bone> bones) {
    final int n = bones.length;
    for (int i = 0; i < n; i++) {
      final Bone bone = bones[i];
      if (bone.sorted) sortReset(bone.children);
      bone.sorted = false;
    }
  }

  void updateWorldTransform() {
    final List<Updatable?> updateCacheReset = _updateCacheReset;
    final int n = updateCacheReset.length;
    for (int i = 0; i < n; i++) {
      final Bone bone = updateCacheReset[i] as Bone;
      bone
        ..ax = bone.x
        ..ay = bone.y
        ..arotation = bone.rotation
        ..ascaleX = bone.scaleX
        ..ascaleY = bone.scaleY
        ..ashearX = bone.shearX
        ..ashearY = bone.shearY
        ..appliedValid = true;
    }
    final List<Updatable> updateCache = _updateCache;
    final int nn = updateCache.length;
    for (int i = 0; i < nn; i++) updateCache[i].update();
  }

  void setToSetupPose() {
    setBonesToSetupPose();
    setSlotsToSetupPose();
  }

  void setBonesToSetupPose() {
    final List<Bone> bones = this.bones;
    final int n = bones.length;
    for (int i = 0; i < n; i++) bones[i].setToSetupPose();

    final List<IkConstraint> ikConstraints = this.ikConstraints;
    final int nn = ikConstraints.length;
    for (int i = 0; i < nn; i++) {
      final IkConstraint constraint = ikConstraints[i];
      constraint
        ..bendDirection = constraint.data.bendDirection
        ..mix = constraint.data.mix;
    }

    final List<TransformConstraint> transformConstraints =
        this.transformConstraints;
    final int nnn = transformConstraints.length;
    for (int i = 0; i < nnn; i++) {
      final TransformConstraint constraint = transformConstraints[i];
      final TransformConstraintData data = constraint.data;
      constraint
        ..rotateMix = data.rotateMix
        ..translateMix = data.translateMix
        ..scaleMix = data.scaleMix
        ..shearMix = data.shearMix;
    }

    final List<PathConstraint> pathConstraints = this.pathConstraints;
    final int nnnn = pathConstraints.length;
    for (int i = 0; i < nnnn; i++) {
      final PathConstraint constraint = pathConstraints[i];
      final PathConstraintData data = constraint.data;
      constraint
        ..position = data.position
        ..spacing = data.spacing
        ..rotateMix = data.rotateMix
        ..translateMix = data.translateMix;
    }
  }

  void setSlotsToSetupPose() {
    final List<Slot> slots = this.slots;
    drawOrder = ArrayUtils.arrayCopyWithGrowth(
        slots, 0, drawOrder, 0, slots.length, Slot.empty());
    final int n = slots.length;
    for (int i = 0; i < n; i++) slots[i].setToSetupPose();
  }

  Bone? getRootBone() => bones.isEmpty ? null : bones[0];

  Bone? findBone(String boneName) {
    final List<Bone> bones = this.bones;
    final int n = bones.length;
    for (int i = 0; i < n; i++) {
      final Bone bone = bones[i];
      if (bone.data.name == boneName) return bone;
    }
    return null;
  }

  int findBoneIndex(String boneName) {
    final List<Bone> bones = this.bones;
    final int n = bones.length;
    for (int i = 0; i < n; i++) if (bones[i].data.name == boneName) return i;
    return -1;
  }

  Slot? findSlot(String slotName) {
    if (slotName.isEmpty) throw ArgumentError('slotName cannot be empty.');
    final List<Slot> slots = this.slots;
    final int n = slots.length;
    for (int i = 0; i < n; i++) {
      final Slot slot = slots[i];
      if (slot.data.name == slotName) return slot;
    }
    return null;
  }

  int findSlotIndex(String slotName) {
    final List<Slot> slots = this.slots;
    final int n = slots.length;
    for (int i = 0; i < n; i++) if (slots[i].data.name == slotName) return i;
    return -1;
  }

  void setSkinByName(String skinName) {
    final Skin? skin = data.findSkin(skinName);
    if (skin == null) throw StateError('Skin not found: $skinName');
    setSkin(skin);
  }

  void setSkin(Skin? newSkin) {
    if (newSkin != null) {
      if (skin != null)
        newSkin.attachAll(this, skin);
      else {
        final List<Slot> slots = this.slots;
        final int n = slots.length;
        for (int i = 0; i < n; i++) {
          final Slot slot = slots[i];
          final String? name = slot.data.attachmentName;
          if (name != null) {
            final Attachment? attachment = newSkin.getAttachment(i, name);
            if (attachment != null) slot.setAttachment(attachment);
          }
        }
      }
    }
    skin = newSkin;
  }

  Attachment? getAttachmentByName(String slotName, String attachmentName) =>
      getAttachment(data.findSlotIndex(slotName), attachmentName);

  Attachment? getAttachment(int? slotIndex, String? attachmentName) {
    if (attachmentName == null)
      throw ArgumentError('attachmentName cannot be null.');
    if (skin != null) {
      final Attachment? attachment =
          skin!.getAttachment(slotIndex!, attachmentName);
      if (attachment != null) return attachment;
    }
    if (data.defaultSkin != null)
      return data.defaultSkin!.getAttachment(slotIndex!, attachmentName);
    return null;
  }

  void setAttachment(String slotName, String attachmentName) {
    final List<Slot> slots = this.slots;
    final int n = slots.length;
    for (int i = 0; i < n; i++) {
      final Slot slot = slots[i];
      if (slot.data.name == slotName) {
        Attachment? attachment;
        if (attachmentName.isNotEmpty) {
          attachment = getAttachment(i, attachmentName);
          if (attachment == null)
            throw StateError(
                'Attachment not found: $attachmentName, for slot: $slotName');
        }
        slot.setAttachment(attachment);
        return;
      }
    }
    throw StateError('Slot not found: ' + slotName);
  }

  IkConstraint? findIkConstraint(String constraintName) {
    final List<IkConstraint> ikConstraints = this.ikConstraints;
    final int n = ikConstraints.length;
    for (int i = 0; i < n; i++) {
      final IkConstraint ikConstraint = ikConstraints[i];
      if (ikConstraint.data.name == constraintName) return ikConstraint;
    }
    return null;
  }

  TransformConstraint? findTransformConstraint(String constraintName) {
    final List<TransformConstraint> transformConstraints =
        this.transformConstraints;
    final int n = transformConstraints.length;
    for (int i = 0; i < n; i++) {
      final TransformConstraint constraint = transformConstraints[i];
      if (constraint.data.name == constraintName) return constraint;
    }
    return null;
  }

  PathConstraint? findPathConstraint(String constraintName) {
    final List<PathConstraint> pathConstraints = this.pathConstraints;
    final int n = pathConstraints.length;
    for (int i = 0; i < n; i++) {
      final PathConstraint constraint = pathConstraints[i];
      if (constraint.data.name == constraintName) return constraint;
    }
    return null;
  }

  void getBounds(Vector2 offset, Vector2 size, List<double> temp) {
    final List<Slot> drawOrder = this.drawOrder;
    double minX = double.infinity,
        minY = double.infinity,
        maxX = double.negativeInfinity,
        maxY = double.negativeInfinity;

    final int n = drawOrder.length;
    for (int i = 0; i < n; i++) {
      final Slot slot = drawOrder[i];
      int verticesLength = 0;
      Float32List? vertices;
      final Attachment? attachment = slot.getAttachment();
      if (attachment is RegionAttachment) {
        final RegionAttachment region = attachment;
        verticesLength = 8;
        vertices = Float32List.fromList(
            ArrayUtils.copyWithNewArraySize(temp, verticesLength, double.infinity));
        region.computeWorldVertices2(slot.bone, vertices, 0, 2);
      } else if (attachment is MeshAttachment) {
        final MeshAttachment mesh = attachment;
        verticesLength = mesh.worldVerticesLength;
        vertices = Float32List.fromList(
            ArrayUtils.copyWithNewArraySize(temp, verticesLength, double.infinity));
        mesh.computeWorldVertices(slot, 0, verticesLength, vertices, 0, 2);
      }
      if (vertices != null) {
        final int nn = vertices.length;
        for (int ii = 0; ii < nn; ii += 2) {
          final double x = vertices[ii], y = vertices[ii + 1];
          minX = math.min(minX, x);
          minY = math.min(minY, y);
          maxX = math.max(maxX, x);
          maxY = math.max(maxY, y);
        }
      }
    }
    offset.set(minX, minY);
    size.set(maxX - minX, maxY - minY);
  }

  void update(double delta) => time += delta;
}
