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

class SkeletonJson {
  final List<LinkedMesh> linkedMeshes = <LinkedMesh>[];
  AttachmentLoader attachmentLoader;
  double scale = 1.0;

  SkeletonJson(this.attachmentLoader);

  SkeletonData readSkeletonData(Object object) {
    final double scale = this.scale;
    final SkeletonData skeletonData = SkeletonData();

    dynamic root;

    if (object is String) {
      root = json.decode(object);
    } else if (object is Map) {
      root = object;
    } else {
      throw ArgumentError('object must be a String or Map.');
    }

    // Skeleton
    if (root.containsKey('skeleton')) {
      final dynamic skeletonMap = root['skeleton'];
      skeletonData
        ..hash = _getString(skeletonMap, 'hash')
        ..version = _getString(skeletonMap, 'spine')
        ..width = _getDouble(skeletonMap, 'width')
        ..height = _getDouble(skeletonMap, 'height')
        ..fps = _getDouble(skeletonMap, 'fps')
        ..imagesPath = _getString(skeletonMap, 'images');
    }

    // Bones
    if (root.containsKey('bones')) {
      for (int i = 0; i < root['bones'].length; i++) {
        final dynamic boneMap = root['bones'][i];

        BoneData? parent;
        final String parentName = _getString(boneMap, 'parent');
        if (parentName.isNotEmpty) {
          parent = skeletonData.findBone(parentName);
          if (parent == null)
            throw StateError('Parent bone not found: $parentName');
        }
        final BoneData data = BoneData(
            skeletonData.bones.length, _getString(boneMap, 'name'), parent)
          ..length = _getDouble(boneMap, 'length', 0.0) * scale
          ..x = _getDouble(boneMap, 'x', 0.0) * scale
          ..y = _getDouble(boneMap, 'y', 0.0) * scale
          ..rotation = _getDouble(boneMap, 'rotation', 0.0)
          ..scaleX = _getDouble(boneMap, 'scaleX', 1.0)
          ..scaleY = _getDouble(boneMap, 'scaleY', 1.0)
          ..shearX = _getDouble(boneMap, 'shearX', 0.0)
          ..shearY = _getDouble(boneMap, 'shearY', 0.0)
          ..transformMode = SkeletonJson.transformModeFromString(
              _getString(boneMap, 'transform', 'normal'));

        skeletonData.bones.add(data);
      }
    }

    // Slots.
    if (root.containsKey('slots')) {
      for (int i = 0; i < root['slots'].length; i++) {
        final dynamic slotMap = root['slots'][i];
        final String slotName = _getString(slotMap, 'name');
        final String boneName = _getString(slotMap, 'bone');
        final BoneData? boneData = skeletonData.findBone(boneName);
        if (boneData == null)
          throw StateError('Slot bone not found: ' + boneName);
        final SlotData data =
            SlotData(skeletonData.slots.length, slotName, boneData);

        final String color = _getString(slotMap, 'color');
        if (color.isNotEmpty) data.color.setFromString(color);

        final String dark = _getString(slotMap, 'dark');
        if (dark.isNotEmpty) {
          data.darkColor = Color(1.0, 1.0, 1.0, 1.0);
          data.darkColor!.setFromString(dark);
        }

        data
          ..attachmentName = _getString(slotMap, 'attachment')
          ..blendMode = SkeletonJson.blendModeFromString(
              _getString(slotMap, 'blend', 'normal'));
        skeletonData.slots.add(data);
      }
    }

    // IK constraints
    if (root.containsKey('ik')) {
      for (int i = 0; i < root['ik'].length; i++) {
        final dynamic constraintMap = root['ik'][i];
        final IkConstraintData data =
            IkConstraintData(_getString(constraintMap, 'name'))
              ..order = _getInt(constraintMap, 'order', 0);

        for (int j = 0; j < constraintMap['bones'].length; j++) {
          final String boneName = constraintMap['bones'][j];
          final BoneData? bone = skeletonData.findBone(boneName);
          if (bone == null) throw StateError('IK bone not found: ' + boneName);
          data.bones.add(bone);
        }

        final String targetName = _getString(constraintMap, 'target');
        data.target = skeletonData.findBone(targetName);
        if (data.target == null)
          throw StateError('IK target bone not found: ' + targetName);

        data
          ..bendDirection =
              _getBool(constraintMap, 'bendPositive', true) ? 1 : -1
          ..mix = _getDouble(constraintMap, 'mix', 1.0);

        skeletonData.ikConstraints.add(data);
      }
    }

    // Transform constraints.
    if (root.containsKey('transform')) {
      for (int i = 0; i < root['transform'].length; i++) {
        final dynamic constraintMap = root['transform'][i];
        final TransformConstraintData data =
            TransformConstraintData(_getString(constraintMap, 'name'))
              ..order = _getInt(constraintMap, 'order', 0);

        for (int j = 0; j < constraintMap['bones'].length; j++) {
          final String boneName = constraintMap['bones'][j]!;
          final BoneData? bone = skeletonData.findBone(boneName);
          if (bone == null)
            throw StateError('Transform constraint bone not found: $boneName');
          data.bones.add(bone);
        }

        final String targetName = _getString(constraintMap, 'target');
        data.target = skeletonData.findBone(targetName);
        if (data.target == null)
          throw StateError(
              'Transform constraint target bone not found: $targetName');

        data
          ..local = _getBool(constraintMap, 'local', false)
          ..relative = _getBool(constraintMap, 'relative', false)
          ..offsetRotation = _getDouble(constraintMap, 'rotation', 0.0)
          ..offsetX = _getDouble(constraintMap, 'x', 0.0) * scale
          ..offsetY = _getDouble(constraintMap, 'y', 0.0) * scale
          ..offsetScaleX = _getDouble(constraintMap, 'scaleX', 0.0)
          ..offsetScaleY = _getDouble(constraintMap, 'scaleY', 0.0)
          ..offsetShearY = _getDouble(constraintMap, 'shearY', 0.0)
          ..rotateMix = _getDouble(constraintMap, 'rotateMix', 1.0)
          ..translateMix = _getDouble(constraintMap, 'translateMix', 1.0)
          ..scaleMix = _getDouble(constraintMap, 'scaleMix', 1.0)
          ..shearMix = _getDouble(constraintMap, 'shearMix', 1.0);

        skeletonData.transformConstraints.add(data);
      }
    }

    // Path constraints.
    if (root.containsKey('path')) {
      for (int i = 0; i < root['path'].length; i++) {
        final dynamic constraintMap = root['path'][i];
        final PathConstraintData data =
            PathConstraintData(_getString(constraintMap, 'name'))
              ..order = _getInt(constraintMap, 'order', 0);

        for (int j = 0; j < constraintMap['bones'].length; j++) {
          final String boneName = constraintMap['bones'][j]!;
          final BoneData? bone = skeletonData.findBone(boneName);
          if (bone == null)
            throw StateError('Transform constraint bone not found: $boneName');
          data.bones.add(bone);
        }

        final String targetName = _getString(constraintMap, 'target');
        data.target = skeletonData.findSlot(targetName);
        if (data.target == null)
          throw StateError('Path target slot not found: $targetName');

        data
          ..positionMode = SkeletonJson.positionModeFromString(
              _getString(constraintMap, 'positionMode', 'percent'))
          ..spacingMode = SkeletonJson.spacingModeFromString(
              _getString(constraintMap, 'spacingMode', 'length'))
          ..rotateMode = SkeletonJson.rotateModeFromString(
              _getString(constraintMap, 'rotateMode', 'tangent'))
          ..offsetRotation = _getDouble(constraintMap, 'rotation', 0.0)
          ..position = _getDouble(constraintMap, 'position', 0.0);
        if (data.positionMode == PositionMode.Fixed) data.position = data.position * scale;
        data.spacing = _getDouble(constraintMap, 'spacing', 0.0);
        if (data.spacingMode == SpacingMode.Length ||
            data.spacingMode == SpacingMode.Fixed) data.spacing = data.spacing * scale;
        data
          ..rotateMix = _getDouble(constraintMap, 'rotateMix', 1.0)
          ..translateMix = _getDouble(constraintMap, 'translateMix', 1.0);

        skeletonData.pathConstraints.add(data);
      }
    }

    // // Skins.
    if (root.containsKey('skins')) {
      for (String skinName in root['skins'].keys) {
        final dynamic skinMap = root['skins'][skinName];
        final Skin skin = Skin(skinName);
        for (String slotName in skinMap.keys) {
          final int slotIndex = skeletonData.findSlotIndex(slotName);
          if (slotIndex == -1) throw StateError('Slot not found: $slotName');
          final dynamic slotMap = skinMap[slotName];
          for (String entryName in slotMap.keys) {
            final Attachment? attachment = readAttachment(
                slotMap[entryName], skin, slotIndex, entryName, skeletonData);
            if (attachment != null)
              skin.addAttachment(slotIndex, entryName, attachment);
          }
        }
        skeletonData.skins.add(skin);
        if (skin.name == 'default') skeletonData.defaultSkin = skin;
      }
    }

    // Linked meshes.
    final int n = linkedMeshes.length;
    for (int i = 0; i < n; i++) {
      final LinkedMesh linkedMesh = linkedMeshes[i];
      final Skin? skin = linkedMesh.skin == null
          ? skeletonData.defaultSkin
          : skeletonData.findSkin(linkedMesh.skin);
      if (skin == null) throw StateError('Skin not found: $linkedMesh.skin');
      final Attachment? parent =
          skin.getAttachment(linkedMesh.slotIndex, linkedMesh.parent);
      if (parent == null)
        throw StateError('Parent mesh not found: $linkedMesh.parent');
      linkedMesh.mesh.parentMesh = parent as MeshAttachment?;
      linkedMesh.mesh.updateUVs();
    }
    linkedMeshes.length = 0;

    // Events.
    if (root.containsKey('events')) {
      for (String eventName in root['events'].keys) {
        final dynamic eventMap = root['events'][eventName];
        final EventData data = EventData(eventName)
          ..intValue = _getInt(eventMap, 'int')
          ..floatValue = _getDouble(eventMap, 'float')
          ..stringValue = _getString(eventMap, 'string');
        skeletonData.events.add(data);
      }
    }

    // Animations.
    if (root.containsKey('animations')) {
      for (String animationName in root['animations'].keys) {
        final dynamic animationMap = root['animations'][animationName];
        readAnimation(animationMap, animationName, skeletonData);
      }
    }

    return skeletonData;
  }

