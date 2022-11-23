PS_SOURCES := $$(fd -epurs)

NIX_SOURCES := $(shell fd -enix)

# Add folder locations to the list to be reformatted.
format:
	@ echo "> Formatting all .purs files"
	purs-tidy format-in-place ${PS_SOURCES}
	@ echo "> Formatting all .nix files"
	nixpkgs-fmt $(NIX_SOURCES)

format_check:
	@ echo "> Checking format of all .purs files"
	purs-tidy check ${PS_SOURCES}
	@ echo "> Checking format of all .nix files"
	nixpkgs-fmt --check $(NIX_SOURCES)
