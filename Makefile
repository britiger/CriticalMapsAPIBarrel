include properties.mk

appName = `grep module manifest.xml | sed 's/.*module="\([^"]*\).*/\1/'`
JAVA_OPTIONS = JDK_JAVA_OPTIONS="--add-modules=java.xml.bind"

build:
	$(SDK_HOME)/bin/barrelbuild \
	--jungle-files ./monkey.jungle \
	--output bin/$(appName).prg \
	--warn