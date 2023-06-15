import 'package:flutter_gl/native-array/index.dart';
import 'package:three_dart/three_dart.dart' as THREE;

class OBJExporter{
  //OBJExporter();

  String output = '';
  int precision = 6;

  int indexVertex = 0;
  int indexVertexUvs = 0;
  int indexNormals = 0;

  int? group;
  face = [];

  String parse(THREE.Object3D object) {
    object.traverse((child){
      if (child is THREE.Mesh) {
        parseMesh(child);
      }
      if (child is THREE.Line) {
        parseLine(child);
      }
    });

    return output;
  }

  void parseLine(THREE.Object3D line) {
    int nbVertex = 0;
    THREE.BufferGeometry? geometry = line.geometry;
    String type = line.type;

    // if (geometry is THREE.Geometry) {
    //   geometry = THREE.BufferGeometry().setFromObject(line);
    // }

    if (geometry is THREE.BufferGeometry) {
      // shortcuts
      THREE.Float32BufferAttribute? vertices = geometry.getAttribute('position');
      THREE.BufferAttribute<NativeArray<num>>? indices = geometry.getIndex();

      // name of the line object
      output += 'o ${line.name}\n';

      if (vertices != null) {
        THREE.Vector3 vertex = THREE.Vector3();
        int l = vertices.count;
        for(int i = 0; i < l; i++, nbVertex++) {
          vertex.x = vertices.getX(i)!.toDouble();
          vertex.y = vertices.getY(i)!.toDouble();
          vertex.z = vertices.getZ(i)!.toDouble();

          // transfrom the vertex to world space
          vertex.applyMatrix4(line.matrixWorld);

          // transform the vertex to export format
          output += 'v ${vertex.x} ${vertex.y} ${vertex.z}\n';
        }
      }

      if (type == 'Line') {
        output += 'l ';
        int l = vertices!.count;
        for (int j = 1; j <= l; j++) {
          output += '${indexVertex + j}';
        }

        output += '\n';
      }

      if (type == 'LineSegments') {
        int l = vertices!.count;
        for(int j = 1, k = j + 1; j < l; j += 2, k = j + 1) {
          output += 'l ${indexVertex + j} ${indexVertex + k}\n';
        }
      }
    } 
    else {
      print('THREE.OBJExporter.parseLine(): geometry type unsupported $geometry');
    }

    // update index
    indexVertex += nbVertex;
  }

  void parseMesh(THREE.Object3D mesh) {
    int nbVertex = 0;
    int nbNormals = 0;
    int nbVertexUvs = 0;

    THREE.BufferGeometry? geometry = mesh.geometry;
    let faceGroups;
    let groupNames;

    if (geometry is THREE.BufferGeometry) {
        faceGroups = geometry.faces.map(f => f.materialIndex);
        groupNames = mesh.material.materials.map(m => m.name);

        // shortcuts
        THREE.Float32BufferAttribute? vertices = mesh.geometry!.getAttribute('position');
        //const vertices = mesh.geometry.vertices;
        // const normals = geometry.getAttribute('normal')
        THREE.Float32BufferAttribute? uvs = mesh.geometry!.attributes['uv'];//faceVertexUvs[0];
        const faces = mesh.geometry.faces;

        //var normals = attributes["normal"].array;
        //var uvs = attributes["uv"].array;

        // name of the mesh object
        output += 'o ${mesh.name}\n';

        // name of the mesh material
        if (mesh.material && mesh.material.name) {
            output += 'usemtl ${mesh.material.name}\n';
        }

        // vertices

        if (vertices != null) {
          THREE.Vector3 vertex = THREE.Vector3();
          for (int ii = 0; ii < vertices.length; ii++) {
            vertex.x = vertices.getX(ii)!.toDouble();
            vertex.y = vertices.getY(ii)!.toDouble();
            vertex.z = vertices.getZ(ii)!.toDouble();

            // transfrom the vertex to world space
            vertex.applyMatrix4(mesh.matrixWorld);

            // transform the vertex to export format
            output += 'v ${vertex.x.toStringAsPrecision(precision)} ${vertex.y.toStringAsPrecision(precision)} ${vertex.z.toStringAsPrecision(precision)}\n';
          }
        }

        // uvs
        if (uvs != null) {
          THREE.Vector2 uv = THREE.Vector2();
          for (int ii = 0; ii < uvs.length; ii++) {
            uv.x = uvs.getX(ii)!.toDouble();
            uv.y = uvs.getY(ii)!.toDouble();
            // transform the uv to export format
            output += 'vt ${uv.x.toStringAsPrecision(precision)} ${uv.y.toStringAsPrecision(precision)}\n';
          }
        }

      for (int ii = 0; ii < faces.length; ii++) {
        face = faces[ii];

        // convert from materialIndex to facegroup
        if (faceGroups && faceGroups[ii] != group) {
          group = faceGroups[ii];
          output += 'g ${groupNames[group]}\n';
        }

        // transform the face to export format
        output += 'f ${face.a + 1}/${ii * 3 + 1} ${face.b + 1}/${ii * 3 + 2} ${face.c + 1}/${ii * 3 + 3}\n';
      }
    }
    else {
      throw('THREE.OBJExporter.parseMesh(): geometry type unsupported $geometry');
    }

    // update index
    indexVertex += nbVertex;
    indexVertexUvs += nbVertexUvs;
    indexNormals += nbNormals;
  }
}
