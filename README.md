# pub2yocto

## Introduction
pub2yocto is a tool that generates a detailed source URL list based on the `pubspec.lock` file.

The generated result is for the Yocto build recipe. It should manage dependent packages through the do_fetch and do_unpack stages.

## Installing

Adding the package name to `dev_dependencies`; not to `dependencies` because the package does nothing on runtime.

```shell
flutter pub add dev:pub2yocto
```

or

```yaml
dev_dependencies:
  pub2yocto: ^0.1.0
```

## Generate recipe

Before executing the command, you must update your `pubspec.lock` using `pub get` (or `pub upgrade` if you want).

```shell
flutter pub get
dart run pub2yocto
```
## In your Flutter App recipe
PUB_CACHE_LOCAL is a relative path starting from ${WORK_DIR} that specifies the pub_cache 
path used in each individual recipe. The default path is ${WORK_DIR}/pub_cache.
