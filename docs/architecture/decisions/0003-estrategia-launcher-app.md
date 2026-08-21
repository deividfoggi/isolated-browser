# ADR-0003: Estratégia do launcher `.app` no macOS

| Campo | Valor |
|-------|-------|
| Status | Proposed |
| Data | 2026-08-21 |
| Decisores | Equipe isolated-browser |
| Feature | isolated-browser |

## Contexto

O RF-007/RF-008 exigem um launcher `.app` instalável na pasta Aplicativos que, com um duplo-clique, (1) inicie o container isolado e (2) abra automaticamente a UI gráfica do browser, sem etapas manuais em terminal. O mecanismo de display é noVNC (ADR-0001) e a imagem é construída conforme ADR-0002.

O Apple Container atribui um IP dedicado a cada container; o acesso ao noVNC se dá por esse IP (host-local). O launcher precisa: iniciar o container, resolver o IP, aguardar a porta ficar pronta e abrir o navegador do host na URL de autoconnect.

## Decision Drivers

- Duplo-clique único, zero terminal (RF-008).
- Iteração rápida: o `.app` deve ser (re)gerável por script (RNF-001).
- Ciclo de vida limpo: encerrar/remover o container ao fim (efemeridade, INV-002).

## Opções Consideradas

### Opção A — Bundle `.app` mínimo com script shell wrapper

`IsolatedBrowser.app/Contents/MacOS/IsolatedBrowser` é um script shell + `Contents/Info.plist`. O `.app` é gerado por um `build-app.sh` versionado.

- **Prós**: total controle do fluxo (start → resolve IP → poll → open → cleanup); trivial de versionar e regerar; sem dependências além do `container` CLI.
- **Contras**: bundle não assinado por padrão (Gatekeeper pode exigir `xattr -dr com.apple.quarantine` ou clique com botão direito → Abrir na primeira execução).

### Opção B — App gerado por Automator/AppleScript (`.app`)

- **Prós**: integração nativa.
- **Contras**: fluxo de poll/cleanup mais desajeitado; mais difícil de versionar como código; menos transparente.

### Opção C — Ferramenta empacotadora (Platypus e similares)

- **Prós**: gera `.app` a partir de script com UI.
- **Contras**: adiciona dependência de ferramenta externa; contraria simplicidade/RNF-001.

## Decisão

Adotar a **Opção A — bundle `.app` mínimo com script shell wrapper**, gerado por um `build-app.sh` versionado no repositório.

Fluxo do script wrapper (no duplo-clique):

1. `container run --rm -d --name isolated-browser isolated-browser:latest` (sem `-v`; senha VNC efêmera por sessão via env — ver ADR-0001).
2. Resolver o IP do container (`container inspect`/`container ls`).
3. Poll TCP na porta noVNC (`6080`) até ficar pronta (timeout com falha amigável).
4. `open "http://<ip>:6080/vnc.html?autoconnect=true&resize=remote&password=<senha-efemera>"` no navegador padrão.
5. Ao encerrar (ou via item de menu/segundo clique), `container stop`/remoção garante efemeridade.

## Consequências

**Positivas**

- Experiência de duplo-clique atendida (RF-007/RF-008).
- `.app` regerável por script → alinhado a iteração rápida.
- Ciclo de vida do container controlado pelo launcher → reforça efemeridade.

**Negativas / Mitigações**

- Gatekeeper para app não assinado → documentar o passo de primeira execução (botão direito → Abrir) no README; assinatura/notarização fica como item futuro fora do escopo atual.
- Pré-requisito: `container` CLI instalado e no PATH → o script valida e emite mensagem clara se ausente.
- A senha efêmera não deve ser logada nem persistida (apenas em memória/tmpfs durante a sessão).
