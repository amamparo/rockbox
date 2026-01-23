Add a `make install` command to the root Makefile

this command should:
1. check with diskutil if an ipod is connected
   * if one isn't detected, print a message and exit
   * if one is detected but mounted elsewhere (e.g., `/Volumes/AARON'S IPOD`), unmount and remount to `/Volumes/IPOD`
2. deploy the built rockbox by extracting `output/rockbox.zip` to `/Volumes/IPOD/`, fully replacing the `.rockbox` directory
   * create `.rockbox` if it doesn't exist (fresh install case)
   * note: `rockbox.zip` contains the `.rockbox` folder with codecs, plugins, themes, etc.
   * note: `rockbox.ipod` is the bootloader (installed separately via `ipodpatcher`, not needed for updates)
3. eject/unmount the iPod after deployment

Later on, I'll add capabilities for maintaining .cfg settings files and copying custom themes