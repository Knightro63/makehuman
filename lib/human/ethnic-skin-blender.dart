import 'package:makehuman/makehuman.dart';
import 'package:three_dart/three_dart.dart' as THREE;

// these are set to look right when added to the caucasian skin
THREE.Color asianColor = THREE.Color().setHSL(0.078, 0.34, 0.576);
THREE.Color africanColor = THREE.Color().setHSL(0.09, 0.83, 0.21);
THREE.Color caucasianColor = THREE.Color().setHSL(0.062, 0.51, 0.68);


class EthnicSkinBlender {
  ///return a blend of the three ethnic skin tones based on the human macro settings.
  EthnicSkinBlender(this.human);

  Human human;

  THREE.Color valueOf() {
    List<double> blends = [
      human.factors.getCaucasian(),
      human.factors.getAfrican(),
      human.factors.getAsian()
    ];

    // Set diffuse color
    THREE.Color color = THREE.Color(0, 0, 0)
        .add(caucasianColor.clone().multiplyScalar(blends[0]))
        .add(africanColor.clone().multiplyScalar(blends[1]))
        .add(asianColor.clone().multiplyScalar(blends[2]));
    // clamp to [0,1]
    return color.fromArray(color.toArray().map((e) => e.clamp(0, 1)));
  }
}
