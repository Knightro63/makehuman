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
import 'package:makehuman/human/human/human.dart';
import '../../helpers/helpers.dart';

class HumanIO {
  HumanIO(this.human) {
    List<String> modifierFullNames = human.modifiers.children.keys.toList();
    modifierFullNames.sort();    
    shortenMapping = {
      'poseName': 'pn', 
      'skin': 's', 
      'modifiers': 'm', 
      'proxies': 'p', 
    };
    modifierFullNames.map((e){
      shortenMapping[e] = e;
    });
  }

  int rounding = 3;
  Human human;
  late Map<String,String> shortenMapping;

  toConfig() {
    return human.exportConfig();
  }

  void fromConfig(config) {
    human.importConfig(config);
  }

  Map<String,dynamic> toShortConfig([Map<String,dynamic>? config]) {
    config ??= human.exportConfig();
    config = Helper.remapKeyValuesDeep(config, shortenMapping, {});
    config = Helper.deepRoundValues(config,rounding);
    return config;
  }

  fromShortConfig(Map<String,String> sortConfig) {
    return Helper.remapKeyValuesDeep(sortConfig, Helper.invert(shortenMapping), {});
  }

  fromUrlQuery(Map<String,String> queryConfig) {
    final config = qs.parse(queryConfig);
    return Helper.deepParseFloat(Helper.remapKeyValuesDeep(config, Helper.invert(shortenMapping), {}));
  }

  /* transforms the config to a smaller url query **/
  toUrlQuery([config, bool encode = true]) {
    config ??= human.exportConfig();
    config = Helper.remapKeyValuesDeep(config, shortenMapping, {});
    config = Helper.deepRoundValues(config, rounding);
    final queryConfig = qs.stringify(config, { encode });
    if (queryConfig.length < 2048) {
      throw('url config should be shorter than 2048 chars');
    }
    return queryConfig;
  }

  String toUrl([config, bool encode = true]) {
    config ??= human.exportConfig();
    return '${window.location.origin}?${toUrlQuery(config, encode)}';
  }

  fromUrl([String? url]) {
    url ??= window.location.toString();
    final parser = document.createElement('a');
    parser.href = url;
    final config = fromUrlQuery(parser.search.slice(1));
    human.importConfig(config);
    return config;
  }

  /**
   * Export the human mesh with morphs but not pose, skin, or accessories.
   * @param {bool} helpers - if true it strips the helper meshes like hair-helper.
   * @return {string} Wavefront obj file compatible with blender
   */
  toObj([bool helpers=false]) {
      // const self = this
      final objExporter = OBJExporter();

      final mesh = this.human.mesh.clone();
      mesh.geometry = mesh.geometry.clone();

      mesh.name = 'makehuman_1.1-${DateTime.now()}';

      // unmask vertices under clothes
      final nullMaterial = mesh.material.materials.findIndex(m => m.name == "maskedFaces");
      mesh.geometry.faces.forEach((f, i) => {
          if (f.materialIndex == nullMaterial) {
              f.materialIndex = this.human.mesh.geometry.faces[i].oldMaterialIndex
          }
      });

      if (!helpers) {
          /* Makehuman has a human body mesh, then it has some invisible meshes attached to it.
            * These are hair-helper, dress-helpers etc which invisible extensions to the human body 
            * used to attach clothes or hair to. When the human is morphed so are the helpers,
            * ensuring that the clothes fit the morphed human. 
            * If the helper option is not selected, lets remove the helper vertices.
            */
          final geom = mesh.geometry;

          // delete unused, uvs, faces, and vertices
          geom.faceVertexUvs = geom.faceVertexUvs.filter((uv, i) => geom.faces[i].materialIndex === 0)
          geom.faces = geom.faces.filter(f => f.materialIndex === 0)

          // TODO remove unused vertices without breaking the obj
          const verticesToKeep = _.sortBy(_.uniq(_.concat(
              ...geom.faces.filter(f => f.materialIndex === 0)
              .map(f => [f.a, f.b, f.c])
          )))
          geom.vertices = geom.vertices.filter((v, i) => verticesToKeep.includes(i))
          geom.faces.forEach((f) => {
              f.a = verticesToKeep.indexOf(f.a)
              f.b = verticesToKeep.indexOf(f.b)
              f.c = verticesToKeep.indexOf(f.c)
          })
      }

      String obj = objExporter.parse(mesh);
      // don't export vertex normals
      obj = obj.split('\n').filter(line => !line.startsWith('vn ')).join('\n');

      // header data
      final jsonMetadata = jsonEncode(this.human.metadata, null, 4).replaceAll('\n', '\n#');
      final header = '# Exported from makehuman js on ${DateTime.now()}\n#Source metadata:\n#$jsonMetadata\n';

      return header + obj;
  }
}