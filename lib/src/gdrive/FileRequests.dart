import 'dart:async';
import 'dart:convert';

import 'package:googleapis/drive/v2.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:lg_controller/src/menu/NavBarMenu.dart';
import 'package:lg_controller/src/models/KMLData.dart';
import 'package:lg_controller/src/models/SegregatedKMLData.dart';

class FileRequests {
  final _credentials = new auth.ServiceAccountCredentials.fromJson(r'''
  
  ''');
  final scopes = [drive.DriveApi.DriveScope];

  Future<Map<String, List<KMLData>>> getPOIFiles() async {
    var client = await authorizeUser();
    if (client == null) return null;
    var api = new drive.DriveApi(client);
    var query =
        "mimeType = 'application/vnd.google-earth.kml+xml' and '1Gs-KiheWHACyUtYtvGZma8xsBX6r1iTJ' in parents";
    List<drive.File> files =
        await searchFiles(api, 24, query).catchError((error) {
      print('An error occured: ' + (error.toString()));
      return null;
    }).whenComplete(() {
      client.close();
    });
    return decodeFiles(files);
  }

  Future<Map<String, List<KMLData>>> decodeFiles(files) async {
    Map<String, List<KMLData>> segData = new Map<String, List<KMLData>>();
    for (var ic in NavBarMenu.values()) {
      segData.addAll({ic.title: new List<KMLData>()});
    }
    SegregatedKmlData d;
    try {
      for (var file in files) {
        d = new SegregatedKmlData.fromJson(jsonDecode(file.description));
        if (segData.containsKey(d.category)) {
          segData[d.category].add(KMLData.fromJson(jsonDecode(d.data)));
        }
      }
    } catch (e) {
      print(e.toString());
    }
    return segData;
  }

  Future<auth.AuthClient> authorizeUser() async {
    var client = await auth
        .clientViaServiceAccount(_credentials, scopes)
        .catchError((error) {
      print("An unknown error occured: $error");
      return null;
    });
    return client;
  }

  Future<List<drive.File>> searchFiles(
      drive.DriveApi api, int max, String query) async {
    List<drive.File> docs = [];
    Future<List<drive.File>> next(String token) {
      return api.files
          .list(q: query, pageToken: token, maxResults: max)
          .then((results) {
        docs.addAll(results.items);
        if (docs.length < max && results.nextPageToken != null) {
          return next(results.nextPageToken);
        }
        return docs;
      });
    }

    return next(null);
  }
}
