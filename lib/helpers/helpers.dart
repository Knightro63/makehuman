///inverts a object by many values
///e.g. invertByMany({ 'a': [1,2,3], 'b': [1], c:[2]})
///{"1":["a","b"],"2":["a","c"],"3":["a"]}
invertByMany(dataObj) {
    return _.transform(dataObj, (result, values, key) =>
        _.map(values, subvalue =>
            (result[subvalue] || (result[subvalue] = [])).push(key)), {})
}

///inverts a object by many unique values
///inveryByUniqueValues({ 'a': [1,2], 'b': [3], c:[4]})
///{1: "a", 2: "a", 3: "b", 4:"c"}
invertByUniqueValues(dataObj) {
  return _.transform(dataObj, (a, v, k) =>
      _.map(v, sv => a[sv] = k), {})
}

///remap property name and values using lodash
///ref: http://stackoverflow.com/a/37389070/221742
///@param  {Object} object         - e.g. {oldKey:'oldValue''}
///@param  {Object} keyMapping   - {oldKey:'newKey'}
///@param  {Object} valueMapping - {oldValue:'newValue'}
///@return {Object}              - {newKey:'newValue'}
remapKeyValues(currentObject, keyMapping, valueMapping) {
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
remapKeyValuesDeep(currentObject, keyMapping, valueMapping) {
  currentObject = remapKeyValues(currentObject, keyMapping, valueMapping);
  if (_.isPlainObject(currentObject)) {
    return _.mapValues(currentObject, (v) => {
      if (_.isPlainObject(v)) {
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

deepRoundValues(currentObject, roundFunc = v => _.round(v, 2)) {
  return _.mapValues(currentObject, (v) => {
    if (Number.isFinite(v)){ 
      v = roundFunc(v);
    }
    if (_.isPlainObject(v)){ 
      v = deepRoundValues(v, roundFunc);
    }
    return v;
  });
}

double deepParseFloat(currentObject) {
  return _.mapValues(currentObject, (v) => {
    double n = Number(v);
    if (_.isPlainObject(v)){ 
      return deepParseFloat(v);
    }
    else if (_.isFinite(n)) {
      return n;
    }
    else{ 
      return v;
    }
  });
}
