# Emulator farm: server preconditions and operations

Target: a server that runs N independent **emulator + appium** pairs for any
Appium/UiAutomator2 UI suite (a Kotlin + JUnit 5 + Gradle suite is the worked
example below). Everything is containerized; the test runner talks only to
the Appium port of a pair.

```
test runner (Gradle :appium-tests:test)
    │  HTTP  -Dappium.url=http://<farm-host>:4723
    ▼
┌─ compose project "pair1" ────────────────────────┐
│  appium (qemudroid-appium:2.15.0, port 4723) ────┼── adb over the compose
│  emulator (qemudroid-emulator:36, /dev/kvm)  ◄───┘   network, no host ports
└──────────────────────────────────────────────────┘
allure report server (optional, port 5050, shared by all pairs)
```

## Host preconditions

| Requirement | Why | Check |
|---|---|---|
| x86_64 CPU with VT-x/AMD-V | QEMU acceleration | `egrep -c '(vmx\|svm)' /proc/cpuinfo` → > 0 |
| KVM available at `/dev/kvm` | emulator will not boot without it | `ls -la /dev/kvm`; module: `lsmod \| grep kvm` |
| If the server is a VM: nested virtualization enabled | KVM inside the VM | `cat /sys/module/kvm_intel/parameters/nested` → `Y` |
| Docker Engine 24+ with the compose plugin | `docker compose` v2 syntax | `docker compose version` |
| Operator user in the `docker` group | run without sudo | `groups` |
| **No GPU needed** | SwiftShader renders on CPU | — |

Sizing per pair: **2 vCPU + ~4 GiB RAM** (emulator ~3.3 GiB + appium ~0.5 GiB).
Disk: ~7 GiB for the emulator image, ~1.5 GiB for the appium image (shared
across pairs), plus a thin overlay per running container. A 16-core/64 GiB
server comfortably runs 6–8 pairs.

Network: open one TCP port per pair (4723, 4724, …) plus 5050 for Allure,
to the CI/runner network only. Nothing else is published — the emulator's
adb/console ports stay inside the compose network.

## Build the images (once per server / per version bump)

```bash
git clone <this repo> && cd qemudroid
docker compose build          # emulator (SDK 36) + appium (2.15.0/uia2 3.9.8)
```

Other Android versions: `SDK_VERSION=35 docker compose build emulator`.
The Appium/uiautomator2 versions are pinned in `Dockerfile.appium`; keep them
in lockstep with whatever your suite pins (e.g. its `package.json`), so local
and farm runs go through identical versions.

## Run a pair

```bash
mkdir -p apk
cp /path/to/app-under-test.apk apk/    # the APK the suite will install

docker compose up -d --wait   # --wait blocks until both healthchecks pass
curl -s http://localhost:4723/status   # {"value":{"ready":true,...}}
```

`--wait` typically returns in 60–90 s: cold Android boot + appium start.
The appium sidecar waits for `sys.boot_completed=1` and **disables window
animations itself** (UiAutomator2 gets false NoSuchElement under a live
animation), so a bare pair is immediately suite-ready.

## Scale to N pairs

Each pair is an isolated compose project with its own network; only the
published Appium port differs:

```bash
COMPOSE_PROJECT_NAME=pair2 APPIUM_PORT=4724 docker compose up -d --wait
COMPOSE_PROJECT_NAME=pair3 APPIUM_PORT=4725 docker compose up -d --wait
```

Stop/remove a pair: `COMPOSE_PROJECT_NAME=pair2 docker compose down`.

## Point a suite at the farm

Example for a Kotlin + JUnit 5 + Gradle suite, on any machine that can reach
the farm host (the runner needs only a JDK — no adb, no Android SDK):

```bash
./gradlew test --rerun \
    -Dappium.url=http://<farm-host>:4723 \
    -Dapp.apk=/apk/app-under-test.apk
```

- The `app` capability is resolved by the Appium **server**, so pass the path
  as the appium container sees it: the file you dropped into `./apk/` is
  mounted at `/apk`. The runner machine does not need the APK.
- With Gradle, force a real run (e.g. `--rerun`): a cached green test task
  measures nothing.
- If the suite needs device-shell actions (broadcasts, settings) without a
  runner-side adb, use `mobile: shell` through the session — the sidecar
  already allows it (`--allow-insecure=uiautomator2:adb_shell`).
- Do not `adb connect` to the farm from workstations while a suite is
  running: a second adb client can steal the UiAutomation connection.

## Allure reports

The suite writes Allure results on the runner side to
`appium-tests/build/allure-results/`. The farm serves them:

```bash
docker compose --profile reports up -d allure
# after a suite run, drop the results into the watched directory:
rsync -a --delete appium-tests/build/allure-results/ <farm-host>:<farm-dir>/allure-results/
```

Report UI: `http://<farm-host>:5050/allure-docker-service/projects/default/reports/latest/index.html`
(the service regenerates the report automatically every few seconds when new
results land; history is kept between runs).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| emulator container unhealthy > 3 min | almost always missing/inaccessible `/dev/kvm`; `docker compose logs emulator` |
| `SessionNotCreatedException: ConnectException` in tests | appium container not up/healthy — `docker compose ps`, `curl :4723/status` |
| suite is green in 11 s | it did not run (server was down and every session failed fast, or Gradle cache served) — check the real per-test verdicts in the log/XML |
| `INSTALL_FAILED_*` on first session | broken/missing APK in `./apk`; the mount is read-only, replace the file on the host |
| two adb entries for one device on a workstation | you ran `adb connect` against the farm; `adb disconnect` — the farm itself never needs it |
| port already allocated on `up` | another pair owns it — pick a different `APPIUM_PORT`/`COMPOSE_PROJECT_NAME` |
