//* Container class for modifiers
import 'package:makehuman/human/human/base.dart';

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