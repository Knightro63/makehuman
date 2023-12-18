import 'package:flutter_gl/native-array/index.dart';
import 'package:makehuman/human/human/human.dart';
import 'package:three_dart/three3d/three.dart';
import 'package:three_dart/three_dart.dart' as three;
import 'metadata.dart';

class Targets extends TargetMetaData {
  Targets(this.human):super(){
    lastBake = DateTime.now().millisecondsSinceEpoch;

    // for loading
    manager = three.LoadingManager();
    this.bufferLoader = three.XHRLoader(manager);
    this.bufferLoader.setResponseType('arraybuffer');
  }

  late Human human;
  late int lastBake;
  Map<String,dynamic> children = {};
  bool loading = false;
  late three.LoadingManager manager;
  Float32BufferAttribute referenceVertices;
  List<num>? lastmorphTargetInfluences;

  //  * load all from a single file describing sparse data
  //  * @param  {String} url  - url to bin file containing Int16 array
  //  *                       nb_targets*nb_vertices*3 in length
  //  * @return {Promise}     promise of an array of targets
  load([String dataUrl = 'data/targets/targets.bin']) {
      final self = this;
      loading = true;

      final targets = [];//Float32BufferAttribute(Float32Array.from(shape.vertices), 3));

      referenceVertices = human.mesh?.geometry?.attributes['position'];// .vertices.map(v => v.clone());

      final paths = targetIndex.map(t => t.path);
      paths.sort();
      human.morphTargetDictionary = paths.reduce((a, p, i) => { a[p] = i; return a }, {});
      targetIndex.map(t => t.path).map((path) => {
          const config = self.pathToGroupAndCategories(path)
          const target = Target(config)
          targets.push(target)
          target.parent = self
          self.children[target.name] = target
          return target
      });

      self.human.morphTargetInfluences = Float32Array(paths.length);

      return Promise((resolve, reject) => self.bufferLoader.load(dataUrl, resolve, undefined, reject))
      .then((data) => {
          self.targetData = Int16Array(data)
          const loadedTargets = self.human.targets.targetData.length / 3 / self.human.mesh.geometry.vertices.length
          console.assert(
              self.targetData.length % (3 * self.human.mesh.geometry.vertices.length) === 0,
              'targets should be a multiple of nb_vertices*3'
          )
          console.assert(
              loadedTargets === Object.keys(self.children).length,
              "length of target data doesn't match nb_targets*nb_vertices*3"
          )
          console.debug(
              'loaded targets',
              loadedTargets
          )
          self.loading = false
          return self.targetData
      })
      .catch((err) => {
          self.loading = false
          throw (err)
      });
  }


  //  * Updated vertices from applied targets. Should be called on render since it
  //  * will only run if it's needed and more than a second has passed
  bool applyTargets() {
    // skip if it hasn't been rendered
    if (human != null||
      human.mesh != null ||
      human.mesh?.geometry != null||
      targetData != null
    ) return false;

    // skip if less than a second since last
    if ((DateTime.now().millisecondsSinceEpoch - lastBake) < this.human.minUpdateInterval){ 
      return false;
    }

    // check if it'schanged
    if (lastmorphTargetInfluences == human.morphTargetInfluences){// _.isEqual(this.lastmorphTargetInfluences, this.human.morphTargetInfluences)){ 
      return false;
    }

    // let [m,n] =  this.targetData.size
    final m = human.geometry?.attributes['position'].length;
    final n = human.morphTargetInfluences?.length;
    final dVert = Float32Array(m);

    // What is targetData? It's all the makehuman targets, (ordered alphebetically by target path)
    // put in an nb_targets X nb_vertices*3 array as Int16 then flattened written as bytes to a file.
    //  We then load it as a binary buffer and load it into a javascript Int16 array.
    // Now we can calculate vertices by doing a dotproduct of
    //     $morphTargetInfluences \cdot targetData *1e-3 $
    // with shapes
    //     $(nb_targets) \cdot (nb_target,nb_vertices*3) *1e-3 $
    // where 1e-3 is the scaling factor to convert from Int16
    // The upside is that the amount of data doesn't crash the browser like
    // json, msgpack etc do. It's also relativly fast and bypasses threejs
    // limit on the number of morphtargets you can have.

    print(this.targetData.length == m * n, `target data should be nb_targets*nb_vertices*3: ${m * n}`);
    print(_.sum(this.targetData.slice(3 * m, 4 * m)) === 2952);

    // do the dot product over a flat targetData
    for (int j = 0; j < n; j += 1) {
      for (int i = 0; i < m; i += 1) {
        if (human.morphTargetInfluences[j] != 0 && this.targetData[i + j * m] != 0) {
          dVert[i] += this.targetData[i + j * m] * this.human.morphTargetInfluences[j];
        }
      }
    }

    // update the vertices
    final vertices = referenceVertices.array.toDartList();//.map(v => v.clone());
    for (int i = 0; i < vertices.length; i += 1) {
      vertices.addAll([dVert[i * 3] * 1e-3,dVert[i * 3 + 1] * 1e-3,dVert[i * 3 + 2] * 1e-3]);
    }
    human.geometry?.setAttribute('position', Float32BufferAttribute(Float32Array.from(vertices), 3));

    // this.human.mesh.geometry.verticesNeedUpdate = true;
    human.mesh?.geometry?.elementsNeedUpdate = true;
    lastmorphTargetInfluences = human.morphTargetInfluences;
    lastBake = DateTime.now();

    return true;
  }
}
