/**
 * @name            MakeHuman
 * @copyright       MakeHuman Team 2001-2016
 * @license         [AGPL3]{@link http://www.makehuman.org/license.php}
 * @author          wassname
 * @description
 * Describes human class which holds the 3d mesh, modifiers, human factors,
 * and morphTargets.
 */
import 'dart:convert';
import 'package:makehuman/human/human/config.dart';
import 'package:three_dart/three_dart.dart' as three;

/**
 * Basic human with method to load base mash, skins, and config
 * @type {Class}
 */
class BaseHuman extends three.Object3D {
  BaseHuman(this.config):super(){
    poses = config.poses;

    // TODO undo this hardcoding
    // this.skeleton_metadata = skeleton_metadata
    this._poseTweens = []
    this._skinCache = {}

    // this.mixer = three.AnimationMixer(this);
    manager.onLoad = onLoadComplete.bind(this);
    materialLoader = three.MaterialLoader(manager);
  }

  Config config;
  three.Mesh? mesh;
  late List<> poses;
  late List<> skins;
  //List<> proxies;
  int minUpdateInterval = 1000;
  late three.MaterialLoader materialLoader;
  three.LoadingManager manager = three.LoadingManager();

    /**
     * Loads body from config
     * @return {Promise}                - promise of loaded human
     */
    loadModel() {
      BaseHuman self = this;
      Config config = this.config;

      // HUMAN
      // Load the geometry data from a url
      this.loader = three.XHRLoader(this.manager);
      String modelUrl = '${config.baseUrl}models/${config.model}';
      return Promise((resolve, reject) => {
        try {
          self.loader.load(modelUrl,resolve,undefined,reject);
        } 
        catch (e) {
          reject(e)
        }
      }).catch((err) => {
                console.error('Failed to load model data', modelUrl, err)
                throw err
            }).then(text =>
                JSON.parse(text)
            ).then((json) => {
                self.metadata = json.metadata
                const texturePath = self.texturePath && (typeof self.texturePath === "string") ? self.texturePath : three.Loader.prototype.extractUrlBase(modelUrl)

                return three.JSONLoader().parse(json, texturePath)
            })
            // use unpacking here to turn one args into two, as promises only return one
            .then(({
                geometry,
                materials
            }) => {
                self.geometry = geometry

                geometry.computeBoundingBox()
                // geometry.computeVertexNormals()
                geometry.name = config.character

                materials.map(m => (m.morphTargets = true))
                materials.map(m => (m.skinning = true))

                // add a null material, and backup face materialIndexes
                geometry.faces.map(face => (face.oldMaterialIndex = face.materialIndex))
                materials.push(three.MeshBasicMaterial({ visible: false, name: 'maskedFaces' }))

                // load multiple materials, to group helper faces using materials http://stackoverflow.com/questions/11025307/can-i-hide-faces-of-a-mesh-in-three-js
                self.mesh = three.SkinnedMesh(geometry, three.MultiMaterial(materials))
                self.mesh.name = config.character
                self.add(self.mesh)

                this.skeleton = this.mesh.skeleton

                self.scale.set(config.s, config.s, config.s)

                self.mesh.geometry.computeBoundingBox()
                const halfHeight = self.mesh.geometry.boundingBox.getSize().y / 2
                self.position.set(config.x, config.y + halfHeight, config.z)

                self.mesh.castShadow = true
                self.mesh.receiveShadow = true


                self.mesh.geometry.computeVertexNormals()

                self.updateJointPositions()

                // hide the helper parts
                self.bodyPartOpacity(0)
                return self.setSkin(config.defaultSkin)
                    .then(() => self)
            });
    }

    /**
     * Load targets from .target urls
     * @param  {String}      dataUrl    Url of the targt binary
     * @return {Promise}                Promise of an array of targets
     */
    loadTargets([String? dataUrl]){
      dataUrl = dataUrl??'${config.baseUrl}$targets/${config.targets}';
      return targets.load(dataUrl).then(targets => targets);
    }

