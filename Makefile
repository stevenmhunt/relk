install: test
	chmod +x ./scripts/install.sh && sudo ./scripts/install.sh

test: build
	chmod +x ./scripts/test.sh && ./scripts/test.sh

build:
	chmod +x ./scripts/build.sh && ./scripts/build.sh

lint:
	shellcheck ./src/**/*.sh -e "SC2148,SC2001"

ci:
	chmod +x ./scripts/ci.sh && ./scripts/ci.sh