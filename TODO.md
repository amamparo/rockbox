Add a `make install` command to the root Makefile

this command should:
1. check with diskutil if an ipod is connected
  * if one isn't detected, print a message and exit
  * if one is detected but isn't mounted to `/Volumes/IPOD`, mount it there
1. deploys the built rockbox into the ipod by fully replacing everything in `/Volumes/IPOD/.rockbox` with the version built here

Later on, I'll add capabilities for mainting .cfg settings files and copying custom themes