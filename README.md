# pub2yocto

## Introduction
pub2yocto is a tool that generates a detailed source URL list based on the `pubspec.lock` file.

The generated result is for the Yocto build recipe. It should manage dependent packages through the do_fetch and do_unpack stages.

## Installing

Adding the package name to `dev_dependencies`; not to `dependencies` because the package does nothing on runtime.

```shell
flutter pub add --dev pub2yocto
```

Or manually add it to your `pubspec.yaml` under `dev_dependencies`:

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

You can specify an input file (`pubspec.lock` by default) and an output file for the generated recipe using command-line options:

```shell
dart run pub2yocto -i path/to/pubspec.lock -o path/to/output.bbappend
```

### Options:

- `-i, --input`: Specify the input file. Defaults to `pubspec.lock`.
- `-o, --output`: Specify the output file name for the generated recipe. If not provided, `pub2yocto` generates a `.bbappend` file named after the project defined in `pubspec.yaml`.

## In Your Flutter App Recipe

`pub2yocto` generates Yocto recipes that assume a `PUB_CACHE_LOCAL` environment variable. This variable is a relative path from `${WORK_DIR}` that specifies the `pub_cache` path used by individual recipes. If not set, it defaults to `${WORK_DIR}/pub_cache`.

Ensure this setup aligns with your Yocto project's configuration for smooth integration.

