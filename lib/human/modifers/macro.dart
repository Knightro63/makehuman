import '../target/targets.dart';
import 'target.dart';

// * Modifiers that control many other modifiers instead of controlling target weights directly
class MacroModifier extends ManagedTargetModifier {
  MacroModifier(groupName, name):super(groupName, name){
    defaultValue = 0.5;
    setter = 'set${this.name}';
    getter = 'get${this.name}';

    targets = targetMetaData.findTargets(this.groupName);

    // console.debug('macro modifier %s.%s(%s): %s', base, name, variable, this.targets)

    macroDependencies = findMacroDependencies(this.groupName);

    macroVariable = _getMacroVariable(this.name);

    // Macro modifier is not dependent on variable it controls itself
    if (macroVariable) {
      macroDependencies.remove(macroVariable);
    }
  }

  late String setter;
  late String getter;

  /** The macro variable modified by this modifier. **/
  String? _getMacroVariable([String? name]) {
    name ??= this.name;
    if (name != null) {
      String variable = name.toLowerCase();
      if (targetMetaData.categoryTargets[variable]) {
        return variable;
      } 
      else if (targetMetaData.targetCategories[variable]) {
        // necessary for caucasian, asian, african
        return targetMetaData.targetCategories[variable];
      }
    } 
    else {
      return null;
    }
  }

  @override
  int? getValue([List<Target>? targets]) {
    return parent.human.factors[getter]();
  }

  @override
  void setValue(double value, [bool skipDependencies = false]) {
    value = clampValue(value);
    parent.human.factors[setter](value, false);
    super.setValue(value, skipDependencies);
  }

  @override
  List<String> getFactors([double value = 1]) {
    List<String> factors = super.getFactors(value);
    factors[this.groupName] = 1.0;
    return factors;
  }

  // buildLists() {
  //     return;
  // }
}