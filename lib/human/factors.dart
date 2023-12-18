import 'dart:math' as Math;
import 'human.dart';
import 'package:three_dart/three_dart.dart' as three;

enum Ethnicity{asian,african,caucasian}
enum Gender{male,female}

class Factors {
  Factors(this.human){
    _setGenderVals();
    _setAgeVals();
    _setWeightVals();
    _setMuscleVals();
    _setHeightVals();
    _setBreastSizeVals();
    _setBreastFirmnessVals();
    _setBodyProportionVals();
  }

  Human human;

  int minAge = 1;
  int maxAge = 90;
  int midAge = 25;
  // TODO BMI needs adjusting to weightKg comes out Ok and BMI=25 corresponds to weight=0.5
  double minBMI = 15;
  double maxBMI = 35;

  double _age = 0.5;
  double _gender = 0.5;
  double _weight = 0.5;
  double _muscle = 0.5;
  double _height = 0.5;
  double _breastSize = 0.5;
  double _breastFirmness = 0.5;
  double _bodyProportions = 0.5;

  double caucasianVal = 1 / 3;
  double asianVal = 1 / 3;
  double africanVal = 1 / 3;

  // //////////////////////////////////
  // Non getter and setter functions //
  // //////////////////////////////////
  double maleVal = 1;
  double femaleVal = 0;

  double oldVal = 0;
  double babyVal = 0;
  double youngVal = 0;
  double childVal = 0;

  double maxweightVal = 1;
  double minweightVal = 0;
  double averageweightVal = 0.5;

  double maxMuscleVal = 1;
  double minMuscleVal = 0;
  double averageMuscleVal = 0.5;

  double maxHeightVal = 1;
  double minHeightVal = 0;
  double averageHeightVal = 0.5;

  double maxCupVal = 1;
  double minCupVal = 0;
  double averageCupVal = 0.5;

  double maxFirmnessVal = 1;
  double minFirmnessVal = 0;
  double averageFirmnessVal = 0.5;

  double idealProportionsVal = 1;
  double uncommonProportionsVal = 0;
  double regularProportionsVal = 0.5;

  bool blockEthnicUpdates = false;

  ///The height approximatly in  cm.
  double getHeightCm() {
    three.Box3 bBox = getBoundingBox();
    return 10 * (bBox.max.y - bBox.min.y);
  }

  ///Bounding box of the basemesh without the helper groups
  three.Box3 getBoundingBox() {
    if (human.mesh?.geometry?.boundingBox != null) {
      human.mesh!.geometry!.computeBoundingBox(); 
    }
    return human.mesh!.geometry!.boundingBox!;
  }

  ///Approximate age in years.
  double getAgeYears() {
    if (getAge() < 0.5) {
      return minAge + ((midAge - minAge) * 2) * getAge();
    } 
    else {
      return midAge + ((maxAge - midAge) * 2) * (getAge() - 0.5);
    }
  }

  ///Set age in years.
  void setAgeYears(double ageYears, [bool updateModifier = true]) {
    double age;
    if (ageYears < minAge || ageYears > maxAge) {
        throw("RuntimeError Invalid age specified, should be minimum $minAge && maximum $maxAge.");
    }
    if (ageYears < midAge) { 
      age = (ageYears - minAge) / ((midAge - minAge) * 2);
    } 
    else {
      age = ((ageYears - midAge) / ((maxAge - midAge) * 2)) + 0.5;
    }
    setAge(age, updateModifier);
  }

  double getWeightBMI() {
    return getWeight() * (maxBMI - minBMI) + minBMI;
  }
  void setWeightBMI(double bmi) {
    double weight = bmi / (maxBMI - minBMI) - minBMI;
    setWeight(weight);
  }

  double getWeightKg() {
    double heightM = getHeightCm() / 100;
    return getWeightBMI() * heightM * heightM;
  }
  void setWeightKg(double kgs) {
    double heightM = getHeightCm() / 100;
    setWeightBMI(kgs / heightM / heightM);
  }

    // //////////////////////
    // Getter and setters //
    // //////////////////////