  Attachment? readAttachment(Map<String, dynamic> map, Skin skin, int slotIndex,
      String name, SkeletonData skeletonData) {
    final double scale = this.scale;
    name = _getString(map, 'name', name);

    final String type = _getString(map, 'type', 'region');

    switch (type) {
      case 'region':
        {
          final String path = _getString(map, 'path', name);
          final RegionAttachment region =
              attachmentLoader.newRegionAttachment(skin, name, path)
                ..path = path
                ..x = _getDouble(map, 'x', 0.0) * scale
                ..y = _getDouble(map, 'y', 0.0) * scale
                ..scaleX = _getDouble(map, 'scaleX', 1.0)
                ..scaleY = _getDouble(map, 'scaleY', 1.0)
                ..rotation = _getDouble(map, 'rotation', 0.0)
                ..width = _getDouble(map, 'width') * scale
                ..height = _getDouble(map, 'height') * scale;

          final String color = _getString(map, 'color');
          if (color.isNotEmpty) region.color.setFromString(color);

          region.updateOffset();
          return region;
        }
      case 'boundingbox':
        {
          final BoundingBoxAttachment box =
              attachmentLoader.newBoundingBoxAttachment(skin, name);
          readVertices(map, box, _getInt(map, 'vertexCount') << 1);
          final String color = _getString(map, 'color');
          if (color.isNotEmpty) box.color.setFromString(color);
          return box;
        }
      case 'mesh':
      case 'linkedmesh':
        {
          final String path = _getString(map, 'path', name);
          final MeshAttachment mesh =
              attachmentLoader.newMeshAttachment(skin, name, path)..path = path;

          final String color = _getString(map, 'color');
          if (color.isNotEmpty) mesh.color.setFromString(color);

          final String parent = _getString(map, 'parent');
          if (parent.isNotEmpty) {
            mesh.inheritDeform = _getBool(map, 'deform', true);
            linkedMeshes.add(
                LinkedMesh(mesh, _getString(map, 'skin'), slotIndex, parent));
            return mesh;
          }

          final Float32List uvs = _getFloat32List(map, 'uvs')!;
          readVertices(map, mesh, uvs.length);
          mesh
            ..triangles = _getInt16List(map, 'triangles')
            ..regionUVs = uvs
            ..updateUVs()
            ..hullLength = _getInt(map, 'hull', 0) * 2;
          return mesh;
        }
      case 'path':
        {
          final PathAttachment path =
              attachmentLoader.newPathAttachment(skin, name)
                ..closed = _getBool(map, 'closed', false)
                ..constantSpeed = _getBool(map, 'constantSpeed', true);

          final int vertexCount = _getInt(map, 'vertexCount');
          readVertices(map, path, vertexCount << 1);

          path.lengths = _getFloat32List(map, 'lengths')!
              .map((double length) => length * scale) as Float32List;

          final String color = _getString(map, 'color');
          if (color.isNotEmpty) path.color.setFromString(color);
          return path;
        }
      case 'point':
        {
          final PointAttachment point =
              attachmentLoader.newPointAttachment(skin, name)
                ..x = _getDouble(map, 'x', 0.0) * scale
                ..y = _getDouble(map, 'y', 0.0) * scale
                ..rotation = _getDouble(map, 'rotation', 0.0);

          final String color = _getString(map, 'color');
          if (color.isNotEmpty) point.color.setFromString(color);
          return point;
        }
      case 'clipping':
        {
          final ClippingAttachment clip =
              attachmentLoader.newClippingAttachment(skin, name);

          final String end = _getString(map, 'end');
          if (end.isNotEmpty) {
            final SlotData? slot = skeletonData.findSlot(end);
            if (slot == null)
              throw StateError('Clipping end slot not found: $end');
            clip.endSlot = slot;
          }

          final int vertexCount = _getInt(map, 'vertexCount');
          readVertices(map, clip, vertexCount << 1);

          final String color = _getString(map, 'color');
          if (color.isNotEmpty) clip.color.setFromString(color);
          return clip;
        }
    }
    return null;
  }

