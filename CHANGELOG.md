# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2025-01-27

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`firebase_admin` - `v0.3.0+1`](#firebase_admin---v0301)

---

#### `firebase_admin` - `v0.3.0+1`

 - **FIX**: login showing error page, unregistered scope: profile. ([b0c33c68](https://github.com/appsup-dart/firebase_admin/commit/b0c33c6852419663eb386f09ec397b52b7f314de))

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
