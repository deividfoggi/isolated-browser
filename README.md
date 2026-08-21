# Isolated Browser

Um browser **isolado e descartável** que roda dentro de um [Apple Container](https://github.com/apple/container) e é acessado por um app nativo no macOS. A navegação acontece inteiramente dentro do container (imagem [Neko](https://github.com/m1k1o/neko), streaming por WebRTC com **vídeo e áudio**), sem tocar no sistema de arquivos do host. Cada sessão é **efêmera**: ao fechar a janela, o container é destruído e nada persiste.

## Por que

- **Isolamento**: o browser não enxerga o filesystem do host; sites potencialmente não confiáveis ficam contidos numa VM Linux efêmera.
- **Descartável**: sem histórico, cookies ou cache entre sessões — fechou, acabou.
- **Nativo**: abre por um ícone em Aplicativos, em janela própria (privada), com áudio.

## Pré-requisitos

- macOS em Apple Silicon (testado no macOS 26).
- [Apple Container CLI](https://github.com/apple/container) instalado e o serviço iniciado:
  ```sh
  container system start
  container --version   # 1.2.x
  ```
- Xcode Command Line Tools (para compilar o app): `xcode-select --install`.

> O app do host usa **WKWebView** (WebKit do sistema) — não é necessário Chrome/Firefox instalado.

## Instalação

```sh
# 1) Baixe a imagem do browser (Neko/Chromium, arm64)
make pull

# 2) Gere e instale o app em /Applications
make install
```

Isso compila `dist/IsolatedBrowser.app` e copia para `/Applications`.

### Primeira execução (Gatekeeper)

O app é assinado **ad-hoc** (não notarizado). Na primeira vez, abra com o botão direito → **Abrir** (ou remova o atributo de quarentena):

```sh
xattr -dr com.apple.quarantine /Applications/IsolatedBrowser.app
```

## Uso

1. Abra **Isolated Browser** (Aplicativos ou Spotlight).
2. Aguarde alguns segundos: o app sobe o container e carrega o browser numa janela maximizada.
3. Navegue normalmente — com áudio.
4. **Feche a janela** para encerrar: o container é parado e removido automaticamente.

## Como funciona

```
┌──────────────── macOS (host) ─────────────────┐
│  IsolatedBrowser.app (Swift + WKWebView)       │
│   • sobe o container efêmero                   │
│   • carrega http://<ip-do-container>:8080      │
│   • janela privada, maximizada                 │
│   • ao fechar → mata o container               │
└──────────────────────┬─────────────────────────┘
                        │ WebRTC (vídeo + áudio) + WebSocket
        ┌───────────────▼─────────────────┐
        │ Apple Container (VM Linux, --rm) │
        │   Neko: Chromium + PulseAudio    │
        │   egresso via NAT                │
        │   sem montagens do host          │
        └──────────────────────────────────┘
```

Detalhes de arquitetura e decisões em [docs/architecture/decisions](docs/architecture/decisions) e [docs/features/isolated-browser](docs/features/isolated-browser).

## Comandos (Makefile)

| Alvo | O que faz |
|------|-----------|
| `make pull` | Baixa a imagem do Neko |
| `make app` | Gera `dist/IsolatedBrowser.app` |
| `make install` | Gera e instala o `.app` em `/Applications` |
| `make run` | Sobe o container Neko (uso manual/dev) |
| `make open` | Abre a UI do Neko no navegador padrão |
| `make stop` | Encerra e remove o container |
| `make clean` | `stop` + remove `dist/` |

## Isolamento e segurança

- **Sem montagens do host**: o container roda com `--rm` e **sem** `-v`; nenhum caminho do host é acessível.
- **Efêmero**: nada persiste entre sessões (perfil, histórico, cookies, downloads).
- **Host-local**: a porta do Neko é acessada apenas pelo IP privado do container (sub-rede do Apple Container); não é publicada na LAN.
- **App privado**: o WKWebView usa um _data store_ não-persistente (nada gravado em disco no host).
- **Autenticação relaxada**: por ser acesso host-local, single-user e efêmero, o login do Neko é dispensado no cliente. Se for expor o container além do host, reative a autenticação.

## Escopo

Incluído: browser gráfico com áudio, isolamento de filesystem, sessões efêmeras, launcher `.app`.
Fora de escopo: persistência de dados, isolamento de rede/clipboard, compartilhamento de arquivos host↔container.

## Build a partir do fonte

```sh
make app                       # gera dist/IsolatedBrowser.app
open dist/IsolatedBrowser.app  # testa sem instalar
```

Fonte do app: [app/IsolatedBrowser.swift](app/IsolatedBrowser.swift) · ícone: [app/make-icon.swift](app/make-icon.swift) · bundle: [app/build-app.sh](app/build-app.sh).
