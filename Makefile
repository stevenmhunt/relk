install: test
	chmod +x ./scripts/install.sh && sudo ./scripts/install.sh

test: build
	chmod +x ./scripts/test.sh && ./scripts/test.sh

build:
	chmod +x ./scripts/build.sh && ./scripts/build.sh

ci:
	chmod +x ./scripts/ci.sh && ./scripts/ci.sh