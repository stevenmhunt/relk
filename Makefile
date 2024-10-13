install:
	chmod +x ./scripts/install.sh && sudo ./scripts/install.sh

test:
	chmod +x ./scripts/test.sh && ./scripts/test.sh

ci:
	chmod +x ./scripts/ci.sh && ./scripts/ci.sh