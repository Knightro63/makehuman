//* Contains meta data about all available targets
class TargetMetaData {
  //  * [constructor description]
  //  * @param  {[type]} targetList       [description]
  //  * @param  {[type]} targetCategories [description]
  //  * @return {[type]}                  [description]

  TargetMetaData() {
    final self = this;
    // this.groups = _.invertBy(targetList.targets); // Target components, ordered per group
    this.targetCategories = targetCategories;
    categoryTargets = _.invertBy(targetCategories);
    categories = _.uniq(_.keys(targetCategories));

    // TODO move these to a metadata obj in a property or else prefix with md
    targetIndex = _.map(_.keys(targetList.targets), path => self.pathToGroupAndCategories(path))
    targetImages = targetList.images; // Images list
    targetsByTag = invertByMany(targetList.targets);
    targetsUrls = _.keys(targetList.targets); // List of target files
    targetsByPath = _.groupBy(targetIndex, i => i.path);
    targetGroups = _(targetsUrls)
        .map(path => Target(self.pathToGroupAndCategories(path)))
        .groupBy(gc => gc.group)
        .value();
  }

  targetGroups;
  targetsByPath;
  List<String> targetsUrls;
  targetsByTag;
  targetImages;
  targetIndex;
  categories;
  categoryTargets;
  targetCategories;

  //  * extract the path for a mprh target to categories and groups
  //  * @param  {string} path  e.g. 'data/targets/macrodetails/height/female-old-averagemuscle-averageweight-minheight.target'
  //  * @return {[type]}      {key:"macrodetails,height",data:{'weight': 'averageweight',..}
  Map<String,dynamic> pathToGroupAndCategories(String origPath) {
    // TODO refactor: data, key/groupName => categories, groups
    // lowercase
    origPath = origPath.toLowerCase();

    // remove everything up to the target folder if it's there
    final shortPath = origPath.replaceAll(/^.+targets\//, '')

    // remove ext
    final path = shortPath.replaceAll(/\.target$/g, '');

    // break it by slash, underscore, comma, or dash
    // this makes the tags which make up categories and group;
    final subgroups = path.replaceAll(/[/_,]/g, '-').split('-');


    // meta categories which each key part belongs to
    final categories = {};
        // ad null vals
    Object.keys(this.categoryTargets).map(categ => (categories[categ] = null))

    // find which subgroups fit into macro categories
    final macroGroup = _.filter(subgroups, group => targetCategories[group])
    macroGroup.forEach((group) => {
        const category = targetCategories[group]
        categories[category] = group
    });

    // now remove macro subgroups
    _.pull(subgroups, ...macroGroup)

    return {
        'group': subgroups.join('-'),
        'categories':categories,
        'variables': _.values(_.pickBy(categories, _.isTrue)).sort(),
        'macroVariables': _.keys(_.pickBy(categories, _.isTrue)).sort(),
        'path': origPath,
        'shortPath':shortPath
    };
  }

  //  * Get targets that belong to the same group, and their factors
  //  * @param  {String} path - target path e.g. data/targets/nose/nose-nostrils-angle-up.target'
  //  * @return {Array}      [path,[factor1,factor2]],[path2,[factor1,factor2]]
  //  * e.g. ['data/targets/nose/nose-nostrils-angle-up.target',['nose-nostrils-angle-up']]]
  //  * see makehuman/gui/humanmodifier.py for more
  findTargets(path) {
    if (path == null) {
      return [];
    }

    List<Map<String,dynamic>> targetsList;

    try {
      targetsList = getTargetsByGroup(path) ?? [];
    } 
    catch (exc) {
      // TODO check for keyerror or whatever this will return
      print('missing target $path');
      targetsList = [];
    }

    final result = [];
    for (int i = 0; i < targetsList.length; i += 1) {
      final target = targetsList[i];
      final factordependencies = _.concat(target.variables, [target.group]);
      result.add([target['path'], factordependencies]);
    }
    return result;
  }

  //  * get targets by groups e.g. "armslegs,r,upperarms,fat"
  //  * @param  {String} group Comma seperated string of keys e.g. "armslegs,r,upperarms,fat"
  //  * @return {Array}       List of target objects
  getTargetsByGroup(String? group) {
    if(group == null){ 
      return [];
    }
    group = pathToGroupAndCategories(group)['group'];
    return targetGroups[group];
  }
}