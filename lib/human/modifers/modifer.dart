import 'package:makehuman/human/human/human.dart';
import 'package:makehuman/human/modifers/human.dart';
import 'package:makehuman/human/target/metadata.dart';
import 'package:makehuman/human/target/target.dart';

import '../target/targets.dart';

class Modifier{
  Modifier(this.groupName, this.name,[TargetMetaData? targetMetaData]){
    fullName = '$groupName/$name';
    this.targetMetaData = targetMetaData ?? TargetMetaData();
  }

  String groupName;
  String name;
  late String fullName;

  List<Targets> targets = [];
  String description = "";
  bool showMacroStats = false;

  // Macro variable controlled by this modifier
  var macroVariable = null;
  // Macro variables on which the targets controlled by this modifier depend
  var macroDependencies = [];

  var _symmModifier = null;
  double _symmSide = 0;

  late TargetMetaData targetMetaData;
  Human? human;
  double defaultValue = 0;
  int min = 0;
  int max = 1;

  String? left;
  String? right;
  String? mid;

  late Modifiers parent;

  double resetValue() {
    double oldVal = getValue()!.toDouble();
    setValue(defaultValue);
    return oldVal;
  }

  // Propagate modifier update to dependent modifiers
  propagateUpdate([bool realtime = false]) {
    List<String>? f = realtime?['macrodetails', 'macrodetails-universal']:null;

    final modifiersAffectedBy = parent.getModifiersAffectedBy(this, f)
        .map((dependentModifierGroup){
            // Only updating one modifier in a group should suffice to update the
            // targets affected by the entire group.
            final m = parent.getModifiersByGroup(dependentModifierGroup)[0];
            if (realtime) {
              return m.updateValue(m.getValue(), true);
            } 
            else {
              return m.setValue(m.getValue(), true);
            }
        });

    return modifiersAffectedBy;
  }

  double clampValue(double value) {
    return value.clamp(min, max).toDouble();
  }

  //Subclasses must override this
  List<String> getFactors([double value = 1]) {
    throw("NotImplemented");
  }

  //  * Gets modifier value from sum of own or given targets
  //  * @param  {Array} targets=this.targets - The targets to get values from
  //  * @return {Number}                     - sum of values from targets
  int? getValue([List<Target>? targets]) {
    this.targets ??= targets;
    int sum = 0;
    for (int i = 0; i < targets.length; i++) {
      final path = targets[i][0];
      Target? target = parent.human.targets.children[path];
      if (target == null) {
        // console.error('Target not found for modifier', path, this.name)
        throw AssertionError('Target not found for modifier $path $name');
      } 
      else {
        sum += target.value;
      }
    }

    // var targets = _.map(this.targets, target => this.parent.human.targets.children[target[0]])
    // return _.sum(_.map(targets,target=>target.value));
    return sum;
  }

  //  * Update the values of this modifers targets
  //  * @param  {Number} value            new value
  //  * @param  {Boolean} skipUpdate=false Flag to prevent infinite recursion
  updateValue(value, [bool skipUpdate = false]) {
    // Update detail state
    if (value != null) {
      setValue(value, true);
    }

    if (skipUpdate) {
      // Used for dependency updates (avoid dependency loops && double updates to human)
      return value;
    }

    // Update dependent modifiers
    return propagateUpdate(true); // realtime=true
  }

  //  * The side this modifier takes in a symmetric pair of two modifiers.
  //  * Returns 'l' for left, 'r' for right.
  //  * Returns null if symmetry does not apply to this modifier.
  String? getSymmetrySide([List<String>? path]) {
    path ??= name.split('-');
      if (path.contains('l')) {
        return 'l';
      } 
      else if (path.contains('r')) {
        return 'r';
      } 
      else {
        return null;
      }
  }

  String getSymmModifier([List<String>? path]) {
    path ??= name.split('-');
    return path.map((p){
        if (p == 'r'){ 
          return 'l';
        }
        else if (p == 'l'){ 
          return 'r';
        }
        else {
          return p;
        }
    }).join('-');
  }

  // Get name of the modifier which is symmetric to this one or null if there is none
  String? getSymmetricOpposite() {
    if (_symmModifier) {
      return '$groupName/$_symmModifier';
    } 
    else {
      return null;
    }
  }


  //  * Retrieve the other modifiers of the same type on the human.
  //  * @return {Array} Array of modifiers with the same class
  getSimilar() {
    // return [m for m in this.parent.getModifiersByType(this.type) if m != self]
    return parent.getModifiersByType(this).filter(m => m != this);
  }

  bool isMacro() {
    return macroVariable != null;
  }

  get leftLabel => (){return left != null? left?.split('-').last : '';};
  
  get rightLabel => () {
      return right != null? right?.split('-').length : '';
  };
  get midLabel => () {
      return mid != null? mid?.split('-').last : '';
  };
  get image => () {
      return 'data/targets/${fullName.replaceAll('/', '/images/').replaceAll('|', '-').toLowerCase()}.png';
  };
}