/**
 * @name            MakeHuman
 * @copyright       MakeHuman Team 2001-2016
 * @license         [AGPL3]{@link http://www.makehuman.org/license.php}
 * @author          wassname
 * @description
 * Describes human class which holds the 3d mesh, modifiers, human factors,
 * and morphTargets.
 */
import 'package:makehuman/human/human/base.dart';
import 'package:makehuman/human/human/io.dart';
import '../target/targets.dart';
import '../modifers/human.dart';
import '../proxy.dart';
import '../ethnic_skin_blender.dart';
import '../factors.dart';
import 'package:flutter/services.dart' show rootBundle;

/**
 * Extends BaseHuman to have targets and modifiers to manage them
 */
class Human extends BaseHuman {
  Human(config):super(config){
    modifiers = Modifiers(this);
    factors = Factors(this);
    targets = Targets(this);
    proxies = Proxies(this);
    ethnicSkinBlender = EthnicSkinBlender(this);
    io = HumanIO(this);

    onBeforeRender = (){
      onBeforeRender?.call();
      _onBeforeRender();
    };
  }

  List<String> bodyZones = ['l-eye', 'r-eye', 'jaw', 'nose', 'mouth', 'head',
    'neck', 'torso', 'hip', 'pelvis', 'r-upperarm', 'l-upperarm',
    'r-lowerarm', 'l-lowerarm', 'l-hand', 'r-hand', 'r-upperleg',
    'l-upperleg', 'r-lowerleg', 'l-lowerleg', 'l-foot', 'r-foot', 'ear'
  ];
  // a modular container for modifiers such as age, left-arm length etc
  late Modifiers modifiers;

  // a modular object with human factors and their getters and setters,
  //  e.g. age, weight, ageInYears
  late Factors factors;

  // holds loaded targets, target metadata, and target related methods
  late Targets targets;

  late Proxies proxies;
  late EthnicSkinBlender ethnicSkinBlender;
  late HumanIO io;

  void updateHeight() {
    // TODO update position, by reading bone world position, or buffer geom?
    // let position = this.mesh.geometry._bufferGeometry.attributes.position.array
    // let ys=[]
    // for (let i=0;i<position.length;i+=3){
    //     ys.push(position[i])
    // }
    // let miny = _.min(ys)
    // this.position.y=miny
    //
    // Use joint ground, get face group that corresponds, then get vertices for the faces, then get mean y?
    // no the ground join is just between the feet, it doesn't seem to help us
  }

  bool updateSkinColor() {
    final defaultSkin = ;//this._skinCache["data/skins/young_caucasian_female/young_caucasian_female.json"];
    if (defaultSkin) {
      return defaultSkin.color = this.ethnicSkinBlender.valueOf();
    } 
    else {
      return false;
    }
  }

  /** Call when vertices/element change **/
  @override
  void onElementsNeedUpdate() {
    super.onElementsNeedUpdate();
    updateJointPositions();
    proxies.onElementsNeedUpdate();
    updateSkinColor();
    mesh?.geometry?.computeVertexNormals();
  }

  /** Call before render **/
  void _onBeforeRender() {
    TWEEN.update();
    targets.applyTargets();
    if (mesh != null && mesh!.geometry != null && mesh!.geometry!.elementsNeedUpdate) {
      onElementsNeedUpdate();
    }
  }

  @override
  Map<String, dynamic> exportConfig() {
    // TODO, no need to export modifiers with default values or skin etc
    final json = super.exportConfig();
    json['proxies'] = proxies.exportConfig();
    json['modifiers'] = modifiers.exportConfig();
    return json;
  }

  @override
  void importConfig(json) {
    // json = _.defaults(json, { modifiers: [], proxies: [] })
    super.importConfig(json);
    if (json['proxies'] != null){
      proxies.importConfig(json.proxies);
    }
    if (json['modifiers'] != null){
      modifiers.importConfig(json.modifiers);
    }
  }
}