    // this makes it a little nicer to access
    // TODO hide the getter and setter functions
    double get age => getAge();
    set age(v) => setAge(v);
    double get gender => getGender();
    set gender(v) => setGender(v);
    double get weight => getWeight();
    set weight(v) => setWeight(v);
    double get muscle => getMuscle();
    set muscle(v) => setMuscle(v);
    double get height => getHeight();
    set height(v) => setHeight(v);
    double get breastSize => getBreastSize();
    set breastSize(v) => setBreastSize(v);
    double get breastFirmness => getBreastFirmness();
    set breastFirmness(v) => setBreastFirmness(v);
    double get bodyProportions => getBodyProportions();
    set bodyProportions(v) => setBodyProportions(v);
    double get caucasian => getCaucasian();
    set caucasian(v) => setCaucasian(v);
    double get african => getAfrican();
    set african(v) => setAfrican(v);
    double get asian => getAsian();
    set asian(v) => setAsian(v);

  
  ///Set gender
  ///@param {Number}  gender  -  0 for female to 1 for male
  void setGender(double gender, [bool updateModifier = true]) {
    if (updateModifier) {
      final modifier = human.modifiers.children['macrodetails/Gender'];
      modifier.setValue(gender);
      // human.targets.applyAll()
      return;
    }

    gender = gender.clamp(0, 1);//_.clamp(gender, 0, 1)
    if(_gender == gender) { 
      return; 
    }
    _gender = gender;
    _setGenderVals();
  }

  ///Gender from 0 (female) to 1 (male)
  double getGender(){
    return _gender;
  }

  ///Dominant gender of this human or null
  Gender? getDominantGender() {
    if(getGender() < 0.5) { 
      return Gender.female;
    } 
    else if(getGender() > 0.5) { 
      return Gender.male;
    } 
    else {
      return null;
    }
  }

  void _setGenderVals() {
    maleVal = _gender;
    femaleVal = 1 - _gender;
  }

  ///Set age
  ///@param {Number}  age                   - 0 for 0 years old to 1 for 70 years old
  void setAge(double age, [bool updateModifier = true]) {
    if (updateModifier) {
      final modifier = human.modifiers.children['macrodetails/Age'];
      modifier.setValue(age);
      // human.targets.applyAll()
      return;
    }

    age = age.clamp(0, 1);
    if(_age == age) {
      return;
    }
    _age = age;
    _setAgeVals();
  }

  ///Age of this human as a float between 0 && 1.
  double getAge() {
    return _age;
  }

  ///Makehuman a8 age sytem where:
  ///- 0 is a 1 years old baby
  ///- 0.1875 is 10 year old child
  ///- 0.5 is a 25 year old young adult
  ///- 1 is a 90 year old, old adult
  void _setAgeVals() {
    if (_age < 0.5) {
      oldVal = 0;
      babyVal = Math.max(0, 1 - _age * 5.333); // 1/0.1875 = 5.333
      youngVal = Math.max(0, (age - 0.1875) * 3.2); // 1/(0.5-0.1875) = 3.2
      childVal = Math.max(0, Math.min(1, 5.333 * _age) - youngVal);
    } 
    else {
      childVal = 0;
      babyVal = 0;
      oldVal = Math.max(0, _age * 2 - 1);
      youngVal = 1 - oldVal;
    }
  }

  ///set weight
  ///@param {Number}  weight                - 0 to 1
  ///@param {Boolean} [updateModifier=true] [description]
  void setWeight(double weight, [bool updateModifier = true]) {
    if (updateModifier) {
      final modifier = human.modifiers.children['macrodetails-universal/Weight'];
      modifier.setValue(weight, false);
      // human.targets.applyAll()
      return;
    }

    weight = weight.clamp(0, 1);
    if (_weight == weight) {
        return;
    }
    _weight = weight;
    _setWeightVals();
  }

  double getWeight() {
    return _weight;
  }

  void _setWeightVals() {
    maxweightVal = Math.max(0, _weight * 2 - 1);
    minweightVal = Math.max(0, 1 - _weight * 2);
    averageweightVal = 1 - (maxweightVal + minweightVal);
  }

