# distcc_scripts
Few scripts to enhance distcc usability (for Windows with MSYS2)

# Installation
Run msys2.exe as Administrator
```
cp ~/.distcc/hosts ~/.distcc/hosts.all
./distcc_test.sh --install-service
cp distcc_make.sh /usr/bin/
```

# Usage:
`distcc_test.sh` runs in background as a service, periodically checks availability of hosts in `~/.distcc/hosts.all` and puts the available ones to `~/.distcc/hosts`

`distcc_make.sh` should be used instead of `make`. It runs the build locally when the amount of compilation jobs fits the local system's threads, but it distributes jobs using distcc otherwise.