  void readVertices(Map<String, dynamic> map, VertexAttachment attachment,
      int verticesLength) {
    final double scale = this.scale;
    attachment.worldVerticesLength = verticesLength;
    final Float32List vertices = _getFloat32List(map, 'vertices')!;
    if (verticesLength == vertices.length) {
      if (scale != 1) {
        final int n = vertices.length;
        for (int i = 0; i < n; i++) vertices[i] *= scale;
      }

      attachment.vertices = vertices;
      return;
    }
    final List<double> weights = <double>[];
    final List<int> bones = <int>[];
    final int n = vertices.length;
    for (int i = 0; i < n;) {
      final int boneCount = vertices[i++].toInt();
      bones.add(boneCount);
      final int nn = i + boneCount * 4;
      for (; i < nn; i += 4) {
        bones.add(vertices[i].toInt());
        weights
          ..add(vertices[i + 1] * scale)
          ..add(vertices[i + 2] * scale)
          ..add(vertices[i + 3]);
      }
    }
    attachment
      ..bones = Int32List.fromList(bones)
      ..vertices = Float32List.fromList(weights);
  }

  void readAnimation(
      Map<String, dynamic> map, String name, SkeletonData skeletonData) {
    final double scale = this.scale;
    final List<Timeline> timelines = <Timeline>[];
    double duration = 0.0;

    // Slot timelines.
    if (map.containsKey('slots')) {
      for (String slotName in map['slots'].keys) {
        final dynamic slotMap = map['slots'][slotName];
        final int slotIndex = skeletonData.findSlotIndex(slotName);
        if (slotIndex == -1) throw StateError('Slot not found: ' + slotName);
        for (String timelineName in slotMap.keys) {
          final dynamic timelineMap = slotMap[timelineName];
          if (timelineName == 'attachment') {
            final AttachmentTimeline timeline =
                AttachmentTimeline(timelineMap.length)..slotIndex = slotIndex;

            int frameIndex = 0;
            for (int i = 0; i < timelineMap.length; i++) {
              final dynamic valueMap = timelineMap[i];
              timeline.setFrame(frameIndex++, _getDouble(valueMap, 'time'),
                  _getString(valueMap, 'name'));
            }
            timelines.add(timeline);
            duration = math.max(
                duration, timeline.frames[timeline.getFrameCount() - 1]);
          } else if (timelineName == 'color') {
            final ColorTimeline timeline = ColorTimeline(timelineMap.length)
              ..slotIndex = slotIndex;

            int frameIndex = 0;
            for (int i = 0; i < timelineMap.length; i++) {
              final dynamic valueMap = timelineMap[i];
              final Color color = Color()
                ..setFromString(_getString(valueMap, 'color'));
              timeline.setFrame(frameIndex, _getDouble(valueMap, 'time'),
                  color.r, color.g, color.b, color.a);
              readCurve(valueMap, timeline, frameIndex);
              frameIndex++;
            }
            timelines.add(timeline);
            duration = math.max(
                duration,
                timeline.frames[
                    (timeline.getFrameCount() - 1) * ColorTimeline.entries]);
          } else if (timelineName == 'twoColor') {
            final TwoColorTimeline timeline =
                TwoColorTimeline(timelineMap.length)..slotIndex = slotIndex;

            int frameIndex = 0;
            for (int i = 0; i < timelineMap.length; i++) {
              final dynamic valueMap = timelineMap[i];
              final Color light = Color();
              final Color dark = Color();
              light.setFromString(_getString(valueMap, 'light'));
              dark.setFromString(_getString(valueMap, 'dark'));
              timeline.setFrame(frameIndex, _getDouble(valueMap, 'time'),
                  light.r, light.g, light.b, light.a, dark.r, dark.g, dark.b);
              readCurve(valueMap, timeline, frameIndex);
              frameIndex++;
            }
            timelines.add(timeline);
            duration = math.max(
                duration,
                timeline.frames[
                    (timeline.getFrameCount() - 1) * TwoColorTimeline.entries]);
          } else
            throw StateError(
                'Invalid timeline type for a slot: $timelineName ($slotName)');
        }
      }
    }

    // Bone timelines.
    if (map.containsKey('bones')) {
      for (String boneName in map['bones'].keys) {
        final dynamic boneMap = map['bones'][boneName];
        final int boneIndex = skeletonData.findBoneIndex(boneName);
        if (boneIndex == -1) throw StateError('Bone not found: $boneName');
        for (String timelineName in boneMap.keys) {
          final dynamic timelineMap = boneMap[timelineName];
          if (timelineName == 'rotate') {
            final RotateTimeline timeline = RotateTimeline(timelineMap.length)
              ..boneIndex = boneIndex;

            int frameIndex = 0;
            for (int i = 0; i < timelineMap.length; i++) {
              final dynamic valueMap = timelineMap[i];
              timeline.setFrame(frameIndex, _getDouble(valueMap, 'time'),
                  _getDouble(valueMap, 'angle', 0.0));
              readCurve(valueMap, timeline, frameIndex);
              frameIndex++;
            }
            timelines.add(timeline);
            duration = math.max(
                duration,
                timeline.frames[
                    (timeline.getFrameCount() - 1) * RotateTimeline.entries]);
          } else if (timelineName == 'translate' ||
              timelineName == 'scale' ||
              timelineName == 'shear') {
            TranslateTimeline timeline;
            double timelineScale = 1.0;
            if (timelineName == 'scale')
              timeline = ScaleTimeline(timelineMap.length);
            else if (timelineName == 'shear')
              timeline = ShearTimeline(timelineMap.length);
            else {
              timeline = TranslateTimeline(timelineMap.length);
              timelineScale = scale;
            }
            timeline.boneIndex = boneIndex;

            int frameIndex = 0;
            for (int i = 0; i < timelineMap.length; i++) {
              final dynamic valueMap = timelineMap[i];
              final double? x = _getDouble(valueMap, 'x', 0.0),
                  y = _getDouble(valueMap, 'y', 0.0);
              timeline.setFrame(frameIndex, _getDouble(valueMap, 'time'),
                  x! * timelineScale, y! * timelineScale);
              readCurve(valueMap, timeline, frameIndex);
              frameIndex++;
            }
            timelines.add(timeline);
            duration = math.max(
                duration,
                timeline.frames[(timeline.getFrameCount() - 1) *
                    TranslateTimeline.entries]);
          } else
            throw StateError(
                'Invalid timeline type for a bone: $timelineName ($boneName)');
        }
      }
    }

    // IK constraint timelines.
    if (map.containsKey('ik')) {
      for (String constraintName in map['ik'].keys) {
        final dynamic constraintMap = map['ik'][constraintName];
        final IkConstraintData? constraint =
            skeletonData.findIkConstraint(constraintName);
        final IkConstraintTimeline timeline =
            IkConstraintTimeline(constraintMap.length)
              ..ikConstraintIndex =
                  skeletonData.ikConstraints.indexOf(constraint);
        int frameIndex = 0;
        for (int i = 0; i < constraintMap.length; i++) {
          final dynamic valueMap = constraintMap[i];
          timeline.setFrame(
              frameIndex,
              _getDouble(valueMap, 'time'),
              _getDouble(valueMap, 'mix', 1.0),
              _getBool(valueMap, 'bendPositive', true) ? 1 : -1);
          readCurve(valueMap, timeline, frameIndex);
          frameIndex++;
        }
        timelines.add(timeline);
        duration = math.max(
            duration,
            timeline.frames[
                (timeline.getFrameCount() - 1) * IkConstraintTimeline.entries]);
      }
    }

    // Transform constraint timelines.
    if (map.containsKey('transform')) {
      for (String constraintName in map['transform'].keys) {
        final dynamic constraintMap = map['transform'][constraintName];
        final TransformConstraintData? constraint =
            skeletonData.findTransformConstraint(constraintName);
        final TransformConstraintTimeline timeline =
            TransformConstraintTimeline(constraintMap.length)
              ..transformConstraintIndex =
                  skeletonData.transformConstraints.indexOf(constraint);
        int frameIndex = 0;
        for (int i = 0; i < constraintMap.length; i++) {
          final dynamic valueMap = constraintMap[i];
          timeline.setFrame(
              frameIndex,
              _getDouble(valueMap, 'time'),
              _getDouble(valueMap, 'rotateMix', 1.0),
              _getDouble(valueMap, 'translateMix', 1.0),
              _getDouble(valueMap, 'scaleMix', 1.0),
              _getDouble(valueMap, 'shearMix', 1.0));
          readCurve(valueMap, timeline, frameIndex);
          frameIndex++;
        }
        timelines.add(timeline);
        duration = math.max(
            duration,
            timeline.frames[(timeline.getFrameCount() - 1) *
                TransformConstraintTimeline.entries]);
      }
    }

    // Path constraint timelines.
    if (map.containsKey('paths')) {
      for (String constraintName in map['paths'].keys) {
        final dynamic constraintMap = map['paths'][constraintName];
        final int index = skeletonData.findPathConstraintIndex(constraintName);
        if (index == -1)
          throw StateError('Path constraint not found: $constraintName');
        final PathConstraintData data = skeletonData.pathConstraints[index];
        for (String timelineName in constraintMap.keys) {
          final dynamic timelineMap = constraintMap[timelineName];
          if (timelineName == 'position' || timelineName == 'spacing') {
            PathConstraintPositionTimeline timeline;
            double timelineScale = 1.0;
            if (timelineName == 'spacing') {
              timeline = PathConstraintSpacingTimeline(timelineMap.length);
              if (data.spacingMode == SpacingMode.Length ||
                  data.spacingMode == SpacingMode.Fixed) timelineScale = scale;
            } else {
              timeline = PathConstraintPositionTimeline(timelineMap.length);
              if (data.positionMode == PositionMode.Fixed)
                timelineScale = scale;
            }
            timeline.pathConstraintIndex = index;
            int frameIndex = 0;
            for (int i = 0; i < timelineMap.length; i++) {
              final dynamic valueMap = timelineMap[i];
              timeline.setFrame(frameIndex, _getDouble(valueMap, 'time'),
                  _getDouble(valueMap, timelineName, 0.0) * timelineScale);
              readCurve(valueMap, timeline, frameIndex);
              frameIndex++;
            }
            timelines.add(timeline);
            duration = math.max(
                duration,
                timeline.frames[(timeline.getFrameCount() - 1) *
                    PathConstraintPositionTimeline.entries]);
          } else if (timelineName == 'mix') {
            final PathConstraintMixTimeline timeline =
                PathConstraintMixTimeline(timelineMap.length)
                  ..pathConstraintIndex = index;
            int frameIndex = 0;
            for (int i = 0; i < timelineMap.length; i++) {
              final dynamic valueMap = timelineMap[i];
              timeline.setFrame(
                  frameIndex,
                  _getDouble(valueMap, 'time'),
                  _getDouble(valueMap, 'rotateMix', 1.0),
                  _getDouble(valueMap, 'translateMix', 1.0));
              readCurve(valueMap, timeline, frameIndex);
              frameIndex++;
            }
            timelines.add(timeline);
            duration = math.max(
                duration,
                timeline.frames[(timeline.getFrameCount() - 1) *
                    PathConstraintMixTimeline.entries]);
          }
        }
      }
    }

    // Deform timelines.
    if (map.containsKey('deform')) {
      for (String deformName in map['deform'].keys) {
        final dynamic deformMap = map['deform'][deformName];
        final Skin? skin = skeletonData.findSkin(deformName);
        if (skin == null) throw StateError('Skin not found: $deformName');
        for (String slotName in deformMap.keys) {
          final dynamic slotMap = deformMap[slotName];
          final int slotIndex = skeletonData.findSlotIndex(slotName);
          if (slotIndex == -1)
            throw StateError('Slot not found: ${_getString(slotMap, 'name')}');
          for (String timelineName in slotMap.keys) {
            final dynamic timelineMap = slotMap[timelineName];
            final VertexAttachment? attachment =
                skin.getAttachment(slotIndex, timelineName) as VertexAttachment?;
            if (attachment == null)
              throw StateError(
                  'Deform attachment not found: ${_getString(timelineMap, 'name')}');
            final bool weighted = attachment.bones != null;
            final Float32List? vertices = attachment.vertices;
            final int deformLength =
                weighted ? vertices!.length ~/ 3 * 2 : vertices!.length;

            final DeformTimeline timeline = DeformTimeline(timelineMap.length)
              ..slotIndex = slotIndex
              ..attachment = attachment;

            int frameIndex = 0;
            for (int j = 0; j < timelineMap.length; j++) {
              final dynamic valueMap = timelineMap[j];
              Float32List? deform;
              final Float32List? verticesValue =
                  _getFloat32List(valueMap, 'vertices');
              if (verticesValue == null)
                deform = weighted ? Float32List(deformLength) : vertices;
              else {
                deform = Float32List(deformLength);
                final int start = _getInt(valueMap, 'offset', 0);
                deform = ArrayUtils.arrayCopyWithGrowth(verticesValue, 0, deform,
                    start, verticesValue.length, 0.0) as Float32List;
                if (scale != 1) {
                  for (int i = start; i < i + verticesValue.length; i++)
                    deform[i] *= scale;
                }
                if (!weighted) {
                  for (int i = 0; i < deformLength; i++)
                    deform[i] += vertices[i];
                }
              }

              timeline.setFrame(
                  frameIndex, _getDouble(valueMap, 'time'), deform);
              readCurve(valueMap, timeline, frameIndex);
              frameIndex++;
            }
            timelines.add(timeline);
            duration = math.max(
                duration, timeline.frames[timeline.getFrameCount() - 1]);
          }
        }
      }
    }

    // Draw order timeline.
    if (map.containsKey('drawOrder') || map.containsKey('draworder')) {
      final List<dynamic> drawOrderNode =
          map[map.containsKey('drawOrder') ? 'drawOrder' : 'draworder'];
      final DrawOrderTimeline timeline =
          DrawOrderTimeline(drawOrderNode.length);
      final int slotCount = skeletonData.slots.length;
      int frameIndex = 0;
      for (int j = 0; j < drawOrderNode.length; j++) {
        final dynamic drawOrderMap = drawOrderNode[j];
        Int32List? drawOrder;
        final List<dynamic>? offsets = drawOrderMap['offsets'];
        if (offsets != null) {
          drawOrder = Int32List.fromList(List<int>.filled(slotCount, -1));
          final Int32List unchanged = Int32List.fromList(
              List<int>.filled(slotCount - offsets.length, 0));
          int originalIndex = 0, unchangedIndex = 0;
          for (int i = 0; i < offsets.length; i++) {
            final dynamic offsetMap = offsets[i];
            final int slotIndex =
                skeletonData.findSlotIndex(_getString(offsetMap, 'slot'));
            if (slotIndex == -1)
              throw StateError(
                  'Slot not found: ${_getString(offsetMap, 'slot')}');
            // Collect unchanged items.
            while (originalIndex != slotIndex)
              unchanged[unchangedIndex++] = originalIndex++;
            // Set changed items.
            drawOrder[originalIndex + _getInt(offsetMap, 'offset')] =
                originalIndex++;
          }
          // Collect remaining unchanged items.
          while (originalIndex < slotCount)
            unchanged[unchangedIndex++] = originalIndex++;
          // Fill in unchanged items.
          for (int i = slotCount - 1; i >= 0; i--)
            if (drawOrder[i] == -1) drawOrder[i] = unchanged[--unchangedIndex];
        }
        timeline.setFrame(
            frameIndex++, _getDouble(drawOrderMap, 'time'), drawOrder);
      }
      timelines.add(timeline);
      duration =
          math.max(duration, timeline.frames[timeline.getFrameCount() - 1]);
    }

    // Event timeline.
    if (map.containsKey('events')) {
      final EventTimeline timeline = EventTimeline(map['events'].length);
      int frameIndex = 0;
      for (int i = 0; i < map['events'].length; i++) {
        final dynamic eventMap = map['events'][i];
        final String eventDataName = _getString(eventMap, 'name');
        final EventData? eventData = skeletonData.findEvent(eventDataName);
        if (eventData == null)
          throw StateError('Event not found: $eventDataName');
        final Event event = Event(_getDouble(eventMap, 'time'), eventData)
          ..intValue = _getInt(eventMap, 'int', eventData.intValue)
          ..floatValue = _getDouble(eventMap, 'float', eventData.floatValue)
          ..stringValue = _getString(eventMap, 'string', eventData.stringValue);
        timeline.setFrame(frameIndex++, event);
      }
      timelines.add(timeline);
      duration =
          math.max(duration, timeline.frames[timeline.getFrameCount() - 1]);
    }

    if (duration.isNaN)
      throw StateError('Error while parsing animation, duration is NaN');

    skeletonData.animations.add(Animation(name, timelines, duration));
  }

