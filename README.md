# qemudroid (android-in-docker-qemu)

Google Android Emulator (AVD) running headless in Docker: QEMU + KVM with
SwiftShader software rendering. **No GPU required** — everything renders on
the CPU, so it runs on any x86_64 host with KVM. Built for CI farms and basic
automation needs.

Verified boot (Android 16, `google_apis;x86_64`, boots in under a minute):

![Booted home screen](docs/screenshot.png)

## Requirements

- x86_64 host with KVM enabled (`/dev/kvm`)
- Docker with the compose plugin

## Quick start: emulator + Appium pair

The intended way to consume this repo: `docker compose` brings up an
**emulator container and an Appium sidecar container** wired together over
the compose network. The test runner only ever talks to the Appium port —
no adb on the host, nothing bound to localhost by default.

```bash
docker compose build          # emulator (SDK 36) + appium (pinned 2.15.0)

mkdir -p apk && cp /path/to/app-under-test.apk apk/
docker compose up -d --wait   # blocks until Android is booted and Appium is ready

curl -s http://localhost:4723/status        # {"value":{"ready":true,...}}
```

Run a suite against it (the `app` capability is a path **inside the appium
container**, i.e. under the mounted `/apk`):

```bash
./gradlew test --rerun \
    -Dappium.url=http://<host>:4723 \
    -Dapp.apk=/apk/app-under-test.apk
```

The appium sidecar waits for full boot and disables window animations itself,
so a fresh pair is immediately suite-ready. Multiple pairs, host
preconditions, sizing, and the Allure report server: see **[docs/farm.md](docs/farm.md)**.

## Quick start: bare emulator

For a single emulator with adb from the host:

```bash
# 1. Build the emulator image (~6.7 GB: Android SDK + system image + AVD)
docker build -f Dockerfile.emulator -t qemudroid-emulator:latest .

# 2. Run (KVM passthrough is required)
docker run -d --name qemudroid \
  --device /dev/kvm \
  -p 127.0.0.1:5554:5554 \
  -p 127.0.0.1:5555:5555 \
  qemudroid-emulator:latest

# 3. Connect
adb connect localhost:5555
adb devices                      # emulator-5554 / localhost:5555
```

Wait for full boot with:

```bash
docker exec qemudroid adb wait-for-device
docker exec qemudroid adb shell getprop sys.boot_completed   # "1" when ready
```

## Build options

| Build arg | Default | Notes |
|-----------|---------|-------|
| `SDK_VERSION` | `36` (Android 16) | AVD profiles exist for 30–37: see `hardware/config_*.ini` |
| `EMULATOR_ARCH` | `x86_64` | `x86` also supported |
| `APPIUM_VERSION` / `UIAUTOMATOR2_VERSION` | `2.15.0` / `3.9.8` (Dockerfile.appium) | keep in sync with the suite's pinned toolchain |

```bash
docker build -f Dockerfile.emulator --build-arg SDK_VERSION=35 -t qemudroid-emulator:35 .
```

Verified working: SDK 30 (Android 11), 35 (Android 15), 36 (Android 16) — all
boot in well under a minute. SDK 37 (Android 17): the profile is ready, but
Google has not published a `system-images;android-37` image yet (checked
2026-07, stable and canary channels) — the build will work as soon as it
appears.

The AVD profile (`hardware/config_<SDK>.ini`) is intentionally light for CI:
320x480 @ 120dpi, 2 cores, 2 GB guest RAM. A running container uses ~3.3 GiB
of host RAM.

## Runtime options (emulator container)

| Env var | Default | Notes |
|---------|---------|-------|
| `SDK_VERSION` | build arg value | Set automatically from the build; must match a baked-in system image |
| `EMULATOR_ARCH` | `x86_64` | |
| `CONSOLE_PORT` / `ADB_PORT` | `5554` / `5555` | Emulator console / ADB |
| `WINDOW` | unset | `true` renders into an X11 window (pass the X11 socket and `DISPLAY`) |

## Ports

| Port | Purpose |
|------|---------|
| 5037 | ADB server |
| 5554 | Emulator console |
| 5555 | ADB |
| 5900 | VNC (exposed, not started by default) |
| 4723 | Appium (the only port a compose pair publishes) |

All emulator ports are bound to the container's `eth0` via `socat`
(`scripts/adb_redirect.sh`), so plain `docker -p` mappings work — but in the
compose pair none of them are published: only the Appium sidecar reaches the
emulator, over the compose network.

## Repository layout

```
.
├── docker-compose.yml      # emulator + appium pair (+ optional allure server)
├── Dockerfile.emulator     # emulator image: SDK + system image + AVD + entrypoint
├── Dockerfile.appium       # appium sidecar: pinned appium + uiautomator2 + adb
├── Dockerfile.builder      # legacy CI runner image (Marathon + allurectl)
├── packages.txt            # SDK packages for the builder image
├── hardware/               # AVD profiles per SDK version (config_30..37.ini)
├── docs/farm.md            # farm server: preconditions, scaling, Allure
└── scripts/
    ├── entrypoint.sh              # emulator container entrypoint: redirect + run
    ├── run_emulator.sh            # start the QEMU emulator binary
    ├── adb_redirect.sh            # socat: expose adb/console ports on eth0
    ├── prepare_snapshot.sh        # boot once and save a "ci" snapshot
    ├── wait_for_device.sh         # block until sys.boot_completed=1
    └── appium_entrypoint.sh       # appium container entrypoint: wait, connect, serve
```

## Marathon / adb-based runners

The compose pair covers Appium suites; runners that need raw adb access —
e.g. [Marathon](https://github.com/MarathonLabs/marathon) for sharded
instrumentation runs — can reach a pair's emulator through the optional
`adb` profile (a socat bridge, off by default so the closed topology stays
Appium-only):

```bash
docker compose --profile adb up -d
adb connect localhost:5555        # ADB_PORT/ADB_BIND to customize
```

`Dockerfile.builder` is the runner image for that flow (Android SDK +
Marathon + [allurectl](https://github.com/allure-framework/allurectl)):

```bash
docker build -f Dockerfile.builder -t qemudroid-builder:latest .
```

Alternatively, attach any runner container straight to a pair's network,
no published ports at all:
`docker run --network <project>_default ... adb connect emulator:5555`.
