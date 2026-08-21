# ADR-0005: Acesso gráfico + áudio via WebRTC (Neko)

| Campo | Valor |
|-------|-------|
| Status | Accepted |
| Data | 2026-08-21 |
| Decisores | Equipe isolated-browser |
| Feature | isolated-browser |
| Supersedes | [ADR-0004](0004-audio-e-acesso-grafico-via-kasmvnc.md) |

## Contexto

A [ADR-0004](0004-audio-e-acesso-grafico-via-kasmvnc.md) adotou KasmVNC + PulseAudio para atender ao requisito obrigatório de áudio (RF-009/RF-010). Durante a implementação (US-2/US-3) o KasmVNC subiu com vídeo, janela e acesso sem login funcionando, **mas descobriu-se que o pacote `.deb` do KasmVNC standalone não inclui o servidor de áudio**: no ecossistema Kasm, o áudio é um serviço separado (`kasm_audio_out`, parte do Kasm Workspaces) que captura do PulseAudio, codifica em Opus e o transmite por um websocket próprio. O `Xvnc` do KasmVNC não tem áudio compilado (sem símbolos de audio/opus/pcm) e `/usr/share/kasmvnc/bin` é vazio; o cliente web tem apenas o gancho `enable_audio`, sem provedor de áudio no lado servidor.

Consequência: obter áudio no KasmVNC exigiria **reimplementar o serviço de áudio do Kasm** (pulseaudio → opus → websocket + fiação no cliente), esforço alto e frágil. Isso aciona o **caminho de escalonamento já previsto na ADR-0004**: migrar para uma solução WebRTC com áudio+vídeo nativos.

## Decision Drivers

- **Áudio+vídeo nativos e sincronizados** (RF-009/RF-010), experiência "como o browser do SO".
- **Menor esforço de integração** / iteração rápida (RNF-001): preferir solução pronta a montar pipeline do zero.
- **Isolamento preservado**: container efêmero, sem montagens do host, egresso NAT.
- **UX de duplo-clique** preservada (cliente é o navegador do host).

## Opções Consideradas

### Opção A — Neko (`m1k1o/neko`) (escolhida)

Projeto open-source de "browser isolado em container" que já entrega **vídeo + áudio por WebRTC** com cliente web embutido, Chromium incluso e imagens multi-arch (amd64/arm64). Toda a stack (Xorg, PulseAudio, pipeline GStreamer WebRTC, sinalização, cliente) vem pronta e configurável por variáveis de ambiente.

- **Prós**: turnkey para o caso de uso exato; A/V nativo com áudio; arm64; cliente web (mantém duplo-clique); muito menos código próprio.
- **Contras**: imagem maior; WebRTC exige portas UDP (mux) alcançáveis do host; autenticação própria a configurar (ou relaxar para host-local).

### Opção B — Selkies-GStreamer puro

Montar diretamente o pipeline GStreamer (captura X → H.264/VP8 + Opus), servidor de sinalização, cliente web e, possivelmente, TURN.

- **Prós**: controle total e baixo nível.
- **Contras**: esforço alto, muitas peças, frágil de estabilizar; contraria RNF-001. Mantido como alternativa de baixo nível.

### Opção C — Construir serviço de áudio companheiro para o KasmVNC

Manter KasmVNC (vídeo) e implementar o serviço de áudio ausente (pulseaudio→opus→websocket) + fiação no cliente.

- **Prós**: reaproveita o vídeo do KasmVNC já validado.
- **Contras**: reimplementar um componente do Kasm Workspaces; integração de cliente incerta; risco de dessincronização A/V.

## Decisão

Adotar a **Opção A — Neko (`m1k1o/neko`)** como mecanismo de acesso gráfico + áudio via WebRTC. O container passa a basear-se na imagem Chromium do Neko (arm64), configurada por variáveis de ambiente.

- **Rede WebRTC**: na sub-rede plana do Apple Container (host e container em `192.168.64.0/24`, alcançáveis diretamente), usar **ICE-lite** + **UDP mux** em porta fixa, com o Neko anunciando o IP do container como host candidate. Sem necessidade de TURN.
- **HTTP**: cliente web do Neko em porta fixa (padrão `8080`), acessado por `http(s)://<container-ip>:<porta>`.
- **Isolamento**: `container run --rm` sem `-v` (INV-001), estado efêmero (INV-002), egresso NAT (RF-006).
- **Auth**: acesso host-local, usuário único e efêmero → autenticação relaxada/simplificada (mesma política de trade-off das ADRs anteriores).

As ADRs [0002](0002-imagem-base-e-empacotamento-chromium.md) (imagem base própria + Chromium via apt) e a stack noVNC/KasmVNC deixam de valer para o runtime gráfico: o Neko traz sua própria base e Chromium. A [ADR-0003](0003-estrategia-launcher-app.md) (launcher `.app`) permanece válida; mudam **URL/porta** e o fato de não haver senha VNC a injetar.

## Consequências

**Positivas**

- Áudio+vídeo nativos e sincronizados, com esforço de integração baixo (RF-009/RF-010, RNF-001).
- Cliente web mantém a UX de duplo-clique.
- Isolamento e efemeridade preservados.

**Negativas / Mitigações**

- **Portas UDP do WebRTC** precisam ser alcançáveis do host → na sub-rede do Apple Container isso é direto; fixar uma porta de UDP mux e confirmar conectividade.
- **Imagem maior** (traz toda a stack) → aceitável frente ao ganho.
- **Dependência de imagem de terceiro** (`m1k1o/neko`) → fixar tag/digest; auditar variáveis; container efêmero limita a superfície.
- **Auth relaxada** para host-local → se o container for exposto além do host, reativar autenticação forte.

## Notas de Segurança

- Acesso host-local (IP privado do Apple Container), sem `--publish` para LAN.
- Sessão efêmera (`--rm`, sem `-v`); nenhum estado persiste (INV-002); sem montagens do host (INV-001).
- Fixar a versão/imagem do Neko; revisar as variáveis de ambiente sensíveis.
- Áudio via PulseAudio interno do Neko (sem dispositivo de áudio do host montado).