  void readCurve(
      Map<String, dynamic> map, CurveTimeline timeline, int frameIndex) {
    if (!map.containsKey('curve')) return;
    if (map['curve'] == 'stepped')
      timeline.setStepped(frameIndex);
    else if (map['curve'] is List) {
      final Float32List curve = _getFloat32List(map, 'curve')!;
      timeline.setCurve(frameIndex, curve[0], curve[1], curve[2], curve[3]);
    }
  }

  static Float32List? _getFloat32List(Map<String, dynamic> map, String name) {
    if (!map.containsKey(name)) {
      return null;
    }
    final List<dynamic> values = map[name];
    final Float32List result = Float32List(values.length);
    for (int i = 0; i < values.length; i++) {
      result[i] = values[i].toDouble();
    }
    return result;
  }

  static Int16List? _getInt16List(Map<String, dynamic> map, String name) {
    if (!map.containsKey(name)) {
      return null;
    }

    final List<dynamic> values = map[name];
    final Int16List result = Int16List(values.length);
    for (int i = 0; i < values.length; i++) {
      result[i] = values[i].toInt();
    }
    return result;
  }

  static String _getString(Map<String, dynamic> map, String name,
          [String defaultValue = '']) =>
      map[name] is String ? map[name] : defaultValue;

  static double _getDouble(Map<String, dynamic> map, String name,
          [double defaultValue = 0.0]) =>
      map[name] is num ? map[name].toDouble() : defaultValue;

