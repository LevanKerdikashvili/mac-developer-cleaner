# Mac Developer Cleaner

**Interactive disk cleanup for macOS developer environments.**

Mac Developer Cleaner is a lightweight Bash utility for reclaiming storage consumed by Android Emulator snapshots, iOS Simulator caches, Xcode build artifacts, and common package-manager caches. It shows the estimated size of each cleanup target, requires confirmation for every step, and keeps virtual-device definitions in place.

## Why it exists

Android, iOS, Java, and JavaScript development workflows can accumulate gigabytes of snapshots, temporary build data, and cached dependencies. Finding these files manually takes time and deleting them indiscriminately can break a development environment. This tool provides a transparent, opt-in approach to common cleanup targets.

## Features

- Seven independent cleanup stages with a separate `[y/N]` confirmation
- Total estimated eligible cleanup and per-stage size estimates
- Summary of approved cleanup and failed operations
- `--dry-run` preview without deletion
- Preserves Android AVD definitions, iOS Simulator devices, and simulator runtimes
- Detects active Android Emulators and booted iOS Simulators and skips their respective cleanup
- No `sudo`, Homebrew, or third-party dependencies

## Cleanup targets

| Stage | Target | Impact |
| --- | --- | --- |
| Android snapshots | `~/.android/avd/*.avd/snapshots` | Removes saved Quick Boot state; next launch may be slower |
| Android cache images | `~/.android/avd/*.avd/cache.img` | Removes emulator cache disk images |
| iOS Simulator cache | `~/Library/Developer/CoreSimulator/Caches` | Clears shared simulator cache, not devices |
| Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData` | Requires build artifacts and indexes to regenerate |
| Gradle caches | `~/.gradle/caches` | Future builds may redownload dependencies |
| Maven repository | `~/.m2/repository` | **May remove local-only artifacts that cannot be downloaded again** |
| npm cache | `~/.npm/_cacache` | Runs `npm cache clean --force` |

## Requirements

- macOS
- Bash 3.2 or later
- Optional: Xcode command-line tools and npm for their related cleanup stages

## Installation

```bash
git clone https://github.com/LevanKerdikashvili/mac-developer-cleaner.git
cd mac-developer-cleaner
chmod +x mac-dev-cleaner.sh
```

Preview the stages without deleting files:

```bash
./mac-dev-cleaner.sh --dry-run
```

Start interactive cleanup:

```bash
./mac-dev-cleaner.sh
```

For each step, enter `y` to approve or press Enter to skip. The default is **No**.

## Safety

**Close Android Studio, Xcode, Appium sessions, emulators, simulators, and active builds before cleanup.** The script avoids deleting the AVD definitions, Android userdata disk images, iOS Simulator device directories, and system runtimes. Snapshot cleanup does remove saved emulator Quick Boot states, and additional cache files can be recreated.

**Maven warning:** `~/.m2/repository` is not exclusively a cache. It may contain locally installed or private artifacts. Skip that stage unless you know you can recover its contents.

Disk usage estimates use `du` and can differ from actual free-space gains due to APFS snapshots, sparse files, and shared blocks. No cleanup operation is guaranteed to be harmless for every workflow. Review displayed paths before approving any deletion.

## Author

Levan Kerdikashvili - [GitHub](https://github.com/LevanKerdikashvili)

## License

MIT - see [LICENSE](LICENSE).