    onLoadComplete() {}

    /**
     * This sets the opacity of parts of the body.
     * With name given arguments it sets all helpers and joints
     * If no arguments are given it lists helper names.
     * @param  {Number} opacity - Set opacity of the helper/s to this
     * @param  {String} name    - Optional helper, otherwise all helpers are set
     * @return {Number}         - Amount of helper opacities set
     */
    bodyPartOpacity([double? opacity, String? name]) {
      let parts;

      // return lists of parts
      if (opacity != null) {
        return this.mesh.material.materials.map(m => m.name);
      }

      bool helpersAndJoints = this.mesh.material.materials.filter(m => typeof m.name == 'string' &&
              (m.name.startsWith('joint') || m.name.startsWith('helper')));

      if(name != null) {
        parts = this.mesh.material.materials.filter(m => m.name == name);
      } 
      else {
        parts = helpersAndJoints;
      }
      for (int i = 0; i < parts.length; i++) {
        // no point in rendering it at 0 opacity
        if (opacity == 0) {
          parts[i].visible = false;
        } 
        else { 
          parts[i].visible = true;
        }
        parts[i].opacity = opacity;
        parts[i].transparent = opacity < 1;
      }
      return parts.length;
    }

    /** Set this bodies texture map from a loaded skin material **/
    setSkin(String? url) {
      url ??= config.defaultSkin;
        const base = `${this.config.baseUrl}skins/`
        if (!url.startsWith(base)) {
            url = `${this.config.baseUrl}skins/${url}`
        }
        return Promise.resolve().then(() => {
            if (this._skinCache[url]) {
                return this._skinCache[url]
            } else {
                return Promise((resolve, reject) => {
                    this.loader.load(url, resolve, undefined, reject)
                })
                .then((text) => {
                    const json = JSON.parse(text)
                    const texturePath = self.texturePath &&
                        (typeof self.texturePath === "string") ?
                            self.texturePath :
                            three.Loader.prototype.extractUrlBase(url)
                    return three.Loader().createMaterial(json, texturePath)
                })
                .then((material) => {
                    this._skinCache[url] = material
                    material.name = url.split('/').slice(-1)[0].split('.')[0]
                    material.skinning = true
                    return material
                })
            }
        })
        .then((material) => {
            if (this.mesh && this.mesh.material.materials) {
                return this.mesh.material.materials[0] = material
            } else {
                return false
            }
        })
    }

    /**
     *  Calculate the position of specified named joint from the current
     *  state of the human mesh. If this skeleton contains no vertex mapping
     *  for that joint name, it falls back to looking for a vertex group in the
     *  human basemesh with that joint name.
     * @type {String} - bone name e.g. head
     */
    three.Vector3? getJointPosition(boneName, [bool head = false]) {
        // TODO if inRest then get geom, else buffer geom
        if (boneName && boneName.indexOf('____head') == -1 && boneName.indexOf('____tail') == -1) { 
          boneName += head ? '____head' : '____tail';
        }
        // let bone_id = _.findIndex(this.skeleton.bones, bone=>bone.name==boneName)
        const vertices = this.metadata.joint_pos_idxs[boneName];
        if (vertices) {
            const positions = vertices
                .map(vId => this.mesh.geometry.vertices[vId].clone());

            return three.Vector3(
                _.mean(positions.map(v => v.x)),
                _.mean(positions.map(v => v.y)),
                _.mean(positions.map(v => v.z))
            );
        } else {
            return null;
        }
    }

