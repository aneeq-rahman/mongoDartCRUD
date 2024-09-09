import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main() async {
  // Connect to the MongoDB database
  final db = await connectToDatabase();
  final collection = db.collection('my_collection');

  // Define the handler for incoming HTTP requests
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler((Request request) async {
    switch (request.method) {
      case 'GET':
        return await getCrud(request, collection);

      case 'POST':
        return await postCrud(request, collection);

      case 'PUT':
        return await putCrud(request, collection);

      case 'DELETE':
        return await deleteCrud(request, collection);

      default:
        return Response.notFound('Not Found');
    }
  });

  // Use the serve() method to start the HTTP server
  final server = await shelf_io.serve(handler, 'localhost', 8080);
  print('Serving at http://${server.address.host}:${server.port}');
}

// Function to connect to the MongoDB database
Future<Db> connectToDatabase() async {
  final db = Db('mongodb://localhost:27017/my_database');
  await db.open();
  return db;
}

Future<Response> getCrud(Request request, DbCollection collection) async {
  try {
    final result = await collection.find().toList();
    return Response.ok(jsonEncode(result),
        headers: {'Content-Type': 'application/json'});
  } catch (e) {
    return Response.internalServerError(body: 'Error fetching data: $e');
  }
}

Future<Response> postCrud(Request request, DbCollection collection) async {
  try {
    final payload = await request.readAsString();
    final data = jsonDecode(payload);

    if (data is Map<String, dynamic>) {
      await collection.insert(data);
      return Response.ok('Inserted');
    } else {
      return Response.badRequest(body: 'Invalid payload format');
    }
  } catch (e) {
    return Response.internalServerError(body: 'Error inserting data: $e');
  }
}

Future<Response> putCrud(Request request, DbCollection collection) async {
  try {
    final payload = await request.readAsString();
    final data = jsonDecode(payload);

    if (data.containsKey('id') && data.containsKey('name')) {
      final id = data['id'];
      final updatedName = data['name'];

      final objectId = ObjectId.fromHexString(id);
      final updatedResult = await collection.findAndModify(
          query: where.id(objectId),
          update: modify.set('name', updatedName),
          returnNew: true);

      if (updatedResult != null) {
        return Response.ok(jsonEncode(updatedResult),
            headers: {'Content-Type': 'application/json'});
      } else {
        return Response.notFound('Document not found');
      }
    } else {
      return Response.badRequest(
          body: 'Invalid body, id and name are required');
    }
  } catch (e) {
    return Response.internalServerError(body: 'Error updating document: $e');
  }
}

Future<Response> deleteCrud(Request request, DbCollection collection) async {
  try {
    final payload = await request.readAsString();
    final data = jsonDecode(payload);

    if (data.containsKey('id')) {
      final objectId = ObjectId.fromHexString(data['id']);

      final deleteResult = await collection.deleteOne(where.id(objectId));
      if (deleteResult.nRemoved == 1) {
        return Response.ok('Document with $objectId removed successfully');
      } else {
        return Response.notFound('Document with $objectId not found');
      }
    } else {
      return Response.badRequest(body: 'Invalid body, id is required');
    }
  } catch (e) {
    return Response.internalServerError(body: 'Error deleting document: $e');
  }
}