  static int _getInt(Map<String, dynamic> map, String name,
          [int defaultValue = 0]) =>
      map[name] is num ? map[name].toInt() : defaultValue;

  static bool _getBool(Map<String, dynamic> map, String name,
          [bool defaultValue = false]) =>
      map[name] is bool ? map[name] : defaultValue;

  static BlendMode blendModeFromString(String str) {
    str = str.toLowerCase();
    if (str == 'normal') return BlendMode.Normal;
    if (str == 'additive') return BlendMode.Additive;
    if (str == 'multiply') return BlendMode.Multiply;
    if (str == 'screen') return BlendMode.Screen;
    throw ArgumentError('Unknown blend mode: $str');
  }

  static PositionMode positionModeFromString(String str) {
    str = str.toLowerCase();
    if (str == 'fixed') return PositionMode.Fixed;
    if (str == 'percent') return PositionMode.Percent;
    throw ArgumentError('Unknown position mode: $str');
  }

  static SpacingMode spacingModeFromString(String str) {
    str = str.toLowerCase();
    if (str == 'length') return SpacingMode.Length;
    if (str == 'fixed') return SpacingMode.Fixed;
    if (str == 'percent') return SpacingMode.Percent;
    throw ArgumentError('Unknown position mode: $str');
  }

  static RotateMode rotateModeFromString(String str) {
    str = str.toLowerCase();
    if (str == 'tangent') return RotateMode.Tangent;
    if (str == 'chain') return RotateMode.Chain;
    if (str == 'chainscale') return RotateMode.ChainScale;
    throw ArgumentError('Unknown rotate mode: $str');
  }

  static TransformMode transformModeFromString(String str) {
    str = str.toLowerCase();
    if (str == 'normal') return TransformMode.Normal;
    if (str == 'onlytranslation') return TransformMode.OnlyTranslation;
    if (str == 'norotationorreflection')
      return TransformMode.NoRotationOrReflection;
    if (str == 'noscale') return TransformMode.NoScale;
    if (str == 'noscaleorreflection') return TransformMode.NoScaleOrReflection;
    throw ArgumentError('Unknown transform mode: $str');
  }
}

class LinkedMesh {
  String? parent, skin;
  int slotIndex;
  MeshAttachment mesh;

  LinkedMesh(this.mesh, this.skin, this.slotIndex, this.parent);
}
