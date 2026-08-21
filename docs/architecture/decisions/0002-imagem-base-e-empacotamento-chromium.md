# ADR-0002: Imagem base do container e empacotamento do Chromium

| Campo | Valor |
|-------|-------|
| Status | Proposed |
| Data | 2026-08-21 |
| Decisores | Equipe isolated-browser |
| Feature | isolated-browser |

> **Nota (2026-08-21):** A decisão de base (Debian slim + Chromium via apt) **permanece válida**, mas o **conjunto de pacotes de display mudou**: `xvfb` + `x11vnc` + `websockify` + `novnc` foi substituído por **KasmVNC** (servidor Xvnc com web + áudio integrados) + **PulseAudio**, conforme a [ADR-0004](0004-audio-e-acesso-grafico-via-kasmvnc.md). Onde este documento cita a stack noVNC, leia KasmVNC + PulseAudio.

## Contexto

O container precisa hospedar o Chromium mais a stack de display gráfico definida no ADR-0001 (Xvfb, servidor VNC, websockify, noVNC). A imagem deve ser construída via `container build` (OCI) e priorizar iteração rápida (RNF-001) e isolamento total (nenhuma montagem do host, RNF-002). A sessão é efêmera: todo estado do Chromium (perfil, cache, cookies) vive apenas no filesystem interno do container e desaparece com `--rm` (RF-005, INV-002).

## Decision Drivers

- Disponibilidade de pacote Chromium estável e de Xvfb/VNC/websockify/noVNC.
- Simplicidade do Dockerfile e velocidade de build/rebuild.
- Compatibilidade com arquitetura arm64 (Apple Silicon) — o Apple Container roda VMs Linux na arquitetura do host.
- Tamanho de imagem razoável.

## Opções Consideradas

### Opção A — Base Debian/Ubuntu slim com Chromium do repositório da distro

`debian:stable-slim` ou `ubuntu:24.04` + `apt-get install chromium xvfb x11vnc websockify novnc fluxbox` (nomes de pacote variam por distro).

- **Prós**: pacotes bem mantidos; arm64 nativo; Dockerfile simples e legível; rebuild rápido com cache de camadas.
- **Contras**: imagem maior que Alpine; nome do pacote Chromium varia (`chromium` vs `chromium-browser`).

### Opção B — Base Alpine com Chromium

`alpine` + `apk add chromium xvfb x11vnc ...`.

- **Prós**: imagem menor.
- **Contras**: Chromium no Alpine (musl) historicamente mais frágil para fontes/codecs; mais atrito de depuração → contraria RNF-001.

### Opção C — Reaproveitar imagem pública "chromium+vnc" pronta

- **Prós**: menor esforço inicial.
- **Contras**: menos controle sobre versão/superfície; dependência externa de terceiros; auditoria mais difícil para requisito de isolamento.

## Decisão

Adotar a **Opção A — base Debian/Ubuntu slim** com Chromium e stack de display instalados via gerenciador de pacotes, em um `Dockerfile` próprio versionado no repositório.

Detalhes de empacotamento:

- Gerenciador de janelas mínimo (`fluxbox` ou `openbox`) para o Chromium abrir maximizado de forma previsível.
- Chromium iniciado com `--no-sandbox` (o container/VM já é o limite de sandbox) + `--user-data-dir` em diretório efêmero interno (tmpfs), `--start-maximized`/kiosk conforme UX.
- Um entrypoint (script shell ou `supervisord`) orquestra Xvfb → WM → servidor VNC → websockify/noVNC → Chromium.

## Consequências

**Positivas**

- Controle total da versão do Chromium e da superfície da imagem.
- Build/rebuild rápidos com cache de camadas (RNF-001).
- arm64 nativo no Apple Silicon.

**Negativas / Mitigações**

- `--no-sandbox` reduz a defesa em profundidade **dentro** do Chromium, porém o isolamento primário é o container/VM efêmero — trade-off aceitável e alinhado ao escopo. Registrar a justificativa.
- Imagem maior que Alpine → aceitável frente ao ganho de estabilidade e velocidade de desenvolvimento.
- Verificar o nome correto do pacote Chromium na distro escolhida durante a implementação.
