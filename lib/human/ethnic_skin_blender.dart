import 'package:makehuman/makehuman.dart';
import 'package:three_js/three_js.dart' as three;

// these are set to look right when added to the caucasian skin
three.Color asianColor = three.Color().setHSL(0.078, 0.34, 0.576);
three.Color africanColor = three.Color().setHSL(0.09, 0.83, 0.21);
three.Color caucasianColor = three.Color().setHSL(0.062, 0.51, 0.68);


class EthnicSkinBlender {
  ///return a blend of the three ethnic skin tones based on the human macro settings.
  EthnicSkinBlender(this.human);

  Human human;

  three.Color valueOf() {
    List<double> blends = [
      human.factors.getCaucasian(),
      human.factors.getAfrican(),
      human.factors.getAsian()
    ];

    // Set diffuse color
    three.Color color = three.Color(0, 0, 0)
        .add(caucasianColor.clone()..scale(blends[0]))
        .add(africanColor.clone()..scale(blends[1]))
        .add(asianColor.clone()..scale(blends[2]));
    // clamp to [0,1]
    return color.fromArray(color.toArray().map((e) => e.clamp(0, 1)));
  }
}
