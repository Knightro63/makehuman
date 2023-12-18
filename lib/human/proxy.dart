import 'dart:async';

import 'package:three_dart/three_dart.dart' as three;
import 'human.dart';


//  * parseProxyUrl
//  * @param  {String} url - e.g. "data/proxies/clothes/Bikini/Bikini.json#blue"
//  * @return {Object}     - e.g. {group:"clothes",name:"Bikini",file:"bikini.json", materialName:"blue"}


Map<String,String> parseProxyUrl(String address){
    if (!address.contains('#')) address += '#';
    List<String?> links = address.split('#');
    String fullUrl = links[0]!;
    String? materialName = links[1];
    //const [, , group, name, file] = fullUrl.match(/(.+\/)*(.+)\/(.+)\/(.+)\.json/);
    List<String> matches = fullUrl.split('/');
    int len = matches.length;
    String file = matches[len-1];
    String name = matches[len-2];
    String group = matches[len-3];

    String key = '$group/$name/$file.json${materialName ==null? '#$materialName' : ''}';
    String thumbnail = '$group/$name/${materialName ?? file}.thumb.png';

    return { 
      'group':group, 
      'name':name, 
      'key':key, 
      'materialName': materialName ?? '', 
      'thumbnail':thumbnail
    };
}

class Proxy extends three.Object3D {
  Proxy(this.url, this.human, [three.LoadingManager? manager]):super(){
    visible = false;
    this.manager = manager ?? three.LoadingManager();
    loader = three.FileLoader(this.manager);
    url = '${human.config.baseUrl}proxies/$key';

    final proxy = parseProxyUrl(url);
    name = proxy['name']!;
    group = proxy['group']!;
    materialName = proxy['materialName']!; 
    key = proxy['key']!;
    thumbnail = proxy['thumbnail']!;
  }

  Human human;
  late three.FileLoader loader;
  List<double> extraGeometryScaling = [1.0, 1.0, 1.0];
  Map<String,dynamic> metadata = {};
  three.Mesh? mesh;
  three.LoadingManager manager = three.LoadingManager();

  late String key;
  String url;
  late String group;
  late String thumbnail;
  late String materialName;

    /** load a proxy from threejs json file, making it a child object and giving it the same skeleton **/
    Future<> load() async{
      Completer c = Completer();
        Proxy self = this;
        if(mesh != null){ 
          return Promise.resolve(mesh);
        }

        try {
          mesh = ;
        } catch (e) {
          print(e);
        }
            await self.loader.loadAsync(self.url).catch((err) => {
                print('Failed to load proxy data ${self.url}\n$err');
            })
            .then(JSON.parse(text))
            .then((json) => {
                self.metadata = json.metadata
                const texturePath = self.texturePath &&
                    (typeof self.texturePath == 'string') ?
                        self.texturePath :
                        three.Loader.prototype.extractUrlBase(self.url);
                return new three.JSONLoader().parse(json, texturePath);
            })
            // use unpacking here to turn one args into two, as promises only return one
            .then(({
                geometry,
                materials
            }) => {
                geometry.name = self.url
                materials.map(m => (m.skinning = true))

                const mesh = new three.SkinnedMesh(geometry, new three.MultiMaterial(materials))

                // TODO check they are the same skeletons
                mesh.children.pop() // pop existing skeleton
                mesh.skeleton = self.human.skeleton

                mesh.castShadow = true
                mesh.receiveShadow = true

                self.mesh = mesh
                self.mesh.geometry.computeVertexNormals()
                self.add(mesh)

                // when it overlaps with body, show proxy (body has 0, we want higher ints)
                mesh.renderOrder = self.metadata.z_depth

                self.updatePositions()

                // change it to use the material specified in the url hash
                if (self.materialName) {
                    const materialIndex = _.findIndex(materials, material => material.name === self.materialName)
                    self.changeMaterial(materialIndex)
                }

                return mesh
            })

      return c.future;
    }

    // Turn mesh on or off, loading if needed
    bool toggle([bool? state]) {
      state ??= !visible;
      if (visible == state){ 
        return Promise.resolve(this);
      }
      visible = state;
      let promisedMesh;
      if (!state){
        promisedMesh = Promise.resolve();
      }
      else{ 
        promisedMesh = load().then(() => updatePositions());
      }
      return promisedMesh.then(() => human.proxies.updateFaceMask());
    }


