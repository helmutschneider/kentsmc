CC=swiftc
OUT=kentsmc
all: clean gen_keys
	mkdir -p bin && $(CC) Keys.swift KentSMC.swift  -o bin/$(OUT)
gen_keys:
	swift GenKeys.swift > Keys.swift
clean:
	rm -rf bin Keys.swift
