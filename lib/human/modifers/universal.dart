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