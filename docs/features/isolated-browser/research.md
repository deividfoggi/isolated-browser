# Research — isolated-browser

Consolidação das decisões e do conhecimento técnico que fundamentam o `plan.md`.

## Contexto da plataforma (Apple Container)

- O `container` CLI da Apple executa **VMs Linux leves** no macOS; não há passthrough de GUI para o host.
- Cada container recebe um **IP dedicado** na sub-rede do Apple Container, alcançável a partir do host → o acesso ao serviço gráfico se dá por esse IP.
- Rede de egresso via **NAT padrão** do container (atende RF-006 sem configuração extra).
- Build de imagem via `container build` (formato OCI/Dockerfile).
- Execução efêmera com `container run --rm` e **sem** `-v`/montagens → atende RF-004/RF-005/RNF-002 e INV-001/INV-002.

## Decisões-chave (ver ADRs)

| Tema | Decisão | ADR |
|------|---------|-----|
| Acesso gráfico | noVNC (Xvfb + VNC + websockify + cliente web) na porta `6080` | ADR-0001 |
| Imagem/empacotamento | Debian/Ubuntu slim + Chromium + stack de display via `apt` | ADR-0002 |
| Launcher | Bundle `.app` com script wrapper gerado por `build-app.sh` | ADR-0003 |

## Alternativas descartadas

- **VNC puro + Screen Sharing** (ADR-0001 Opção B): depende do estado do Screen Sharing do macOS; UX de autoconnect/resize inferior.
- **Alpine/musl** (ADR-0002 Opção B): Chromium mais frágil; mais atrito de depuração.
- **Imagem pública pronta** (ADR-0002 Opção C): menor controle/auditabilidade do isolamento.
- **Automator/Platypus** (ADR-0003 Opções B/C): menos versionável e mais dependências.

## Pontos de atenção para implementação

- Nome do pacote Chromium varia por distro (`chromium` vs `chromium-browser`) — confirmar na base escolhida.
- Chromium roda com `--no-sandbox` (o container/VM é o limite de sandbox) — trade-off registrado no ADR-0002.
- Senha de VNC **efêmera por sessão** (tmpfs/env), nunca fixa/persistida — ADR-0001/ADR-0003.
- Gatekeeper: `.app` não assinado exige "abrir mesmo assim" na primeira execução — documentar no README.
- Confirmar a forma de resolução do IP do container (`container inspect`/`container ls`) na versão instalada do CLI.

## Não aplicável a esta feature

- **data-model.md**: a feature não possui modelo de dados persistido; a única entidade ("Sessão de Browser Isolado") é efêmera e sem esquema. Omitido intencionalmente.
- **contracts/**: não há API pública nem contrato de rede exposto além da porta noVNC host-local. Omitido intencionalmente.
