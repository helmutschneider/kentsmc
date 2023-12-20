# KentSMC
A simple tool to read & write to the SMC on Macs.

```
Usage:
  kentsmc -r [key]               Read a key
  kentsmc -r [key] -w [value]    Write a key
  kentsmc -l                     Dump all keys
  kentsmc -f <filter>            Read keys matching <filter>
  kentsmc --fan-rpm <rpm>        Activates fan manual mode (F%Md) and sets the target rpm (F%Tg)
  kentsmc --fan-auto             Disables fan manual mode
```

## Building
```
# build the thing:
make

# run the thing:
./bin/kentsmc
```

## References
[iSMC](https://github.com/dkorunic/iSMC)

[SMCKit](https://github.com/beltex/SMCKit)

[SilentStudio](https://github.com/dirkschreib/SilentStudio)
