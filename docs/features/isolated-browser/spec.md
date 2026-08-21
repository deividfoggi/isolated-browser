# Especificação de Feature: Isolated Browser

| Campo | Valor |
|-------|-------|
| Short name | isolated-browser |
| Tipo | Feature |
| Status | Draft |
| Board | Local (tasks.md) — sem board externo |
| Data | 2026-08-21 |

## Resumo Executivo

- **Objetivo**: Permitir que o usuário navegue na internet a partir de um browser gráfico executando dentro de um container isolado (Apple Container), sem acesso ao sistema de arquivos do host.
- **Usuário primário**: Desenvolvedor/usuário macOS que precisa navegar em sites potencialmente não confiáveis com isolamento do sistema operacional hospedeiro.
- **Valor entregue**: Navegação descartável e sandboxed, iniciada com um duplo-clique, protegendo os arquivos do host contra qualquer atividade do browser.
- **Escopo**: Incluído — browser Chromium/Chrome gráfico, isolamento de filesystem, sessões efêmeras, áudio do browser (reprodução de vídeo com som), launcher `.app` no macOS. Excluído — persistência de dados, isolamento de rede/clipboard, compartilhamento de arquivos com o host.
- **Critério de sucesso primário**: Iniciar o browser isolado através de um ícone (`.app`) na pasta Aplicativos do macOS com um duplo-clique.

## Cenários de Usuário e Testes

### Cenário Principal (Happy Path)

**Como** usuário macOS,
**Quero** iniciar um browser isolado com um duplo-clique em um ícone nos Aplicativos,
**Para** navegar na internet sem expor o filesystem do meu host.

- **Dado** que o `.app` launcher está instalado na pasta Aplicativos,
- **Quando** o usuário dá duplo-clique no ícone,
- **Então** um container isolado é iniciado e uma janela gráfica do browser Chromium/Chrome torna-se acessível ao usuário.

### Cenário de Sessão Efêmera

- **Dado** que o usuário navegou, fez login em sites e baixou conteúdo em uma sessão,
- **Quando** o usuário encerra a sessão e inicia uma nova,
- **Então** a nova sessão começa completamente limpa, sem histórico, cookies, cache ou arquivos da sessão anterior.

### Cenário de Isolamento de Filesystem

- **Dado** que o browser isolado está em execução,
- **Quando** ocorre qualquer tentativa (pelo usuário ou por conteúdo malicioso) de ler ou gravar em arquivos do host,
- **Então** nenhum arquivo do sistema de arquivos do host é acessível a partir do container.

### Cenário de Egresso de Rede

- **Dado** que o browser isolado está em execução,
- **Quando** o usuário acessa um site na internet,
- **Então** a requisição sai pela rede do container (NAT padrão) e o conteúdo é exibido normalmente.

## Requisitos Funcionais

- **RF-001**: O sistema DEVE executar um browser Chromium/Chrome dentro de um container Apple Container (CLI `container` do macOS).
- **RF-002**: O sistema DEVE fornecer acesso gráfico/interativo ao browser em execução no container via cliente web KasmVNC (ver ADR-0004).
- **RF-003**: O sistema DEVE impedir qualquer acesso do container ao sistema de arquivos do host (isolamento total de filesystem).
- **RF-004**: O sistema NÃO DEVE compartilhar volumes, diretórios ou arquivos entre host e container.
- **RF-005**: Cada sessão DEVE ser totalmente efêmera; nenhum estado (histórico, cookies, cache, downloads, perfil) DEVE persistir entre sessões.
- **RF-006**: O sistema DEVE permitir egresso de rede direto do container via rede padrão do container (NAT).
- **RF-007**: O sistema DEVE oferecer um launcher `.app` instalável na pasta Aplicativos do macOS que inicia o browser isolado por duplo-clique.
- **RF-008**: O launcher `.app` DEVE inicializar o container e abrir automaticamente a interface gráfica do browser para o usuário, sem etapas manuais adicionais em terminal.
- **RF-009**: O sistema DEVE transmitir o áudio do browser (ex.: som de um vídeo) do container para o navegador do host, permitindo reprodução audível pelo usuário. [ADR-0004]
- **RF-010**: O sistema DEVE reproduzir vídeo com áudio de forma utilizável e sincronizada, oferecendo experiência equivalente à de um browser executando diretamente no sistema operacional. [ADR-0004]

