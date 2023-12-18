class Helper{
  ///inverts a object by many values
  ///e.g. invertByMany({ 'a': [1,2,3], 'b': [1], c:[2]})
  ///{"1":["a","b"],"2":["a","c"],"3":["a"]}
  static invertByMany(dataObj) {
      return transform(dataObj, (result, values, key) =>
          _.map(values, subvalue =>
              (result[subvalue] || (result[subvalue] = [])).push(key)), {});
  }

  ///inverts a object by many unique values
  ///inveryByUniqueValues({ 'a': [1,2], 'b': [3], c:[4]})
  ///{1: "a", 2: "a", 3: "b", 4:"c"}
  static invertByUniqueValues(dataObj) {
    return _.transform(dataObj, (a, v, k) =>
        _.map(v, sv => a[sv] = k), {})
  }

  ///remap property name and values using lodash
  ///ref: http://stackoverflow.com/a/37389070/221742
  ///@param  {Object} object         - e.g. {oldKey:'oldValue''}
  ///@param  {Object} keyMapping   - {oldKey:'newKey'}
  ///@param  {Object} valueMapping - {oldValue:'newValue'}
  ///@return {Object}              - {newKey:'newValue'}
  static remapKeyValues(currentObject, keyMapping, valueMapping) {
    return (currentObject)
      .mapKeys((v, k) => { return keyMapping[k] == undefined ? k : keyMapping[k] })
      .mapValues((v) => { return valueMapping[v] == null ? v : valueMapping[v] })
      .value();
  }

  ///deep remap property name and values using lodash
  ///@param  {Object} object         - e.g. {oldKey:{oldKey:'oldValue'}}
  ///@param  {Object} keyMapping   - {oldKey:'newKey'}
  ///@param  {Object} valueMapping - {oldValue:'newValue'}
  ///@return {Object}              - {newKey:{newKey:'newValue'}}
  static remapKeyValuesDeep(currentObject, keyMapping, valueMapping) {
    currentObject = remapKeyValues(currentObject, keyMapping, valueMapping);
    if (isPlainObject(currentObject)) {
      return mapValues(currentObject, (v){
        if (isPlainObject(v)) {
          return remapKeyValuesDeep(v, keyMapping, valueMapping);
        } 
        else {
          return v;
        }
      });
    } 
    else {
      return currentObject;
    }
  }

  static Map<String,dynamic> deepRoundValues(currentObject, [int roundTo = 2]) {
    dynamic roundFunc(v){round(v, roundTo);}
    return mapValues(currentObject, (v){
      double? n = double.tryParse(v);
      if (n!= null && n.isFinite){ 
        v = roundFunc(n);
      }
      if (isPlainObject(v)){ 
        v = deepRoundValues(v);
      }
      return v;
    });
  }

  static Map<String,dynamic> deepParseFloat(currentObject) {
    return mapValues(currentObject, (v){
      double? n = double.tryParse(v);
      if (isPlainObject(v)){ 
        return deepParseFloat(v);
      }
      else if (n != null && n.isFinite) {
        return n;
      }
      else{ 
        return v;
      }
    });
  }

  static double round(double value,[int fractionDigits = 0]){
    String temp = value.toStringAsFixed(fractionDigits);
    return double.parse(temp);
  }

  static bool isPlainObject(dynamic map){
    return map is Map || map is Object;
  }

  static Map<String,dynamic> mapValues(Map<String,dynamic> map, dynamic f){
    Map<String,dynamic> toMap = {};
    if(f is String){
      for(String key in map.keys){
        toMap[key] = map[key][f];
      }
    }
    else if(f is Function){
      for(String key in map.keys){
        toMap[key] = f.call(map[key]);
      }
    }
    return toMap;
  }



  static Map<dynamic,dynamic> invert(Map<String,dynamic> toInvert){
    Map<dynamic,dynamic> converted = {};
    for(String key in toInvert.keys){
      converted[toInvert[key]] = key;
    }

    return converted;
  }

  static transform(){

  }
}
