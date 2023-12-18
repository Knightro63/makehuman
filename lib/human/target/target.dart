import 'package:makehuman/human/target/targets.dart';

class Target {
  Target(config){
    name = config.path;
    // this.parent = null; // prob just a tmp var from mh file warlking
    path = config.path;
    group = config.group;

    // meta categories which each key part belongs to
    categories = config.categories;
    variables = config.variables;
    macroVariables = config.macroVariables;
  }

  late Targets parent;
  late String name;
  // this.parent = null; // prob just a tmp var from mh file warlking
  late String path;
  late String group;

  // meta categories which each key part belongs to
  late Map<String,dynamic> categories;
  late variables;
  late macroVariables;


  // The variables that apply to this target component.
  List<String> getVariables() {
    // filter out null values then grab the keys of the remaining properties
    categories.removeWhere((key, value) => value == null);
    return categories.keys.toList();//_.keys(_.pickBy(categories, _.isTrue));
  }


  // put this targets current value into the threejs mesh's influence array
  set value(val) {
    final i = parent.human.morphTargetDictionary?[name];
    parent.human.morphTargetInfluences?[i] = val;
  }

  // Get target's value from where threejs stores it
  num? get value(){
    final i = parent.human.morphTargetDictionary?[name];
    return parent.human.morphTargetInfluences?[i];
  }
}