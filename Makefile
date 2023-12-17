CC=swiftc
OUT=kentsmc
all: clean
	mkdir -p bin && $(CC) KentSMC.swift -o bin/$(OUT)
clean:
	rm -rf bin

