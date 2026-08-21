# Makefile — isolated-browser
# Browser isolado em Apple Container (imagem Neko/WebRTC) com launcher .app nativo.
# Uso: `make <alvo>`.

IMAGE      ?= ghcr.io/m1k1o/neko/chromium:3.1.5
NAME       ?= isolated-browser
HTTP_PORT  ?= 8080
EPR        ?= 52000-52100
APP        ?= dist/IsolatedBrowser.app

.DEFAULT_GOAL := help

.PHONY: help pull app install run stop open logs clean

help: ## Lista os alvos disponíveis
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

pull: ## Baixa a imagem do Neko (arm64/amd64)
	container image pull $(IMAGE)

app: ## Gera dist/IsolatedBrowser.app (compila Swift + ícone)
	./app/build-app.sh

install: app ## Instala o .app em /Applications
	cp -R $(APP) /Applications/
	@echo "Instalado em /Applications/IsolatedBrowser.app"

run: ## Sobe o container Neko efêmero (uso manual/dev)
	container run --rm -d --name $(NAME) \
		--env NEKO_SERVER_BIND=0.0.0.0:$(HTTP_PORT) \
		--env NEKO_EPR=$(EPR) \
		--env NEKO_SESSION_COOKIE_SECURE=false \
		--env NEKO_SESSION_IMPLICIT_HOSTING=true \
		--env 'NEKO_MEMBER_MULTIUSER_USER_PROFILE={"is_admin":true}' \
		$(IMAGE)
	@echo "Neko no ar. 'make open' para abrir a UI."

stop: ## Encerra e remove o container
	-container stop $(NAME)
	-container rm $(NAME)

open: ## Abre a UI do Neko do container em execução (navegador padrão)
	@ip=$$(container ls 2>/dev/null | awk '/$(NAME)/{print $$6}' | cut -d/ -f1); \
	if [ -z "$$ip" ]; then echo "container não está rodando; use 'make run'"; exit 1; fi; \
	open "http://$$ip:$(HTTP_PORT)/?usr=neko&pwd=neko&embed=1"

logs: ## Mostra os logs do container
	container logs $(NAME)

clean: ## Encerra o container e remove o build
	-$(MAKE) stop
	rm -rf dist