  ///Muscle from 0 to 1
  ///@param {Number}  muscle                - 0 to 1
  void setMuscle(double muscle, [bool updateModifier = true]) {
    if (updateModifier) {
      final modifier = human.modifiers.children['macrodetails-universal/Muscle'];
      modifier.setValue(muscle, false);
      // human.targets.applyAll()
      return;
    }

    muscle = muscle.clamp(0,1);
    if (_muscle == muscle) {
      return;
    }
    _muscle = muscle;
    _setMuscleVals();
  }

  double getMuscle() {
    return _muscle;
  }

  _setMuscleVals() {
    maxMuscleVal = Math.max(0, _muscle * 2 - 1);
    minMuscleVal = Math.max(0, 1 - _muscle * 2);
    averageMuscleVal = 1 - (maxMuscleVal + minMuscleVal);
  }

  void setHeight(double height, [bool updateModifier = true]) {
    if (updateModifier) {
      final modifier = human.modifiers.children['macrodetails-height/Height'];
      modifier.setValue(height, false);
      // human.targets.applyAll()
      return;
    }

    height = height.clamp(0,1);
    if (_height == height) {
      return;
    }
    _height = height;
    _setHeightVals();
  }

  double getHeight() {
    return _height;
  }

  void _setHeightVals() {
    maxHeightVal = Math.max(0, _height * 2 - 1);
    minHeightVal = Math.max(0, 1 - _height * 2);
    if (maxHeightVal > minHeightVal) {
      averageHeightVal = 1 - maxHeightVal;
    } 
    else {
      averageHeightVal = 1 - minHeightVal;
    }
  }

  void setBreastSize(double size, [bool updateModifier = true]) {
    if (updateModifier) {
      final modifier = human.modifiers.children['breast/BreastSize'];
      modifier.setValue(size, false);
      // human.targets.applyAll()
      return;
    }

    size = size.clamp(0, 1);
    if (_breastSize == size) {
      return;
    }
    _breastSize = size;
    _setBreastSizeVals();
  }

  double getBreastSize() {
    return _breastSize;
  }

  void _setBreastSizeVals() {
    maxCupVal = Math.max(0, _breastSize * 2 - 1);
    minCupVal = Math.max(0, 1 - _breastSize * 2);
    if (maxCupVal > minCupVal) { 
      averageCupVal = 1 - maxCupVal;
    } 
    else {
      averageCupVal = 1 - minCupVal;
    }
  }

  void setBreastFirmness(double firmness, [bool updateModifier = true]) {
    if (updateModifier) {
      final modifier = human.modifiers.children['breast/BreastFirmness'];
      modifier.setValue(firmness, false);
      // human.targets.applyAll()
      return;
    }

    firmness = firmness.clamp(0,1);
    if (_breastFirmness == firmness) {
      return;
    }
    _breastFirmness = firmness;
    _setBreastFirmnessVals();
  }

  double getBreastFirmness() {
    return _breastFirmness;
  }

  _setBreastFirmnessVals() {
    maxFirmnessVal = Math.max(0, _breastFirmness * 2 - 1);
    minFirmnessVal = Math.max(0, 1 - _breastFirmness * 2);

    if (maxFirmnessVal > minFirmnessVal) { 
      averageFirmnessVal = 1 - maxFirmnessVal;
    } 
    else {
      averageFirmnessVal = 1 - minFirmnessVal;
    }
  }

  void setBodyProportions(double proportion, [bool updateModifier = true]) {
    if (updateModifier) {
      final modifier = human.modifiers.children['macrodetails-proportions/BodyProportions'];
      modifier.setValue(proportion, false);
      // human.targets.applyAll()
      return;
    }

    proportion = three.Math.min(1, three.Math.max(0, proportion));
    if (_bodyProportions == proportion) {
      return;
    }
    _bodyProportions = proportion;
    _setBodyProportionVals();
  }

