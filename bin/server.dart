import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:uuid/uuid.dart';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

var fakeStorageFilePath = 'bin/fakeStorage.json';

// Configure routes.
final _router = Router()
  ..get('/', _rootHandler)
  ..get('/api/v1/sms/send-fake-verifcation-code', _sendFakeVerificationCode)
  ..get('/api/v1/sms/verify-fake-verification-code', _verifySmsCode);

Response _rootHandler(Request req) {
  return Response.ok('Hello, World!\n');
}

Future<Response> _sendFakeVerificationCode(Request request) async {
  String phoneNumber = request.url.queryParameters['phoneNumber'] ?? '123456';

  String verificationCode = [
    Random().nextInt(10),
    Random().nextInt(10),
    Random().nextInt(10),
    Random().nextInt(10),
  ].join();

  List<String> arguments = [
    'emu',
    'sms',
    'send',
    'MegaCloud',
    'Your Verification Code is: $verificationCode'
  ];
  await Process.run('adb', arguments);

  _saveNumberWithCodeInFakeStorage(phoneNumber, verificationCode);

  var headers = {'Content-Type': 'application/json'};

  return Response.ok(
    json.encode({
      "status": 1,
      "message": "Код подтверждения отправлен на номер $phoneNumber",
      "object": null,
    }),
    headers: headers,
  );
}

Future<void> _saveNumberWithCodeInFakeStorage(
  String phoneNumber,
  String verificationCode,
) async {
  String rawData = await File(fakeStorageFilePath).readAsString();
  Map<String, dynamic> data = json.decode(rawData);

  data[phoneNumber] = verificationCode;

  await File(fakeStorageFilePath).writeAsString(json.encode(data));
}

Future<Response> _verifySmsCode(Request request) async {
  String phoneNumber = request.url.queryParameters['phoneNumber'] ?? '123456';
  String? verificationCode = request.url.queryParameters['verificationCode'];

  String rawData = await File(fakeStorageFilePath).readAsString();
  Map<String, dynamic> data = json.decode(rawData);

  var headers = {'Content-Type': 'application/json'};

  if (data.containsKey(phoneNumber) && data[phoneNumber] == verificationCode) {
    return Response.ok(
      json.encode({
        "status": 1,
        "message": "Успешно",
        "object": Uuid().v4(),
      }),
      headers: headers,
    );
  }

  return Response.ok(
    json.encode({
      "status": 0,
      "message": "Профиль абонента не найден",
      "object": null,
    }),
    headers: headers,
  );
}

void main(List<String> args) async {
  // Use any available host or container IP (usually `0.0.0.0`).
  final ip = InternetAddress.anyIPv4;

  // Configure a pipeline that logs requests.
  final _handler = Pipeline().addMiddleware(logRequests()).addHandler(_router);

  // For running in containers, we respect the PORT environment variable.
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(_handler, ip, port);
  print('Server listening on port ${server.port}');
}
