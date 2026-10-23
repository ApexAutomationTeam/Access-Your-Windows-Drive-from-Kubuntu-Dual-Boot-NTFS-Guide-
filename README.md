# Access Your Windows Drive from Kubuntu (Dual-Boot NTFS Guide)

**Fix "Windows is hibernated, refused to mount" for good, and read and write your Windows drive from Kubuntu (or any Ubuntu/Debian-based Linux).** A short permanent fix, ready-to-use commands, two helper scripts and an auto-mount setup.

> Built by [Apex Automation Team](https://apexautomationteam.com/). See real automation builds running on the **[Sample Works page](https://apexautomationteam.com/sample-works/)**.

---

## The problem

On a Windows + Linux dual-boot laptop, Windows "Shut down" is not a full shutdown by default. **Fast Startup** (a partial hibernation) leaves the NTFS drive in a locked, "unsafe" state. Linux then refuses to mount it read-write and shows errors like:

```
The disk contains an unclean file system (0, 0).
Metadata kept in Windows cache, refused to mount.
The NTFS partition is in an unsafe state. Please resume and shutdown Windows fully
(no hibernation or fast restarting), or mount the volume read-only with the 'ro' mount option.
```

## The fix in 3 steps

**1. In Windows:** open Command Prompt **as Administrator** and run

```bat
powercfg /h off
```

This turns off hibernation, and with it Fast Startup. The `ntfs-3g` documentation recommends exactly this command for dual-boot computers.

**2. Shut down Windows completely** (Start > Power > **Shut down**), then start Kubuntu. Do not use hibernate or sleep for switching systems.

**3. In Kubuntu:** press `Ctrl + Alt + T` and run

```bash
sudo mkdir -p /mnt/windows
sudo mount -t ntfs-3g /dev/nvme0n1p3 /mnt/windows
```

Your files are now in `/mnt/windows`.

> `/dev/nvme0n1p3` is only an example. Your Windows partition may have a different name. Find it with `lsblk -f` (look for `ntfs` and the biggest size, which is usually your `C:` drive; the small NTFS "Recovery" partition is not the one you want).

**If the terminal says to reload systemd** (`systemctl daemon-reload`), just run it and repeat the mount command:

```bash
sudo systemctl daemon-reload
```

That hint appears when `/etc/fstab` was changed after systemd last read it. It is harmless.

> **Golden rule: when switching between Windows and Kubuntu, shut down fully instead of restarting.** With hibernation off, a normal shutdown is a full shutdown, and it releases the drive cleanly for Linux.

---

## Helper scripts

| Script | What it does |
|---|---|
| `scripts/mount-windows-drive.sh` | Lists NTFS partitions, mounts one read-write with your user as owner, explains the hibernation error if it appears |
| `scripts/unmount-windows-drive.sh` | Syncs and safely unmounts before you shut down |
| `scripts/fstab.example` | A ready-made line for automatic mounting at boot |

```bash
chmod +x scripts/*.sh

./scripts/mount-windows-drive.sh                    # no argument: list NTFS partitions
./scripts/mount-windows-drive.sh /dev/nvme0n1p3     # mount at /mnt/windows (read-write)
./scripts/mount-windows-drive.sh -r /dev/nvme0n1p3  # read-only, always safe
./scripts/mount-windows-drive.sh -p ~/WinDrive /dev/nvme0n1p3   # custom mount folder

./scripts/unmount-windows-drive.sh                  # unmount /mnt/windows
```

The scripts ask for `sudo` themselves and refuse to touch non-NTFS devices.

## Handy commands

| Goal | Command |
|---|---|
| List all disks and partitions | `lsblk -f` |
| Get a partition's UUID | `sudo blkid /dev/nvme0n1p3` |
| See your user and group id | `id` |
| Install the NTFS driver (if missing) | `sudo apt install ntfs-3g` |
| Mount read-only (safe fallback) | `sudo mount -t ntfs-3g -o ro /dev/nvme0n1p3 /mnt/windows` |
| Mount read-write, your user owns the files | `sudo mount -t ntfs-3g -o rw,uid=$(id -u),gid=$(id -g),umask=022,windows_names /dev/nvme0n1p3 /mnt/windows` |
| Check what is mounted | `findmnt /mnt/windows` |
| Unmount | `sync && sudo umount /mnt/windows` |
| See what blocks an unmount | `fuser -vm /mnt/windows` |
| Re-enable hibernation in Windows later | `powercfg /h on` (admin Command Prompt) |
| Check Windows sleep states | `powercfg /a` (admin Command Prompt) |

### Mount options explained

| Option | Meaning |
|---|---|
| `rw` / `ro` | read-write / read-only |
| `uid=` `gid=` | Make your Linux user own the files (otherwise only root can write) |
| `umask=022` | Everyone can read, only the owner can write |
| `windows_names` | Prevents creating file names Windows cannot open (such as `:` or `?`) |

---

## Mount automatically at every boot (optional)

1. Find the UUID: `sudo blkid /dev/nvme0n1p3`
2. Create the folder: `sudo mkdir -p /mnt/windows`
3. Back up the file: `sudo cp /etc/fstab /etc/fstab.bak`
4. Add one line to `/etc/fstab` (`sudo nano /etc/fstab`), using your UUID and user id:

```
UUID=XXXXXXXXXXXXXXXX  /mnt/windows  ntfs-3g  defaults,uid=1000,gid=1000,umask=022,windows_names,nofail,x-systemd.device-timeout=5  0  0
```

5. Test without rebooting: `sudo systemctl daemon-reload && sudo mount -a`

`nofail` keeps Linux booting normally even if Windows left the drive locked. Mistakes in `/etc/fstab` can cause boot problems, which is why step 3 makes a backup.

---

## Other ways to turn off Fast Startup

If you prefer not to disable hibernation completely:

- **Windows settings:** Control Panel > Power Options > *Choose what the power buttons do* > *Change settings that are currently unavailable* > untick **Turn on fast startup** > Save.
- **Command line (admin):** `reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f`

`powercfg /h off` remains the simplest option and also frees disk space used by the hibernation file.

## Troubleshooting

| Problem | What to do |
|---|---|
| Still "Windows is hibernated" | Boot Windows, run `powercfg /h off` as Administrator, then **Shut down** fully and boot Linux. Do not use Restart, Sleep or Hibernate. Mount read-only meanwhile with `-o ro` |
| It worked before, now locked again | A big Windows update can turn hibernation or Fast Startup back on. Run `powercfg /h off` again |
| `unknown filesystem type 'ntfs-3g'` | `sudo apt install ntfs-3g` |
| Drive mounts but you cannot write | Mount with `uid=` and `gid=` (see above), and make sure it is not mounted `ro` |
| `target is busy` when unmounting | Close the file manager and terminals using it. Find the culprit with `fuser -vm /mnt/windows` |
| `wrong fs type` / BitLocker | A BitLocker-encrypted drive must be unlocked first (for example with the `dislocker` tool). Plain `mount` cannot read it |
| Volume is corrupt | Boot Windows and run `chkdsk /f` on the drive, then shut down fully |

### Last resorts (read the warnings first)

- Running `ntfsfix` on the partition (it is part of the `ntfs-3g` package; check `man ntfsfix` for the exact options on your version) can clear the hibernation state from Linux. **Windows will not resume its saved session**, so anything unsaved in Windows is lost.
- `-o remove_hiberfile` on the mount command deletes the hibernation file for the same purpose, with the same data-loss risk.

Prefer the Windows-side fix above. It addresses the cause instead of working around it.

## Safety rules

- Never write to the Windows system folders (`Windows`, `Program Files`) from Linux.
- Never mount a hibernated Windows drive read-write. That is what can corrupt data.
- Keep a backup of important files before editing a Windows drive from Linux.
- Always unmount (or fully shut down) before booting Windows again.

## Tested on

The scripts were checked with `shellcheck` and tested against simulated system commands covering success, read-only, already mounted, wrong device, missing driver, hibernation error, and busy unmount. Not tested on your specific hardware, so try read-only first if the drive holds important data. Applies to Windows 8, 10 and 11 with Kubuntu, Ubuntu and similar distributions.

---

## Roman Urdu mukhtasar (quick summary)

1. Windows mein **Command Prompt (Run as administrator)** kholen aur chalayen: `powercfg /h off`
2. Windows ko **Shut down** karen (Restart nahi), phir Kubuntu mein boot karen.
3. Kubuntu mein `Ctrl + Alt + T` dabayen aur chalayen: `sudo mount -t ntfs-3g /dev/nvme0n1p3 /mnt` (apni partition `lsblk -f` se dekh len).
4. Agar `systemctl daemon-reload` ka kahe to `sudo systemctl daemon-reload` chala kar dobara mount karen.
5. **Yaad rakhen:** OS badalte waqt hamesha Shut down karen, tab Windows drive Kubuntu ke liye unlock rehta hai.

## Maintenance & support

Operating systems and updates change behaviour over time. If something here stops working or you hit an unexpected error, email **[contact@apexautomationteam.com](mailto:contact@apexautomationteam.com)** with the exact error text and the output of `lsblk -f`, and we will look into it.

## Need a custom tool?

We build automation, scrapers, QA and back-office systems to your exact spec and keep them updated. Write to **[contact@apexautomationteam.com](mailto:contact@apexautomationteam.com)**, visit **[Apex Automation Team](https://apexautomationteam.com/)**, or see more builds on the **[Sample Works page](https://apexautomationteam.com/sample-works/)**.

## License

Add your preferred license (for example MIT) before publishing.
