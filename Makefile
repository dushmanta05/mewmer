.PHONY: dev build check

dev:
	bash scripts/dev.sh

build:
	cd server && go build -o mewmer-server .
	cd frontend && pnpm build

check:
	cd frontend && pnpm check
	cd server && go vet ./...
