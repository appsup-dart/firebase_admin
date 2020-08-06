import 'package:firebase_admin/firebase_admin.dart';
import 'package:firebase_admin/src/credential.dart';

void main() async {
  // applicationDefault() will look for credentials in the following locations:
  // * the service-account.json file in the package main directory
  // * the env variable GOOGLE_APPLICATION_CREDENTIALS
  // * a configuration file, specific for this library, stored in the user's home directory
  // * gcloud's application default credentials
  // * credentials from the firebase tools
  var credential = Credentials.applicationDefault();

  // when no credentials found, login using openid
  // the credentials are stored on disk for later use
  credential ??= await Credentials.login();

  var projectId = 'some-project';
  // create an app
  var app = FirebaseAdmin.instance.initializeApp(AppOptions(
      credential: credential ?? Credentials.applicationDefault(),
      projectId: projectId,
      storageBucket: '$projectId.appspot.com'));

  try {
    // get a user by email
    var v = await app.auth().getUserByEmail('jane@doe.com');
    print(v.toJson());
  } on FirebaseException catch (e) {
    print(e.message);
  }

  await for (var v in app.storage().bucket().list()) {
    print(v.name);
  }
}
