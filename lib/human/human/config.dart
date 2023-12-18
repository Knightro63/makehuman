import '../proxy.dart';

class Config{
  Config({
    this.x = 0,
    this.y = 0,
    this.z = 0,
    this.s = 1,
    this.baseUrl = 'data/',
    this.skins = const [],
    this.proxies = const [],
    this.poses = const [],
    this.targets = 'targets.bin',
    this.model = 'base.json',
  });
  String baseUrl;
  double x = 0;
  double y = 0;
  double s = 1;
  double z = 0;

  String targets;
  String model;
  List<> poses;
  List<> skins;
  List<Proxies> proxies;
}