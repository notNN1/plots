init: docker-build install

docker-build:
	docker compose build

install:
	docker compose run --rm r ./scripts/setup/install.R

example-pdf:
	docker compose run --rm r ./scripts/examples/example_pdf.R
	docker compose run --rm r ./scripts/examples/example_breakdown_plot.R

example-tex:
	docker compose run --rm r ./scripts/examples/example_tex.R

test:
	docker compose run --rm r ./tests/test.R
