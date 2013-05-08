all:
	xcodebuild

osax:
	cd qsx-osax; xcodebuild

install:
	cp -rf build/Release/qsx.app /Applications
	rm -rf /System/Library/ScriptingAdditions/qsx.osax
	cp -rf qsx-osax/bin/qsx.osax /System/Library/ScriptingAdditions/qsx.osax

