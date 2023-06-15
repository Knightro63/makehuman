import 'package:flutter_gl/native-array/index.dart';
import 'package:three_dart/three_dart.dart';

class OBJExporter {

	String parse(Object3D object ) {

		String output = '';

		int indexVertex = 0;
		int indexVertexUvs = 0;
		int indexNormals = 0;

		Vector3 vertex = Vector3();
		Color color = Color();
		Vector3 normal = Vector3();
		Vector2 uv = Vector2();

		List<String> face = [];

		void parseMesh(Mesh mesh ) {
			int nbVertex = 0;
			int nbNormals = 0;
			int nbVertexUvs = 0;

			BufferGeometry geometry = mesh.geometry!;

			Matrix3 normalMatrixWorld = Matrix3();

			// shortcuts
			BufferAttribute<NativeArray<num>>? vertices = geometry.getAttribute( 'position' );
			BufferAttribute<NativeArray<num>>? normals = geometry.getAttribute( 'normal' );
			BufferAttribute<NativeArray<num>>? uvs = geometry.getAttribute( 'uv' );
			BufferAttribute<NativeArray<num>>? indices = geometry.getIndex();

			// name of the mesh object
			output += 'o ${mesh.name}\n';

			// name of the mesh material
			if ( mesh.material != null && mesh.material.name != null) {
				output += 'usemtl ${mesh.material.name}\n';
			}

			// vertices
			if ( vertices != null ) {
				for ( int i = 0, l = vertices.count; i < l; i ++, nbVertex ++ ) {
					vertex.fromBufferAttribute( vertices, i );
					// transform the vertex to world space
					vertex.applyMatrix4( mesh.matrixWorld );
					// transform the vertex to export format
					output += 'v ${vertex.x} ${vertex.y} ${vertex.z}\n';
				}
			}

			// uvs
			if ( uvs != null ) {
				for ( int i = 0, l = uvs.count; i < l; i ++, nbVertexUvs ++ ) {
					uv.fromBufferAttribute( uvs, i );
					// transform the uv to export format
					output += 'vt ${uv.x} ${uv.y}\n';
				}
			}

			// normals
			if ( normals != null ) {
				normalMatrixWorld.getNormalMatrix( mesh.matrixWorld );
				for ( int i = 0, l = normals.count; i < l; i ++, nbNormals ++ ) {
					normal.fromBufferAttribute( normals, i );
					// transform the normal to world space
					normal.applyMatrix3( normalMatrixWorld ).normalize();
					// transform the normal to export format
					output += 'vn ${normal.x} ${normal.y} ${normal.z}\n';
				}
			}

			// faces

			if (indices != null) {
				for ( int i = 0, l = indices.count; i < l; i += 3 ) {
					for ( int m = 0; m < 3; m ++ ) {
						int j = indices.getX( i + m )!.toInt() + 1;
						face[m] = '${indexVertex + j}' + 
            (
              normals != null || uvs != null? '/' + ( uvs != null ? '${indexVertexUvs + j}' : '' ) 
              + ( normals != null? '/' + '${indexNormals + j}' : '' ) : '' 
            );
					}

					// transform the face to export format
					output += 'f ${face.join(' ')}\n';
				}
			} 
      else {
				for ( int i = 0, l = vertices!.count; i < l; i += 3 ) {
					for ( int m = 0; m < 3; m ++ ) {
						int j = i + m + 1;
						//face[ m ] = ( indexVertex + j ) + ( normals || uvs ? '/' + ( uvs ? ( indexVertexUvs + j ) : '' ) + ( normals ? '/' + ( indexNormals + j ) : '' ) : '' );
						face[m] = '${indexVertex + j}' + 
            (
              normals != null || uvs != null? '/' + ( uvs != null ? '${indexVertexUvs + j}' : '' ) 
              + ( normals != null? '/' + '${indexNormals + j}' : '' ) : '' 
            );
          }

					// transform the face to export format
					output += 'f ${face.join( ' ' )}\n';
				}
			}

			// update index
			indexVertex += nbVertex;
			indexVertexUvs += nbVertexUvs;
			indexNormals += nbNormals;
		}

		void parseLine(Line line ) {
			int nbVertex = 0;
			BufferGeometry? geometry = line.geometry;
			String type = line.type;

			// shortcuts
			BufferAttribute<NativeArray<num>>? vertices = geometry!.getAttribute( 'position' );

			// name of the line object
			output += 'o ${line.name}\n';

			if ( vertices != null ) {
				for ( int i = 0, l = vertices.count; i < l; i ++, nbVertex ++ ) {
					vertex.fromBufferAttribute( vertices, i );
					// transform the vertex to world space
					vertex.applyMatrix4( line.matrixWorld );
					// transform the vertex to export format
					output += 'v ${vertex.x} ${vertex.y} ${vertex.z}\n';
				}
			}

			if (type == 'Line') {
				output += 'l ';
				for (int j = 1, l = vertices!.count; j <= l; j ++ ) {
					output += '${indexVertex + j} ';
				}
				output += '\n';
			}

			if ( type == 'LineSegments') {
				for ( int j = 1, k = j + 1, l = vertices!.count; j < l; j += 2, k = j + 1 ) {
					output += 'l ${indexVertex + j} ${indexVertex + k}\n';
				}
			}

			// update index
			indexVertex += nbVertex;
		}

		void parsePoints(Object3D points) {
			int nbVertex = 0;
			BufferGeometry? geometry = points.geometry!;

			BufferAttribute<NativeArray<num>>? vertices = geometry.getAttribute( 'position' );
			BufferAttribute<NativeArray<num>>? colors = geometry.getAttribute( 'color' );

			output += 'o ${points.name}\n';

			if ( vertices != null ) {
				for ( int i = 0, l = vertices.count; i < l; i ++, nbVertex ++ ) {
					vertex.fromBufferAttribute( vertices, i );
					vertex.applyMatrix4( points.matrixWorld );

					output += 'v ${vertex.x} ${vertex.y} ${vertex.z}';

					if ( colors != null ) {
						color.fromBufferAttribute( colors, i ).convertLinearToSRGB();
						output += ' ${color.r} ${color.g} ${color.b}';
					}

					output += '\n';
				}

				output += 'p ';

				for ( int j = 1, l = vertices.count; j <= l; j ++ ) {
					output += '${indexVertex + j} ';
				}

				output += '\n';
			}

			// update index
			indexVertex += nbVertex;
		}

		object.traverse((Object3D child ) {
			if ( child is Mesh) {
				parseMesh( child );
			}
			if ( child is Line) {
				parseLine( child );
			}

      //TO DO
			// if ( child is Point) {
			// 	parsePoints( child );
			// }
		});

		return output;
	}

}