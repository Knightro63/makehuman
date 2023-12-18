import 'macro.dart';

//  * Specialisation of macro modifier to manage three closely connected modifiers
//  * whose total sum of values has to sum to 1.
class EthnicModifier extends MacroModifier {
  EthnicModifier(groupName, variable):super(groupName, variable){
    defaultValue = 1.0 / 3;
  }

    /**
     * Resetting one ethnic modifier restores all ethnic modifiers to their
     * default position.
     */
    double resetValue() {
      final _tmp = parent.blockEthnicUpdates;
      parent.blockEthnicUpdates = true;

      final oldVals = {};
      oldVals[fullName] = getValue();
      setValue(defaultValue);
      getSimilar().forEach((modifier){
          oldVals[modifier.fullName] = modifier.getValue();
          modifier.setValue(modifier.defaultValue);
      });

      parent.blockEthnicUpdates = _tmp;
      return getValue()!.toDouble();
    }
}