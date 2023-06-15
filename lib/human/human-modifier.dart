import 'targets.dart';
import 'human.dart';
import 'factors.dart';
import 'makehuman-data/src/json/modifiers/modeling_modifiers.json';
import 'makehuman-data/src/json/modifiers/measurement_modifiers.json';

class Modifier {
  Modifier(this.groupName, this.name,[TargetMetaData? targetMetaData]){
    fullName = '$groupName/$name';
    targetMetaData = this.targetMetaData;
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

  double resetValue() {
    double oldVal = getValue()!.toDouble();
    setValue(defaultValue);
    return oldVal;
  }

  // Propagate modifier update to dependent modifiers
  propagateUpdate([bool realtime = false]) {
    List<String>? f = realtime?['macrodetails', 'macrodetails-universal']:null;

    const modifiersAffectedBy = this.parent.getModifiersAffectedBy(this, f)
        .map((dependentModifierGroup) => {
            // Only updating one modifier in a group should suffice to update the
            // targets affected by the entire group.
            const m = this.parent.getModifiersByGroup(dependentModifierGroup)[0]
            if (realtime) {
                return m.updateValue(m.getValue(), true)
            } else {
                return m.setValue(m.getValue(), true)
            }
        });

    return modifiersAffectedBy
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
      const path = targets[i][0];
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
  String? getSymmetrySide([String? path]) {
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
    return path.map((p) => {
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
    return this.parent.getModifiersByType(this.constructor).filter(m => m !== this);
  }

  bool isMacro() {
    return macroVariable != null;
  }

  get leftLabel => (){return this.left ? this.left.split('-').slice(-1)[0] : '';};
  
  get rightLabel => () {
      return this.right ? this.right.split('-').slice(-1)[0] : '';
  };
  get midLabel => () {
      return this.mid ? this.mid.split('-').slice(-1)[0] : '';
  };
  get image => () {
      return 'data/targets/${fullName.replaceAll('/', '/images/').replaceAll('|', '-').toLowerCase()}.png';
  };
}


// class SimpleModifier // Simple modifier constructed from a path to a target file.



//  * Modifier that uses the targets module for managing its targets.
//  * Abstract baseclass
class ManagedTargetModifier extends Modifier {
    ManagedTargetModifier(groupName, name):super(groupName, name);

    getTargetWeights([double value = 1, List<Target>? targets, List<Factors>? factors, int total = 1]) {
      targets ??= this.targets;
      factors ??= getFactors(value);
      var facVals;
      Map result = {};

      for (int i = 0; i < targets.length; i++) {
          Target tpath = targets[i][0];
          const tfactors = targets[i][1];

          // look up target factors in our factor values
          facVals = _.map(tfactors, factor => factors[factor] != null ? factors[factor] : 1.0);

          // debug check for unfound factors
          List notFound = _.map(tfactors, factor => factors[factor] == null ? factor : null).filter(_.isString)
          if (notFound.isNotEmpty) {
              print('Names not found in factors $notFound\nmodiferName:$name\n$factors');
          }


          // debug check for NaN, undefined, null
          if (_.filter(facVals, n => !_.isFinite(n)).length) { 
            print('Some factor values are not finite numbers $facVals $name');
          }
              // console.debug('factor values',facVals,this.name)

          // so now we multiply the target weight by all modifying factors
          // armlength-old-tall = 1 * 0.10 old * 0.60 tall = 0.6
          result[tpath] = total * _.reduce(facVals, (accum, val) => accum * val, 1)
      }
      return result;
    }

    //  * Find the groups each child target belongs to
    //  * @param  {String} path e.g. "data/targets/macrodetails/universal-female-young-maxmuscle-averageweight.target"
    //  * @return {Array}      e.g. ["age", "gender", "muscle", "weight"]
    findMacroDependencies(String path) {
        const result = [];
        // get child targets
        List<String> targetPaths = targetMetaData.getTargetsByGroup(path) ?? [];
        for (int i = 0; i < targetPaths.length; i++) {
            const cats = targetPaths[i].macroVariables;
            if (cats){ 
              result.add(...cats);
            }
        }
        return _.uniq(result);
    }

    //  * Set value of this modifier
    //  * @param {Number} value
    //  * @param {Boolean} skipDependencies - A flag to avoid infinite recursion
    void setValue(double value, [bool skipDependencies = false]) {
      if(!value.isFinite){ 
        throw AssertionError('value is not finite $value');
      }
      value = clampValue(value);
      // const factors = this.getFactors(value)
      const tWeights = getTargetWeights(value:value);
      for (const tpath in tWeights) {
        if(tWeights.hasOwnProperty(tpath)) {
          const tWeight = tWeights[tpath];
          Target? target = parent.human.targets.children[tpath];
          if (target == null) {
              if (!parent.human.targets.loading) {
                print('Target not found in ${parent.human.targets.children.keys.length}'); 
                print(' loaded targets. Target=$tpath \n Modifier=$name');
              }
          } 
          else {
            target.value = tWeight;
          }
        }
      }
      // print('Set target values $name',name,_.keys(tWeights).length,tWeights)

      if (skipDependencies) {
        return;
      }

      // Update dependent modifiers
      propagateUpdate(false);
    }

    @override
    int? getValue([List<Target>? targets]) {
      // here the right overrides the left
      int? right = super.getValue(this.r_targets);
      if(right != null) { 
        return right;
      } 
      else {
        return -1 * super.getValue(this.l_targets);
      }
    }

    
    // * Returns weights for each factor e.g {'old':0.8,'young':0.2,child:0}
    @override
    List<String> getFactors([double value = 1]) {
        List<String> categoryNames = targetMetaData.targetCategories.keys;
        // return _.map(categoryNames, name]); // returns nested arrays
        return categoryNames.map((name) => [name, parent.human.factors[name + 'Val']]);
        //return _.transform(categoryNames, (res, name) => res[name] = parent.human.factors['${name}Val'], {});
    }
}


class UniversalModifier extends ManagedTargetModifier {
    constructor(String groupName, target, bool leftExt, bool rightExt, bool centerExt) {
        String name;
        String targetName = '${groupName}-${target}';

        String? left = leftExt ? '${targetName}-${leftExt}' : null;
        String? right = rightExt ? '${targetName}-${rightExt}' : null;
        String? center = centerExt ? '${targetName}-${centerExt}' : null;

        // it either has 3, 2, or 1 targets. Include each target in the name
        if (left && right && center) {
          targetName = '${targetName}-${leftExt}|${centerExt}|${rightExt}';
          name = '${target}-${leftExt}|${centerExt}|${rightExt}';
        } 
        else if (leftExt && rightExt) {
          targetName = '${targetName}-${leftExt}|${rightExt}';
          name = '${target}-${leftExt}|${rightExt}';
        } 
        else {
          right = targetName;
          name = target;
        }

        super(groupName, name)
        // can't use this before super so we assign to this after
        this.left = left
        this.right = right
        this.center = center
        this.targetName = targetName

        // console.debug("UniversalModifier(%s, %s, %s, %s)  :  %s", this.groupName, targetName, leftExt, rightExt, this.fullName)
        this.l_targets = this.targetMetaData.findTargets(this.left)
        this.r_targets = this.targetMetaData.findTargets(this.right)
        this.c_targets = this.targetMetaData.findTargets(this.center)

        this.macroDependencies = _.concat(
            this.findMacroDependencies(this.left),
            this.findMacroDependencies(this.right),
            this.findMacroDependencies(this.center)
        )

        this.targets = _.concat(this.l_targets, this.r_targets, this.c_targets)


        this.min = this.left ? -1 : 0
    }

    @override
    List<String> getFactors([double value = 1]) {
      List<String> factors = super.getFactors(value);

      if (this.left !== null) {
        factors[this.left] = -Math.min(value, 0);
      }
      if (this.center !== null) { 
        factors[this.center] = 1.0 - Math.abs(value);
      }
      factors[this.right] = Math.max(0, value);

      return factors;
    }
}


// * Modifiers that control many other modifiers instead of controlling target weights directly
class MacroModifier extends ManagedTargetModifier {
  MacroModifier(groupName, name):super(groupName, name){
    defaultValue = 0.5;
    this.setter = 'set${this.name}';
    this.getter = 'get${this.name}';

    this.targets = this.targetMetaData.findTargets(this.groupName);

    // console.debug('macro modifier %s.%s(%s): %s', base, name, variable, this.targets)

    this.macroDependencies = this.findMacroDependencies(this.groupName);

    this.macroVariable = this._getMacroVariable(this.name);

    // Macro modifier is not dependent on variable it controls itself
    if (this.macroVariable) {
        _.pull(this.macroDependencies, this.macroVariable);
    }
  }

  late String setter;
  late String getter;

    /** The macro variable modified by this modifier. **/
    String? _getMacroVariable([String? name]) {
      name = this.name ?? null;
      if (name != null) {
        String variable = name.toLowerCase();
        if (this.targetMetaData.categoryTargets[variable]) {
          return variable;
        } 
        else if (this.targetMetaData.targetCategories[variable]) {
          // necessary for caucasian, asian, african
          return this.targetMetaData.targetCategories[variable];
        }
      } 
      else {
        return null;
      }
    }

    int? getValue([List<Target>? targets]) {
      return parent.human.factors[this.getter]();
    }

    void setValue(double value, [bool skipDependencies = false]) {
      value = this.clampValue(value);
      parent.human.factors[this.setter](value, false);
      super.setValue(value, skipDependencies);
    }

    List<String> getFactors([double value = 1]) {
      List<String> factors = super.getFactors(value);
      factors[this.groupName] = 1.0;
      return factors;
    }

    // buildLists() {
    //     return;
    // }
}


//  * Specialisation of macro modifier to manage three closely connected modifiers
//  * whose total sum of values has to sum to 1.

class EthnicModifier extends MacroModifier {
  EthnicModifier(groupName, variable):super(groupName, variable);
  double defaultValue = 1.0 / 3;

    /**
     * Resetting one ethnic modifier restores all ethnic modifiers to their
     * default position.
     */
    double resetValue() {
      const _tmp = parent.blockEthnicUpdates
      parent.blockEthnicUpdates = true

      const oldVals = {}
      oldVals[this.fullName] = this.getValue()
      this.setValue(this.defaultValue)
      this.getSimilar().forEach((modifier) => {
          oldVals[modifier.fullName] = modifier.getValue()
          modifier.setValue(modifier.defaultValue)
      });

      parent.blockEthnicUpdates = _tmp
      return this.getValue()!.toDouble();
    }
}


//* Container class for modifiers
class Modifiers {
  Modifiers(this.human){
    loadModifiers().map(m => addModifier(m));
  }
  BaseHuman human;
  Map<String,Modifiers> children = {};
  // flags
  bool blockEthnicUpdates = false; // When set to True, changes to race are not normalized automatically
  // bool symmetryModeEnabled = false;

  // data
  var modelingModifiers = Array.concat([], measurementModifiers, modelingModifiers);

  // metadata
  var modifier_varMapping = {}; // Maps macro variable to the modifier group that modifies it
  var dependencyMapping = {}; // Maps a macro variable to all the modifiers that depend on it

  // * Load modifiers from a modifier definition file.
  List<Modifier> loadModifiers(modelingModifiersData) {
    modelingModifiersData = modelingModifiers || modelingModifiers;
    // console.debug("Loading modifiers from json")
    const modifiers = [];
    const lookup = {};
    var modifier;
    var modifierClass;
    modelingModifiersData.forEach((modifierGroup) {
      String groupName = modifierGroup.group;
      modifierGroup.modifiers.forEach((mDef) => {
        // Construct modifier
        if ("modifierType" in mDef) {
          if (mDef is EthnicModifier) {
            modifierClass = EthnicModifier
          } else {
            throw('Uknown modifier type ${mDef.modifierType}')
          }
        } else if ('macrovar' in mDef) {
          modifierClass = MacroModifier
        } else {
          modifierClass = UniversalModifier
        }

        if('macrovar' in mDef){
          modifier = ModifierClass(groupName, mDef.macrovar)
        } else {
          modifier = ModifierClass(groupName, mDef.target, mDef.min, mDef.max, mDef.mid)
        }

        if("defaultValue" in mDef){ 
          modifier.defaultValue = mDef.defaultValue;
        }

        modifiers.push(modifier)
        lookup[modifier.fullName] = modifier
      });
    });

    // print('Loaded %s modifiers ${mondifers.length}');
    return modifiers;
  }


  // Modifiers of a class type.
  getModifiersByType(classType) {
    // TODO just build this once on init. Perhaps move to modifiers class
    return _.filter(children, m => m instanceof classType);
  }

  // Get all modifiers for this human belonging to the same modifier group
  getModifiersByGroup(groupName) {
    // TODO just build this once on init. Perhaps move to modifiers class
    return _(children).values().filter(m => m.groupName === groupName).value();
  }


  //  * Update the targets for this human
  //  *  determined by the macromodifier target combinations
  updateMacroModifiers() {
    for (int i = 0; i < children.length; i++) {
      const modifier = children[i];
      if (modifier.isMacro()) {
        modifier.setValue(modifier.getValue());
      }
    }
  }

  // Attach a new modifier to this human.
  addModifier(modifier) {
    if (children[modifier.fullName] !== undefined) {
      print("Modifier with name %s is already attached to human. ${modifier.fullName}");
      return;
    }
    // this._modifier_type_cache = {};
    children[modifier.fullName] = modifier;

    // add to group
    // if (!this.modifier_groups[modifier.groupName])
    //     this.modifier_groups[modifier.groupName] = [];
    //
    // this.modifier_groups[modifier.groupName].push(modifier)

    // Update dependency mapping
    if (modifier.macroVariable && modifier.macroVariable != 'None') {
      if (modifier.macroVariable in modifier_varMapping &&
        modifier_varMapping[modifier.macroVariable] != modifier.groupName) {
        console.error(
            "Error, multiple modifier groups setting var %s (%s && %s)",
            modifier.macroVariable, modifier.groupName, modifier_varMapping[modifier.macroVariable]
        );
      } 
      else {
        modifier_varMapping[modifier.macroVariable] = modifier.groupName;

        // Update any new backwards references that might be influenced by this change (to make it independent of order of adding modifiers)
        const toRemove = []; // Modifiers to remove again from backwards map because they belong to the same group as the modifier controlling the var
        let dep = modifier.macroVariable;
        const affectedModifierGroups = this.dependencyMapping[dep] ?? [];
        for (int i = 0; i < affectedModifierGroups.length; i++) {
          const affectedModifierGroup = affectedModifierGroups[i];
          if (affectedModifierGroup === modifier.groupName) {
            toRemove.add(affectedModifierGroup);
            // console.debug('REMOVED from backwards map again %s', affectedModifierGroup)
          }
        }

        if (toRemove.isNotEmpty) {
          if (toRemove.length == dependencyMapping[dep].length) {
            delete this.dependencyMapping[dep];
          } 
          else {
            dependencyMapping[dep] = dependencyMapping[dep].filter(groupName => !toRemove.includes(groupName));
          }
        }

        for (int k = 0; k < modifier.macroDependencies.length; k++) {
          dep = modifier.macroDependencies[k]
          const groupName = this.modifier_varMapping[dep]
          if (groupName && groupName === modifier.groupName) {
            // Do not include dependencies within the same modifier group
            // (this step might be omitted if the mapping is still incomplete (dependency is not yet mapped to a group), && can later be fixed by removing the entry again from the reverse mapping)
            continue;
          }

          if (!this.dependencyMapping[dep]) {
            dependencyMapping[dep] = [];
          }
          if (!this.dependencyMapping[dep].includes(modifier.groupName)) {
            dependencyMapping[dep].push(modifier.groupName);
          }
          if (modifier.isMacro()){
            updateMacroModifiers();
          }
        }
      }
    }

      children[modifier.fullName] = modifier;
          // modifier.human = this.human;
      modifier.parent = this;
      // return this.children
    }

    
    //  *  Retrieve all modifiers that should be updated if the specified modifier
    //  *  is updated. (forward dependency mapping)
    getModifierDependencies(modifier, filter) {
      const result = [];

      if (modifier.macroDependencies.length > 0) {
        for (int l = 0; l < modifier.macroDependencies.length; l++) {
          const variable = modifier.macroDependencies[l];
          if (!modifier_varMapping[variable]) {
            print("Modifier dependency map: Error variable %s not mapped $variable");
            continue;
          }

          const depMGroup = modifier_varMapping[variable];
          if (depMGroup != modifier.groupName) {
            if (filter && filter.length) {
              if (filter.includes(depMGroup)) {
                result.add(depMGroup);
              } else {
                continue;
              }
            } else {
                result.add(depMGroup);
            }
          }
        }
      }
      return _.uniq(result);
    }

    //  *    Reverse dependency search. Returns all modifier groups to update that
    //  *    are affected by the change in the specified modifier. (reverse
    //  *    dependency mapping)
    getModifiersAffectedBy(modifier, filter) {
      const result = dependencyMapping[modifier.macroVariable] ?? [];
      if (filter == null || filter == null) {
        return result;
      } else {
        return _.filter(result, e => filter.includes(e));
      }
    }

    //  *  A random value bounded between max and min by reflecting out of bounds
    //  *  values. This means that a normal dist around 0, with a min of zero gives
    //  *  half a normal dist
    //  * @param  {Number} minValue
    //  * @param  {Number} maxValue
    //  * @param  {Number} middleValue
    //  * @param  {Number} sigmaFactor = 0.2 - std deviation as a fraction of max and min
    //  * @param  {Number} rounding    - Decmals to keeps
    //  * @return {Number}             - random number
    _getRandomValue(minValue, maxValue, middleValue, sigmaFactor = 0.2, rounding) {
      // TODO this may be better if we used d3Random.exponential for modifiers that go from 0 to 1 with a default at 0
      //
      const rangeWidth = Math.abs(maxValue - minValue);
      const sigma = sigmaFactor * rangeWidth;
      let randomVal = d3Random.randomNormal(middleValue, sigma)();

      // below we enforce max and min by reflecting back values that are outside
      // in some cases this is used to get half a normal dist
      // e.g. for distributions from 0 to 1 centered around 0, this results half a normal dist
      if (randomVal < minValue) {
          randomVal = minValue + Math.abs(randomVal - minValue);
      } else if (randomVal > maxValue) {
          randomVal = maxValue - Math.abs(randomVal - maxValue);
      }
      randomVal = _.clamp(randomVal, minValue, maxValue);
      if (rounding) randomVal = _.round(randomVal, rounding);
      return randomVal;
    }

    //  *  generate random modifiers values using appropriate distributions for each modifier
    //  * @param  {Number} symmetry  = 1     - Amount of symmetry preserved
    //  * @param  {Boolean} macro    = true  - Randomise macro modifiers
    //  * @param  {Boolean} height   = false
    //  * @param  {Boolean} face     = true
    //  * @param  {Boolean} body     = true
    //  * @param  {Number} rounding  = round to N decimal places
    //  * @return {Object}                   - modifier:value properties
    //  *                                      e.g. {'l-arm-length': 0.143145}
    randomValues([
      double symmetry = 1,
      bool macro = true, 
      bool height = false, 
      bool face = true, 
      bool body = true, 
      bool measure = false, 
      int rounding = 2, 
      double sigmaMultiple = 1
    ]) {
        // should have dist:
        // bimodal with peaks at 0 and 1 - gender
        // uniform - "macrodetails/Age", "macrodetails/African", "macrodetails/Asian", "macrodetails/Caucasian"
        // normal - all modifiers with left and right
        // exponentials - all targets with only right target
        //
        const modifierGroups = [];

        if (macro) { 
          modifierGroups.add.apply(modifierGroups, ['macrodetails', 'macrodetails-universal', 'macrodetails-proportions']);
        }
        if (measure) { 
          modifierGroups.add.apply(modifierGroups, ['measure']);
        }
        if (height) { 
          modifierGroups.add.apply(modifierGroups, ['macrodetails-height']);
        }
        if (face) {
          modifierGroups.add.apply(modifierGroups, [
            'eyebrows', 'eyes', 'chin',
            'forehead', 'head', 'mouth',
            'nose', 'neck', 'ears',
            'cheek'
          ]);
        }
        if (body) {
          modifierGroups.push.apply(modifierGroups, ['pelvis', 'hip', 'armslegs', 'stomach', 'breast', 'buttocks', 'torso', 'legs', 'genitals']);
        }

        let modifiers = _.flatten(modifierGroups.map(mGroup => this.getModifiersByGroup(mGroup)));

        // Make sure not all modifiers are always set in the same order
        // (makes it easy to vary dependent modifiers like ethnics)
        modifiers = _.shuffle(modifiers);

        const randomValues = {};

        for (int j = 0; j < modifiers.length; j++) {
            let sigma = null,
              mMin = null,
              mMax = null,
              w = null,
              m2 = null,
              symMax = null,
              symMin = null,
              symmDeviation = null,
              symm = null,
              randomValue = null;

            const m = modifiers[j];

            if (!(m.fullName in randomValues)) {
                if (m.groupName == 'head') {
                  // narow distribution
                  sigma = 0.1 * sigmaMultiple
                } else if (["forehead/forehead-nubian-less|more", "forehead/forehead-scale-vert-less|more"].indexOf(m.fullName) > -1) {
                  // very narrow distribution
                  sigma = 0.02 * sigmaMultiple
                } 
                else if (m.fullName.search("trans-horiz") > -1 || m.fullName === "hip/hip-trans-in|out") {
                  if (symmetry == 1) {
                    randomValue = m.defaultValue
                  } 
                  else {
                    mMin = m.min;
                    mMax = m.max;
                    w = Math.abs(mMax - mMin) * (1 - symmetry);
                    mMin = Math.max(mMin, m.defaultValue - w / 2);
                    mMax = Math.min(mMax, m.defaultValue + w / 2);
                    randomValue = _getRandomValue(mMin, mMax, m.defaultValue, 0.1, rounding);
                  }
                } 
                else if (["forehead", "eyebrows", "neck", "eyes", "nose", "ears", "chin", "cheek", "mouth"].indexOf(m.groupName) > -1) {
                  sigma = 0.1 * sigmaMultiple;
                } 
                else if (m.groupName === 'macrodetails') {
                  if (["macrodetails/Age", "macrodetails/African", "macrodetails/Asian", "macrodetails/Caucasian"].indexOf(m.fullName) > -1) {
                      // people could be any age/race so a uniform distribution here
                      randomValue = Math.random();
                  } 
                  else if (["macrodetails/Gender"].indexOf(m.fullName) > -1) {
                      // most people are mostly male or mostly female
                      // a bimodal distribution here. we will do this by giving it a 50% change of default of 0 otherwise 1
                      const defaultValue = 1 * Math.random() > 0.5;
                      randomValue = _getRandomValue(m.min, m.max, defaultValue, 0.1, rounding);
                  } 
                  else {
                      sigma = 0.3 * sigmaMultiple;
                  }
                } 
                else {
                  sigma = 0.1 * sigmaMultiple;
                }


                // TODO also allow it to continue from current value? Probobly do that by setting the default to _.mean(m.defaultValue,m.value)
                randomValue ??= _getRandomValue(m.min, m.max, m.defaultValue, sigma, rounding);

                randomValues[m.fullName] = randomValue

                symm = m.getSymmetricOpposite()
                if (symm && !(symm in randomValues)) {
                    if (symmetry == 1) {
                        randomValues[symm] = randomValue
                    } else {
                        m2 = human.getModifier(symm)
                    }
                    symmDeviation = ((1 - symmetry) * Math.abs(m2.max - m2.min)) / 2;
                    symMin = Math.max(m2.min, Math.min(randomValue - (symmDeviation), m2.max));
                    symMax = Math.max(m2.min, Math.min(randomValue + (symmDeviation), m2.max));
                    randomValues[symm] = _getRandomValue(symMin, symMax, randomValue, sigma, rounding);
                }
            }
        }

        // No pregnancy for male, too young || too old subjects
        // TODO add further restrictions on gender-dependent targets like pregnant && breast
        if (((randomValues["macrodetails/Gender"] || 0) > 0.5) ||
            ((randomValues["macrodetails/Age"] || 0.5) < 0.2) ||
            ((randomValues["macrodetails/Age"] || 0.7) < 0.75)) {
            if ("stomach/stomach-pregnant-decr|incr" in randomValues) {
                randomValues["stomach/stomach-pregnant-decr|incr"] = 0
            }
        }


        return randomValues
    }

  // randomize the modifier value along a normal distribution
  randomize([symmetry = 1, macro = true, height = false, face = true, body = true, measure = false, rounding = 2, sigmaMultiple = 1]) {
    // var oldValues = _.transform(modifiers, (a, m) => a[m.fullName] = m.getValue(), {})
    const randomVals = this.randomValues(symmetry, macro, height, face, body, measure, rounding, sigmaMultiple)

    for (String name in randomVals) {
      if (randomVals.hasOwnProperty(name)) {
        const value = randomVals[name]
        children[name].setValue(value, true)
      }
    }
    return randomVals;
  }

  void reset() {
    for (const name in children) {
      if (children.hasOwnProperty(name)) {
        children[name].resetValue();
      }
    }
  }

  exportConfig() {
      return _.values(children)
          .reduce((o, m) => {
              o[m.fullName] = m.getValue()
              return o
          }, {})
  }

  importConfig(json) {
    reset();
    return json.map((value, modifierName) => children[modifierName].setValue(value));
  }
}