    /**
     * We move bones towards the vertices they are weighted to, adjusting for
     * change in mesh size
     * See makehumans shared/skeleton.py:Skeleton:updateJointPositions
     */
    updateJointPositions() {
        three.Skeleton skeleton = this.skeleton;
        BaseHuman self = this;
        three.Matrix4 identity = three.Matrix4().identity();

        // undo pose, while we do this
        final poseName = _poseName;
        setPose();

        // get positions of reference vertices
        // first get positions of bones, as we don't want changes to propogate to the mesh then to the skeleton
        const positions = skeleton.bones.map((bone) => {
            const vTail = this.getJointPosition(bone.name, false, true)
            const vHead = this.getJointPosition(bone.parent.name, false, true)
            if (vTail && vHead) {
                return vTail.clone().sub(vHead)
            }
            if (vTail) {
                return vTail
            } else {
                console.warn(`couldn't update ${bone.name} because no weights or group for ${vTail ? bone.name : bone.parent.name}`)
                return null
            }
        })

        // now update referenceMatrix
        for (int i = 0; i < skeleton.bones.length; i++) {
            const boneInverse = three.Matrix4()
            const bone = skeleton.bones[i]
            const parentIndex = _.findIndex(skeleton.bones, b => b.name === bone.parent.name)
            const parent = skeleton.bones[parentIndex]
            const position = positions[i]

            if (position) {
                bone.position.set(position.x, position.y, position.z)
                bone.updateMatrixWorld()

                if (i > 0) {
                    boneInverse.getInverse(parent.matrixWorld)
                        .multiply(bone.matrixWorld)
                    // subtract parents
                    for (let j = 0; j < boneInverse.elements.length; j++) {
                        boneInverse.elements[j] = skeleton.boneInverses[parentIndex].elements[j] - boneInverse.elements[j] + identity.elements[j]
                    }
                } else {
                    boneInverse
                        .getInverse(bone.matrixWorld).multiply(self.matrixWorld)
                }

                // TODO make into test, it shouldn't change boneInverses on initial load with no pose
                // let diffs =_.zipWith(
                //     boneInverse.elements,
                //     self.mesh.skeleton.boneInverses[i].elements,
                //     (a,b)=>a-b
                // )
                // console.assert(
                //     diffs.filter(d=>d>0.001) .length==0,'in pose position these should be equal '+bone.name+' '+diffs
                // )
                skeleton.boneInverses[i] = boneInverse
            }
        }
        // FIXME there should be a way of doing this without actually changing bone positions, the rePosing but it works for now
        self.setPose(poseName)
    }


  setPose(poseName, [int interval = 0]) {
    // TODO, load each from json like a proxy
    const pose = this.poses[poseName]
    const self = this
    if (pose) {
        this._poseName = poseName
        self._poseTweens.map((tween) => { return tween ? tween.stop() : '' })
        self._poseTweens = Object.keys(pose).map((boneName) => {
            const bone = this.mesh.skeleton.bones.find(b => b.name === boneName)
            if (!bone) {
                console.error('couldnt find bone', boneName)
                return null
            }
            // Tween the pose
            const data = pose[bone.name]
            if (!interval) {
                // skip the tween at interval zero
                // we apply the rotation to the one above it (the head), since it modifies the one after
                bone.parent.quaternion.set(...data)
                return null
            } else {
                const qBefore = bone.parent.quaternion.clone()
                const qAfter = three.Quaternion().set(...data)
                const t = 0
                return TWEEN.Tween(t)
                .to(1, interval)
                .onUpdate((ti) => {
                    three.Quaternion.slerp(qBefore, qAfter, bone.parent.quaternion, ti)
                })
                .start()
            }
        })
    } 
    else {
      mesh?.pose();
      this._poseName = null;
    }
    // this.updateHeight()
  }

  onElementsNeedUpdate() {}

  Map<String,dynamic> exportConfig() {
    // consider doing bodyPartOpacity, consider using this.toJSON
    // also consifer exporting config althoug we might need to reload human then
    final json = {
      'skin': mesh?.material.materials[0].name,
      'poseName': this._poseName
    };
    return json;
  }

  void importConfig(json) {
    if (json.skin) {
      setSkin(json.skin);
    }
    if (json.poseName) {
      setPose(json.poseName);
    }
  }
}