  void _setBodyProportionVals() {
    idealProportionsVal = Math.max(0, _bodyProportions * 2 - 1);
    uncommonProportionsVal = Math.max(0, 1 - _bodyProportions * 2);

    if (idealProportionsVal > uncommonProportionsVal) {
      regularProportionsVal = 1 - idealProportionsVal;
    } 
    else { 
      regularProportionsVal = 1 - uncommonProportionsVal ;
    }
  }

  double getBodyProportions() {
    return _bodyProportions;
  }

  void setCaucasian(double caucasian, [bool updateModifier = true,bool sync = true]) {
    if (updateModifier) {
      final modifier = human.modifiers.children['macrodetails/Caucasian'];
      modifier.setValue(caucasian, false);
      // human.targets.applyAll()
      return;
    }

    caucasian = caucasian.clamp(0, 1);
    caucasianVal = caucasian;

    if (sync && !blockEthnicUpdates) {
      _setEthnicVals('caucasian');
    }
  }

  double getCaucasian() {
    return caucasianVal;
  }

  void setAfrican(double african, [bool updateModifier = true, bool sync = true]) {
    if (updateModifier) {
      final modifier = human.modifiers.children['macrodetails/African'];
      modifier.setValue(african, false);
      // human.targets.applyAll()
      return;
    }

    african = african.clamp(0, 1);
    africanVal = african;

    if (sync && !blockEthnicUpdates) {
      _setEthnicVals('african');
    }
  }

  double getAfrican() {
    return africanVal;
  }

  double? setAsian(double asian, [bool updateModifier = true, bool sync = true]) {
    if (updateModifier) {
      final modifier = human.modifiers.children['macrodetails/Asian'];
      modifier.setValue(asian, false);
      // human.targets.applyAll()
      return null;
    }

    asianVal = asian.clamp(0,1);

    if (sync && !blockEthnicUpdates) {
      _setEthnicVals('asian');
    }
    return asian;
  }

  double getAsian() {
    return asianVal;
  }

  ///Normalize ethnic values so that they sum to 1.
  void _setEthnicVals([String? exclude]) {
    double _getVal(ethnic){
      return this[`${ethnic}Val`];
    }
    void _setVal(ethnic, value){
      this[`${ethnic}Val`] = value;
    }

    bool closeTo(double value, double limit, [double epsilon = 0.001]) {
      return three.Math.abs(value - limit) <= epsilon;
    }

    const ethnics = ['african', 'asian', 'caucasian'];
    double remaining = 1;
    if(exclude != null) {
      ethnics.remove(exclude);
    }
    remaining = 1 - _getVal(exclude);

    final otherTotal = ethnics.map((e){_getVal(e);});
    if (otherTotal == 0) {
      // Prevent division by zero
      if (ethnics.length == 3 || _getVal(exclude) == 0) {
        // All values 0, this cannot be. Reset to default values.
        ethnics.forEach((e){
          _setVal(e, 1 / 3);
        });
        if (exclude != null) {
          _setVal(exclude, 1 / 3);
        }
      } 
      else if (exclude != null && closeTo(_getVal(exclude), 1)) {
        // One ethnicity is 1, the rest is 0
        ethnics.forEach((e){_setVal(e, 0);});
        _setVal(exclude, 1);
      } 
      else {
        // Increase values of other races (that were 0) to hit total sum of 1
        ethnics.forEach((e){_setVal(e, 0.01);});
        _setEthnicVals(exclude); // Re-normalize
      }
    } 
    else {
      ethnics.map((e){_setVal(e, remaining * (_getVal(e) / otherTotal));});
    }
  }

  ///Most dominant ethnicity (african, caucasian, asian) or null
  Ethnicity? getEthnicity() {
    if (getAsian() > getAfrican() && getAsian() > getCaucasian()) {
      return Ethnicity.asian;
    } 
    else if (getAfrican() > getAsian() && getAfrican() > getCaucasian()) {
      return Ethnicity.african;
    } 
    else if (getCaucasian() > getAsian() && getCaucasian() > getAfrican()) {
      return Ethnicity.caucasian;
    } 
    else {
      return null;
    }
  }
}
