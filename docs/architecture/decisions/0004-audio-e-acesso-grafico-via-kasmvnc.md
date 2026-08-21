# ADR-0004: Áudio e acesso gráfico via KasmVNC

| Campo | Valor |
|-------|-------|
| Status | Accepted |
| Data | 2026-08-21 |
| Decisores | Equipe isolated-browser |
| Feature | isolated-browser |
| Supersedes | [ADR-0001](0001-mecanismo-de-acesso-grafico.md) |

## Contexto

Durante a validação do tracer bullet (Fase 0) confirmou-se visualmente que o Chromium renderiza e reproduz **vídeo** via noVNC — porém **sem áudio**. Surgiu então um requisito obrigatório que não existia na spec original: o usuário DEVE conseguir reproduzir vídeo **com som**, com experiência equivalente à do "browser principal do sistema operacional" (RF-009/RF-010).

O stack decidido na [ADR-0001](0001-mecanismo-de-acesso-grafico.md) — Xvfb + x11vnc + websockify + noVNC — **não transporta áudio**. O protocolo VNC/RFB carrega apenas quadros de display; não há canal de áudio. Satisfazer o áudio exige ou um segundo stack de transporte de áudio fora de banda, ou um mecanismo de acesso gráfico com áudio integrado.

Restrições que permanecem (herdadas da spec):

- Sessão totalmente efêmera (RF-005, INV-002): nenhum estado de display/áudio persiste.
- Sem montagens do host (RF-004, RNF-002, INV-001): o transporte de áudio não pode depender de socket/arquivo compartilhado com o host.
- Duplo-clique abre a UI automaticamente (RF-008).
- Iteração rápida / stack simples (RNF-001).

## Decision Drivers

- **Áudio audível no host** (RF-009/RF-010), sincronizado com o vídeo.
- **Stack único e simples**: evitar um segundo pipeline de áudio fora de banda (mais peças, mais atrito de sincronização A/V).
- **UX de duplo-clique** preservada: cliente é o próprio navegador do host.
- **Isolamento total** preservado: nenhuma montagem do host para áudio.
- **Iteração rápida de desenvolvimento** (RNF-001).

## Opções Consideradas

### Opção A — KasmVNC + PulseAudio (escolhida)

KasmVNC é um fork do TigerVNC/noVNC que integra um servidor Xvnc (X server + VNC + servidor web) com **streaming de áudio nativo para o navegador** via WebSocket. O Chromium roda no display do KasmVNC; o áudio do Chromium é roteado por um **PulseAudio** interno (sink virtual em tmpfs), que o KasmVNC captura e transmite ao cliente web junto com o vídeo.

- **Prós**: áudio integrado ao mesmo stack (sem segundo pipeline); cliente é o navegador do host (mantém o duplo-clique); web-based e self-contained no container; substitui de uma vez `Xvfb + x11vnc + websockify + noVNC` por um único componente; arm64.
- **Contras**: qualidade de A/V para vídeo pesado é inferior a WebRTC; serve por HTTPS com certificado autoassinado por padrão (aviso de certificado na primeira conexão).

### Opção B — Selkies-GStreamer (WebRTC)

Pipeline WebRTC com GStreamer transmitindo vídeo H.264/VP8 + áudio Opus de baixa latência.

- **Prós**: melhor qualidade A/V "native-like" para vídeo pesado; latência menor.
- **Contras**: stack significativamente mais complexo (pipelines GStreamer, sinalização, considerações de STUN/TURN, imagem maior); maior atrito de desenvolvimento → contraria RNF-001. **Mantida como caminho de escalonamento** (ver abaixo).

### Opção C — noVNC + ponte de áudio separada

Manter noVNC (ADR-0001) e adicionar um transporte de áudio fora de banda (ex.: PulseAudio → ffmpeg/Icecast ou um WebSocket de áudio dedicado + player no cliente).

- **Prós**: preserva o stack noVNC já validado no tracer.
- **Contras**: dois stacks independentes; sincronização A/V no cliente vira responsabilidade do projeto; mais peças móveis e mais superfície que o KasmVNC, que já integra áudio nativamente.

## Decisão

Adotar a **Opção A — KasmVNC + PulseAudio**. O KasmVNC **substitui** o stack `Xvfb + x11vnc + websockify + noVNC` da ADR-0001. O áudio do Chromium é roteado por um PulseAudio interno e transmitido ao navegador do host pelo próprio KasmVNC.

- **Porta padrão**: `8444` (HTTPS), padrão nativo do KasmVNC. O host acessa `https://<container-ip>:8444` (IP host-local resolvido pelo launcher — ADR-0003).
- **Caminho de áudio**: Chromium → PulseAudio (sink virtual em tmpfs) → KasmVNC → navegador do host.
- **Caminho de display**: KasmVNC (Xvnc) fornece o display; Chromium `--no-sandbox` renderiza nele; window manager mínimo mantido (ADR-0002).

A [ADR-0002](0002-imagem-base-e-empacotamento-chromium.md) permanece válida (Debian slim + Chromium via apt), mas o **conjunto de pacotes muda**: `kasmvnc` + `pulseaudio` no lugar de `x11vnc` + `websockify` + `novnc`. A [ADR-0003](0003-estrategia-launcher-app.md) permanece válida; apenas **URL/porta** mudam (de `http://IP:6080/vnc.html` para `https://IP:8444`).

## Consequências

**Positivas**

- Áudio audível no host com um único stack integrado (RF-009/RF-010).
- UX de duplo-clique preservada (cliente é o navegador do host).
- Uma peça a menos que a Opção C; substitui quatro componentes por um.
- Mantém isolamento total: áudio via socket interno em tmpfs, sem montagem do host.

**Negativas / Mitigações**

- **Qualidade A/V para vídeo pesado inferior a WebRTC** → aceitável para o caso de uso fast-dev; se insuficiente, escalar para Selkies-GStreamer (ver caminho de escalonamento).
- **HTTPS com certificado autoassinado** (gerado por sessão em tmpfs) → aviso de certificado na primeira conexão do navegador. Mitigação: documentar o passo de aceitação única no README (análogo ao passo de Gatekeeper do `.app`); acesso é host-local na sub-rede privada do Apple Container.
- Imagem levemente maior por conta do PulseAudio + KasmVNC → aceitável frente ao ganho de áudio nativo.

## Notas de Segurança

- **Senha efêmera por sessão permanece obrigatória**: o KasmVNC usa autenticação básica (usuário/senha); a credencial é gerada por sessão (env/tmpfs), nunca fixa, logada ou persistida — mesma política da ADR-0001.
- **Sem novas montagens do host**: o PulseAudio usa socket/estado interno em **tmpfs**; nenhum dispositivo de áudio do host é montado ou compartilhado → INV-001 preservado.
- **Porta 8444 host-local**: não publicar via `--publish` em `0.0.0.0`/LAN; acesso apenas pelo IP host-local do container.
- **TLS por sessão**: certificado autoassinado gerado em tmpfs, descartado com o container.

## Caminho de Escalonamento (se KasmVNC for insuficiente)

Se a qualidade de A/V do KasmVNC (fluidez de vídeo, sincronização de áudio, latência) se mostrar insuficiente para o uso "como o browser principal do SO", **escalar para Selkies-GStreamer (WebRTC)**: vídeo H.264/VP8 + áudio Opus de baixa latência. Isso implicaria uma nova ADR (superseding esta), imagem com GStreamer + sinalização WebRTC e possivelmente TURN/STUN host-local. Documentado aqui para tornar a rota conhecida; **não** adotado agora por custo/complexidade (RNF-001).
