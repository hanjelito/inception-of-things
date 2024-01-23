NAME = inseption_of_things

all: clean install config

clean:
	@echo "Cleaning..."
	# Aquí puedes añadir comandos para limpiar tu entorno

install:
	@echo "Building..."
	@./scripts/install.sh

config:
	@echo "Configuring..."
	@./scripts/config.sh

delete:
	@echo "Deleting..."
	@docker rm -f $$(docker ps -a -q) || true
	@docker rmi -f $$(docker images -q) || true
	@docker volume rm $$(docker volume ls -q) || true