## Requisitos Não Funcionais

- **RNF-001** (Desenvolvimento rápido): O formato do projeto DEVE priorizar iteração rápida de desenvolvimento (build/execução simples do container).
- **RNF-002** (Isolamento): O container NÃO DEVE ter nenhum ponto de montagem do filesystem do host.

## Critérios de Sucesso

- **CS-001**: O usuário consegue iniciar o browser isolado com um único duplo-clique no ícone `.app` nos Aplicativos.
- **CS-002**: 100% das sessões iniciam sem qualquer dado da sessão anterior (estado zero).
- **CS-003**: Nenhum arquivo do host é legível ou gravável a partir do container em uma verificação de isolamento.
- **CS-004**: O usuário consegue carregar e navegar em páginas da internet dentro do browser isolado.
- **CS-005**: O usuário consegue reproduzir um vídeo público com áudio audível e sincronizado dentro do browser isolado.

## Critérios de Conformidade

| ID | Cenário | Entrada / Condição | Saída Esperada |
|----|---------|--------------------|-----------------|
| CC-001 | Happy path (launch) | Duplo-clique no `.app` | Container inicia e janela gráfica do browser fica acessível |
| CC-002 | Sessão efêmera | Encerrar sessão com cookies/downloads e reiniciar | Nova sessão sem histórico, cookies, cache ou arquivos |
| CC-003 | Isolamento (negativo) | Tentativa de acesso a caminho do host (ex.: `/Users/...`) a partir do container | Acesso negado / caminho inexistente — nenhum arquivo do host visível |
| CC-004 | Egresso de rede | Acessar um site público | Página carrega via NAT do container |
| CC-005 | Playback de áudio | Abrir um vídeo público (ex.: YouTube) e dar play | Vídeo reproduz com áudio audível e sincronizado no host |

## Invariantes

- **INV-001**: Em nenhum momento e por nenhum caminho de execução o container DEVE ter acesso ao filesystem do host.
- **INV-002**: Em nenhum momento dados de uma sessão DEVEM sobreviver ao término dessa sessão.

## Entidades-Chave

- **Sessão de Browser Isolado**: Instância efêmera do browser em execução no container; ciclo de vida limitado ao tempo de uso; sem estado persistido.
- **Container Isolado (Apple Container)**: VM/container Linux leve que hospeda o browser; sem montagens do host; rede NAT padrão.
- **Launcher `.app`**: Aplicativo macOS na pasta Aplicativos que orquestra a inicialização do container e a abertura da interface gráfica.

## Pressupostos (Assumptions)

- **A-001**: O mecanismo de exibição gráfica é KasmVNC (acesso web com áudio integrado), decidido na ADR-0004 (supersede ADR-0001), pois o Apple Container não expõe GUI nativamente ao host.
- **A-002**: Browser alvo é Chromium (variante open-source assumida como padrão; Chrome aceitável se disponível na imagem).
- **A-003**: Rede padrão do container (NAT) é suficiente; sem proxy, VPN ou filtragem de egresso.
- **A-004**: Isolamento de clipboard e de rede não é requisito; apenas isolamento de filesystem é obrigatório. O **áudio do browser É um requisito de capacidade** (RF-009/RF-010): o som deve ser transmitido do container para o host e reproduzido de forma audível.

## Decisões Técnicas Implícitas (candidatas a ADR)

| Decisão | Status | Impacto |
|---------|--------|---------|
| Mecanismo de acesso gráfico + áudio | Resolvido — ADR-0001 (Superseded) → ADR-0004 (KasmVNC + PulseAudio) | Habilita UI gráfica e áudio (RF-002, RF-009, RF-010) |
| Imagem base do container e empacotamento do Chromium | Não definido | Afeta build e formato de dev — requer ADR |
| Estratégia do launcher `.app` (script wrapper, abertura automática do cliente gráfico) | Não definido | Afeta experiência de duplo-clique — requer ADR |

## Fora de Escopo

- Persistência de qualquer dado entre sessões.
- Isolamento de rede ou de clipboard.
- Compartilhamento de arquivos entre host e container.
- Modernização/otimização de performance além do necessário para navegação funcional.