    //  * This recalculates the coords of the proxy using the vertice inds, weights, and offsets
    //  * like in makehumans's proxy.py:Proxy.getCoords()
    updatePositions() {
        // TODO faster to do this in the gpu
        // equation = vertice = w0 * v0 + w1 * v1 + w2*v2 + offset, where w0 = weights[i][0], v0 = ref_verts_i[0]
        if (!this.visible || !this.mesh) return null
        const o = this.metadata.offsets
        const w = this.metadata.weights
        const v = this.metadata.ref_vIdxs
            .map(row =>
                row.map(vIndx => this.human.mesh.geometry.vertices[vIndx])
            )

        // convert this.matrix to Matrix3
        const mw = this.matrix.elements
        const matrix = new three.Matrix3()
        matrix.set(mw[0], mw[1], mw[2], mw[4], mw[5], mw[6], mw[8], mw[9], mw[10]).transpose()
        const m = matrix.elements

        for (let i = 0; i < this.mesh.geometry.vertices.length; i++) {
            // xyz offsets calculated as dot(matrix, offsets)
            const vertice = new three.Vector3(
                o[i][0] * m[0] + o[i][1] * m[1] + o[i][2] * m[2],
                o[i][0] * m[3] + o[i][1] * m[4] + o[i][2] * m[5],
                o[i][0] * m[6] + o[i][1] * m[7] + o[i][2] * m[8]
            )

            // Three weights to three vectors
            for (let j = 0; j < 3; j++) {
                vertice.x += w[i][j] * v[i][j].x
                vertice.y += w[i][j] * v[i][j].y
                vertice.z += w[i][j] * v[i][j].z
            }
            this.mesh.geometry.vertices[i] = vertice
        }
        this.mesh.geometry.scale(...this.extraGeometryScaling)
        this.mesh.geometry.verticesNeedUpdate = true
        this.mesh.geometry.elementsNeedUpdate = true
        return this.mesh.geometry.vertices
    }

  bool changeMaterial(i) {
    if(i > mesh!.material['materials'].length){ 
      return mesh!.material['materials'].length;
    }
    mesh!.geometry.faces.map(face => (face.materialIndex = i));
    mesh!.geometry!.groupsNeedUpdate = true;
    return true;
  }

  preRender() {

  }

  @override
  void onAfterRender(three.Camera? camera, dynamic geometry, dynamic group, dynamic material, three.WebGLRenderer? renderer, dynamic scene) {
    super.onAfterRender();
  }
}


/**
 * Container for proxies
 */
class Proxies extends three.Object3D {
  Proxies(this.human):super(){
    // init an object for each proxy but don't load untill needed
    human.config.proxies
      .map((url) => Proxy('${human.config.baseUrl}proxies/$url', human))
      .map((proxy) => add(proxy));
  }

  Human human;
  Map _cache = {};

    /**
     * Toggles or sets a proxy
     * params:
     *   key {String} the url for the proxy  (relative to baseUrl) e.g. eyes/Low-Poly/Low-Poly.json#brown
     *   state {Boolean|undefined} set the proxy on or off or if undefined toggle it
     * returns a promise to load the mesh
     */
    toggleProxy(key, state) {
        // try to find an existing proxy with this key
        Proxy? proxy = _.find(this.human.proxies.children, p => p.url === key) ||
            _.find(this.human.proxies.children, p => p.key === key) ||
            _.find(this.human.proxies.children, p => p.name === key)
        // or init a new one
        if(proxy == null) {
            print('Could not find proxy with key $key');
            // throw new Error(`Could not find loaded proxy to toggle with key: ${key}`)
            proxy = Proxy('${human.config.baseUrl}proxies/$key', human);
            add(proxy);
        } 
        else {
          print('toggleProxy: ${proxy.url} , $state');
        }
        return proxy.toggle(state);
    }

    updatePositions() {
      children.forEach((child) => child.updatePositions());//.forEach(child )
    }

    /** Make faces to hide parts under clothes, see makehuman/plugins/3_libraries_clothes_choose.py:updateFaceMasks **/
    updateFaceMask(minMaskedVertsPerFace = 3) {
        // get deleted vertices from all active proxies
        const deleteVerts = this.children
            .filter(proxy =>
                proxy.visible &&
                proxy.mesh &&
                proxy.metadata.deleteVerts &&
                proxy.metadata.deleteVerts.length
             )
            .map(proxy => proxy.metadata.deleteVerts)
        const nbVertices = this.human.mesh.geometry.vertices.length;
        const nullMaterial = this.human.mesh.material.materials.findIndex(m => m.name === 'maskedFaces');

        // for each vertice, see if any proxy wants to delete it
        List dv = Array(nbVertices);
        for (int i = 0; i < dv.length; i++) {
          dv[i] = _.sum(deleteVerts.map(vs => vs[i])) > 0
        }

        // if more than n vertices of a face are masked, mask the face else unmask
        human.mesh!.geometry.faces.map((face) => {
            if ((dv[face.a] + dv[face.b] + dv[face.c]) >= minMaskedVertsPerFace) {
                face.materialIndex = nullMaterial
            } else {
                face.materialIndex = face.oldMaterialIndex
            }
            return face.materialIndex;
        });
        human.mesh!.geometry!.groupsNeedUpdate = true;

        const facesMasked = human.mesh.geometry.faces
        .where((face) => face.materialIndex == nullMaterial).length;

        print('vertices masked ${dv.}', _.sum(dv));
        print('faces masked: $facesMasked', );
    }

  onElementsNeedUpdate() {
    updatePositions();
    children
    .where((proxy) => proxy.visible && proxy.mesh)
    .map((proxy) => proxy.mesh.geometry.computeVertexNormals());
  }

  exportConfig() {
    return children.where((p) => p.visible).map((p) => p.url);
  }

  importConfig(config) {
    children.map((p) => (p.visible = false));
    updateFaceMask();
    return config.map((url) => toggleProxy(url, true));
  }
}
