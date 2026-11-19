## 0.5.0+2

 - **FIX**: prefer httpClientFactory over FirebaseDart.setup client. ([7e3dcc27](https://github.com/appsup-dart/firebase_admin/commit/7e3dcc27b3c99f22221f26827916a1a53aab869c))

## 0.5.0+1

 - **FIX**: map Cloud Storage 404 responses to storage/not-found. ([5f8f99ef](https://github.com/appsup-dart/firebase_admin/commit/5f8f99efa7dc268b6ab8834d348b41a4889185c9))

## 0.5.0

> Note: This release has breaking changes.

 - **BREAKING** **REFACTOR**: rename Storage File to StorageObject. ([d6ffedd3](https://github.com/appsup-dart/firebase_admin/commit/d6ffedd338ee34521c1aa03a1ecfdf67bc002669))

## 0.4.0

> Note: This release has breaking changes.

 - **FIX**: keep token refresh timers in the calling zone and stop wrapping listener errors. ([3b505462](https://github.com/appsup-dart/firebase_admin/commit/3b505462dfb3dd823a8f84b244d6d015b71978cf))
 - **FIX**: reuse FirebaseDart.setup HTTP client for token and API calls. ([a0db8b68](https://github.com/appsup-dart/firebase_admin/commit/a0db8b6862fda6ae7fd81b5be1a259c27601a5e2))
 - **FIX**: coalesce in-flight getToken refreshes and expire 60s early. ([fd01bc60](https://github.com/appsup-dart/firebase_admin/commit/fd01bc60bbd1585e92bceed6832557b515abc7ce))
 - **FIX**: fail closed on incomplete tokens and align JWT claims. ([e4f6873e](https://github.com/appsup-dart/firebase_admin/commit/e4f6873e347678b4fd9b858b056139f9ec03f494))
 - **FIX**: make service-account client_id optional. ([64e0971d](https://github.com/appsup-dart/firebase_admin/commit/64e0971d0162b974057035ea08b20ea482cf2506))
 - **FIX**: validate service-account JSON and include RSA public exponent. ([1e241df9](https://github.com/appsup-dart/firebase_admin/commit/1e241df97db14bef454e6840c926b84cb129d26e))
 - **FEAT**: add Firebase App Check service. ([019143d9](https://github.com/appsup-dart/firebase_admin/commit/019143d90f880820c1e0a23ed3122422ee650405))
 - **FEAT**: add File.copy. ([c84328a4](https://github.com/appsup-dart/firebase_admin/commit/c84328a48ba4b53d55fd99215b3c8af7dfdae838))
 - **FEAT**: add create/list/revoke Firebase download URLs. ([0fd7515c](https://github.com/appsup-dart/firebase_admin/commit/0fd7515cadf820018a1a00fd5f2a887308161006))
 - **FEAT**: add Storage getDownloadURL. ([c1736738](https://github.com/appsup-dart/firebase_admin/commit/c1736738d7371566b8daec3121a7bcf8546f6b84))
 - **FEAT**: add V4 signed URLs for Storage. ([5a30df68](https://github.com/appsup-dart/firebase_admin/commit/5a30df68132cc85328bca37b21195ba6f0a74515))
 - **FEAT**: add Storage updateMetadata with named arguments. ([4ea28d8c](https://github.com/appsup-dart/firebase_admin/commit/4ea28d8c994862474376b11067f96783075d5c44))
 - **FEAT**: add Storage info metadata lookup. ([3099f8b1](https://github.com/appsup-dart/firebase_admin/commit/3099f8b19c72f258300478347c0d8985de62f249))
 - **FEAT**: add Storage read with offset/length. ([d4e9c833](https://github.com/appsup-dart/firebase_admin/commit/d4e9c8333039bf5b06c15fe947bf7d12111077a8))
 - **FEAT**: add Storage write/writeBytes (ObjectInfo). ([064cbfa6](https://github.com/appsup-dart/firebase_admin/commit/064cbfa68bd0f8017737c02353164f3e3291d7f6))
 - **BREAKING** **REFACTOR**: replace gcloud with owned Storage types. ([7ac2dd75](https://github.com/appsup-dart/firebase_admin/commit/7ac2dd754e9f1d7e8f990eb253f5622ed6285e38))

## 0.3.1+5

 - **FIX**: failing auth for some service accounts. ([823ddc70](https://github.com/appsup-dart/firebase_admin/commit/823ddc70f07e753e0a6a5fcd0bb9d5bbf43fbeed))

## 0.3.1+4

 - **REFACTOR**: support firebase_dart 2.0.0. ([089a7768](https://github.com/appsup-dart/firebase_admin/commit/089a7768ebd5a490ea51f86b3db9905be8563251))

## 0.3.1+3

 - **REFACTOR**(deps): require gcloud ^0.9.0 and googleapis >=15.0.0 <17.0.0. ([d13eabf5](https://github.com/appsup-dart/firebase_admin/commit/d13eabf584ad80978b144045a182c3b3243280a2))


## 0.3.1+2

 - **REFACTOR**: upgrade jose dependency. ([f43aa123](https://github.com/appsup-dart/firebase_admin/commit/f43aa12338f458e9863794f94bce4dbac75f27a7))


## 0.3.1+1

 - **FIX**: handle more error codes from server. ([5cc31df1](https://github.com/appsup-dart/firebase_admin/commit/5cc31df13ec7b53e2681384b8eda75ecc394ecba))


## 0.3.1

 - **FIX**: error on listlistUsers throws "Cannot be converted to a deep immutable object" [#38](https://github.com/appsup-dart/firebase_admin/issues/38). ([fae33870](https://github.com/appsup-dart/firebase_admin/commit/fae33870f9f2b48a43ba63b0864f6ffebebda5e2))
 - **FEAT**: implement TenantAwareAuth. ([2934bd8d](https://github.com/appsup-dart/firebase_admin/commit/2934bd8d7bd0249a402732132f7c07d5f1713ee1))


## 0.3.0+2

 - **FIX**: Converting object to an encodable object failed: Instance of 'DetailedApiRequestError'. ([bd2e8463](https://github.com/appsup-dart/firebase_admin/commit/bd2e84631a095bf50946069a85842140140ec9b3))


## 0.3.0+1

 - **FIX**: login showing error page, unregistered scope: profile. ([b0c33c68](https://github.com/appsup-dart/firebase_admin/commit/b0c33c6852419663eb386f09ec397b52b7f314de))

## 0.3.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 0.3.0-dev.5

 - **FIX**: deleting app no longer throws exception. ([e72b03d0](https://github.com/appsup-dart/firebase_admin/commit/e72b03d08538eb4af868c5c779d31dd14ed051d3))

## 0.3.0-dev.4

 - **FIX**: date time conversion from epoch. ([c98610b3](https://github.com/appsup-dart/firebase_admin/commit/c98610b33ffc946dfad02e49e9e01005c899164b))
 - **FEAT**: use iam to sign custom tokens when necessary. ([bc201eea](https://github.com/appsup-dart/firebase_admin/commit/bc201eea63a46323dcc8754851e417da863d32ea))

## 0.3.0-dev.3

 - **FIX**: throw FirebaseAuthError on error from identitytoolkit server. ([f05c9893](https://github.com/appsup-dart/firebase_admin/commit/f05c989340bac07ec26b0ba09c79251a679b9593))

## 0.3.0-dev.2

 - **FIX**: getting and updating multi factor enrollments. ([9a5d9627](https://github.com/appsup-dart/firebase_admin/commit/9a5d9627a7ff0b7ddb30aab622d3156855148389))

## 0.3.0-dev.1

 - **FIX**: nullability lastSignInTime. ([84777a48](https://github.com/appsup-dart/firebase_admin/commit/84777a480d6d3e4c235334b8d04b1f4e05486a18))

## 0.3.0-dev.0

 - **REFACTOR**: use firebaseapis for identitytoolkit api calls. ([9296f1de](https://github.com/appsup-dart/firebase_admin/commit/9296f1de9f2e9c9f2ed574e7f057973d30535b72))
 - **FIX**: lastSignInTime returning null. ([d5a5d653](https://github.com/appsup-dart/firebase_admin/commit/d5a5d65395dcb4e41a7481e80914ec91ebb8d9c0))
 - **FEAT**: support multi factor. ([4449df83](https://github.com/appsup-dart/firebase_admin/commit/4449df83675b36c03edfe46e950c87f862110be0))
 - **FEAT**: mock auth requests when testing. ([2273c1f9](https://github.com/appsup-dart/firebase_admin/commit/2273c1f9eb899feb2bd46871c0ee8dc3e26ba538))


## 0.2.0

- null safety

## 0.1.4

- upgrade openid_client dependency to 0.3.1

## 0.1.3

- fix `certFromPath` (see issue #3)
- `Credentials.applicationDefault` now also looks for a `service-account.json` file in the package main directory

## 0.1.2+1

- support latest dependencies

## 0.1.2

- admin sdk for firebase storage

## 0.1.1

- look for default credentials in Firebase CLI configurations
- get credentials by openid login


## 0.1.0

- admin sdk for firebase realtime database 
- admin sdk for firebase authentication
