# distcc_scripts
Few scripts to enhance distcc usability (for Windows with MSYS2)

# Installation
Run msys2.exe as Administrator
```
cp ~/.distcc/hosts ~/.distcc/hosts.all
./install.sh
```

# Usage:
File `~/distcc/hosts.all` could look like this:
```
miso-pc/8,lzo
miro-pc/4,lzo
lubo-pc/8,lzo
```

`distcc_make.sh` should be used instead of `make`. It runs the build locally when the amount of compilation jobs fits the local system's threads, but it distributes jobs using distcc otherwise.

`make -j8` becomes `distcc_make.sh -j8`, compiling up to 8 files locally, but in case of more files, they are distributed using distcc to remote hosts.

# Checking availability of hosts
`distcc_test.sh` runs in background as a service, periodically checks availability of hosts in `~/.distcc/hosts.all` and puts the available ones to `~/.distcc/hosts`
