# ADR-0001: Mecanismo de acesso gráfico ao browser no container

| Campo | Valor |
|-------|-------|
| Status | Superseded por ADR-0004 |
| Data | 2026-08-21 |
| Decisores | Equipe isolated-browser |
| Feature | isolated-browser |

> **Nota (2026-08-21):** Esta decisão foi **substituída pela [ADR-0004](0004-audio-e-acesso-grafico-via-kasmvnc.md)**. Durante a implementação surgiu o requisito obrigatório de **áudio** (reprodução de vídeo com som), que o stack noVNC (Xvfb + x11vnc + websockify + noVNC) **não transporta**. A ADR-0004 adota **KasmVNC** (com áudio integrado) + **PulseAudio**. O conteúdo abaixo é mantido como registro histórico.

## Contexto

O Apple Container executa VMs Linux leves no macOS e **não expõe GUI nativamente ao host** (não há passthrough de X11/Wayland/Metal). Cada container recebe um IP dedicado na sub-rede do Apple Container, acessível a partir do host. Para satisfazer o RF-002 (acesso gráfico ao Chromium) precisamos de um mecanismo de display remoto que rode **dentro** do container e seja consumido pelo host sem etapas manuais de terminal (RF-008).

Restrições:

- Sessão totalmente efêmera (RF-005, INV-002): nenhum estado de display deve persistir.
- Sem montagens do host (RF-004, RNF-002): o cliente gráfico não pode depender de socket/arquivo compartilhado com o host.
- Duplo-clique deve abrir a UI automaticamente (RF-008).

## Decision Drivers

- **UX de duplo-clique**: abrir a interface sem configuração manual do usuário.
- **Zero dependência de host**: não exigir instalação/configuração adicional no macOS.
- **Simplicidade / iteração rápida** (RNF-001).
- **Superfície de exposição mínima**: a porta de display deve ficar restrita ao host.

## Opções Consideradas

### Opção A — noVNC (Xvfb + servidor VNC + websockify + cliente web noVNC)

O container roda um framebuffer virtual (Xvfb), um servidor VNC e o websockify servindo o cliente web noVNC em uma porta HTTP. O host abre a URL no navegador padrão do macOS.

- **Prós**: cliente é o próprio navegador do host (sem app extra); URL abrível via `open http://<ip>:6080/vnc.html?autoconnect=true`; autoconnect e resize nativos; totalmente self-contained no container.
- **Contras**: uma camada a mais (websockify); latência levemente maior que VNC puro.

### Opção B — VNC puro (Xvfb + x11vnc) + macOS Screen Sharing

O container expõe VNC (5900); o host usa o cliente nativo `Screen Sharing` via `open vnc://<ip>:5900`.

- **Prós**: menos uma camada; cliente nativo.
- **Contras**: depende do estado/config do Screen Sharing do macOS; experiência de handshake de senha menos previsível; menos controle sobre resize/autoconnect.

### Opção C — Xpra / RDP / outros

- **Prós**: melhor performance em alguns casos.
- **Contras**: maior complexidade de imagem e de cliente no host; contraria RNF-001.

## Decisão

Adotar a **Opção A — noVNC** (Xvfb + servidor VNC + websockify + cliente web noVNC), exposto em uma porta HTTP única (padrão `6080`).

O host acessa via IP do container resolvido em runtime pelo launcher (ver ADR-0003) e abre `http://<container-ip>:6080/vnc.html?autoconnect=true&resize=remote` no navegador padrão.

## Consequências

**Positivas**

- UX de duplo-clique atendida sem instalar cliente no host.
- Stack 100% dentro do container → compatível com isolamento total de filesystem.
- Autoconnect + resize melhoram a experiência sem intervenção do usuário.

**Negativas / Mitigações**

- Camada websockify adiciona overhead → aceitável para o caso de uso.
- **Segurança**: a porta noVNC não deve ser publicada em `0.0.0.0`/LAN. Fica acessível apenas via IP do container (host-local na rede do Apple Container). Recomenda-se **senha de VNC efêmera** gerada por sessão (passada por variável de ambiente/arquivo em tmpfs, nunca em volume do host) e injetada no URL de autoconnect pelo launcher. Registrar como requisito de implementação.

## Requisitos de segurança derivados

- Não usar `--publish` para expor a porta noVNC ao host loopback/LAN sem necessidade; usar o IP do container.
- Gerar senha de VNC por sessão (efêmera, em tmpfs) — nunca fixa no código nem persistida.
