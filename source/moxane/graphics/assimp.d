module moxane.graphics.assimp;

import derelict.assimp3.assimp;
import derelict.assimp3.types;

import std.experimental.allocator;
import std.experimental.allocator.gc_allocator;

import std.exception;

import std.string : toStringz;

void loadMesh(Vertex, Allocator = GCAllocator)(string file, out Vertex[] vertices)
{
	const(aiScene*) scene = aiImportFile(file.toStringz, aiProcess_Triangulate);
	enforce(scene !is null, "Could not load model from file: \"" ~ file ~ "\"");

	size_t numVerts;
	foreach(i; 0 .. scene.mNumMeshes)
		numVerts += scene.mMeshes[i].mNumFaces * 3;

	vertices = cast(Vertex[])Allocator.instance.allocate(numVerts * Vertex.sizeof);

	size_t v;
	foreach(meshC; 0 .. scene.mNumMeshes)
	{
		const aiMesh* mesh = scene.mMeshes[meshC];
		foreach(faceC; 0 .. mesh.mNumFaces)
		{
			const aiFace face = mesh.mFaces[faceC];
			foreach(vertexC; 0 .. 3)
			{
				aiVector3D aiv = mesh.mVertices[face.mIndices[vertexC]];
				vertices[v++] = Vertex(aiv.x, aiv.z, aiv.y);
			}
		}
	}
}