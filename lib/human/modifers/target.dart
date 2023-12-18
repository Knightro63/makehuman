import '../target/targets.dart';
import '../factors.dart';
import 'modifer.dart';

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