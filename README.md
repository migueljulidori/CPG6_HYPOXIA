<p align="center">
  <img src="docs/readme-banner.png" alt="HYPOXIA: um morcego segue uma trajetória matemática até o alvo enquanto o oxigênio acaba" width="100%">
</p>

<h1 align="center">HYPOXIA — Ctrl+Alt+Math</h1>

<p align="center">
  Um jogo de puzzle e exploração criado em 36 horas para o Coding, Pizza & Glory (CDG) 2026.
</p>

<p align="center">
  <img alt="Godot 4.6" src="https://img.shields.io/badge/Godot-4.6-478CBF?logo=godotengine&amp;logoColor=white">
  <img alt="GDScript" src="https://img.shields.io/badge/GDScript-Game-604A91">
  <img alt="Plataforma Windows" src="https://img.shields.io/badge/Build-Windows-1266B0?logo=windows&amp;logoColor=white">
  <img alt="Game Jam 2026" src="https://img.shields.io/badge/CDG-2026-41B9BC">
</p>

Um erro de cálculo mudou a rota do voo. Agora um morcego está preso em um porão tóxico, com pouca luz e oxigênio limitado. Para escapar, ele precisa atravessar um hub abandonado e resolver três salas de funções matemáticas.

## O jogo

- **Explore no escuro:** use o sonar para revelar o ambiente e encontrar as passagens.
- **Sobreviva ao hub:** desvie de inimigos e teias enquanto administra vidas e oxigênio.
- **Trace o caminho:** nas salas, examine funções afins, quadráticas e exponenciais, visualize as trajetórias e alcance o alvo.
- **Encontre a saída:** conclua as três salas, em qualquer ordem, para liberar a fuga.

## Jogar

Para jogar sem instalar o Godot, baixe a versão de Windows na seção **Releases** deste repositório quando ela estiver disponível. Extraia o ZIP inteiro e execute `HYPOXIA.exe`, mantendo o arquivo `.pck` na mesma pasta.

O botão **Code → Download ZIP** baixa o **projeto-fonte**. Para jogar a partir dele, siga as instruções em [Abrir o projeto](#abrir-o-projeto).

### Controles

| Tecla | Ação |
| --- | --- |
| `WASD` ou setas | Movimentar |
| `Ctrl` | Emitir um pulso de sonar |
| `Alt` | Dash, ataque e fuga das teias; consome oxigênio |
| `E` | Interagir com portas, terminais e saídas |
| `1` a `4` ou clique | Selecionar e visualizar uma trajetória nas salas |
| `Enter` | Confirmar a trajetória selecionada; avançar telas e cutscenes |
| `Esc` | Navegar pelos menus e cutscenes |

Em cada etapa das salas, o objetivo e o alvo aparecem na tela. Uma escolha incorreta consome 5 unidades de oxigênio e permite tentar novamente **na mesma etapa**, com as mesmas alternativas.

## Abrir o projeto

1. Instale o [Godot 4.6](https://godotengine.org/download) — o projeto foi validado com a versão **4.6.3**.
2. No gerenciador de projetos do Godot, escolha **Importar** e selecione `project.godot` nesta pasta.
3. Abra o projeto e pressione **F5** para jogar desde a abertura.

O projeto usa **GDScript**, tem resolução base de **1280 × 720** e não exige plugins externos.

### Gerar uma build

O arquivo `export_presets.cfg` já contém os presets **Windows Desktop** e **Linux**. Instale os modelos de exportação correspondentes à sua versão do Godot em **Editor → Gerenciar Modelos de Exportação**. Depois, abra **Projeto → Exportar**, selecione a plataforma e clique em **Exportar Projeto**. Os caminhos configurados são `build/windows/HYPOXIA.exe` e `build/linux/HYPOXIA.x86_64`.

Para distribuir a versão Windows, compacte todo o conteúdo de `build/windows`; o executável e o `.pck` precisam ficar juntos. A pasta `build/` é ignorada pelo controle de versão para que as builds sejam publicadas separadamente do projeto-fonte.

Inclua também `assets/fonts/OFL.txt` no ZIP da build como `OFL-PressStart2P.txt`. O script `scripts/build_release.sh` já copia essa licença para as builds Windows e Linux.

## Organização

| Caminho | Conteúdo |
| --- | --- |
| `assets/` | Artes, animações, fonte e áudio usados pelo jogo |
| `scenes/` | Cenas do Godot: abertura, hub, salas e telas finais |
| `scripts/` | Jogabilidade, puzzles, interface e gerenciamento da partida |
| `shaders/` | Efeitos visuais |
| `docs/readme-banner.png` | Capa do repositório composta com artes do próprio jogo |
| `project.godot` | Configurações e cena inicial do projeto |
| `export_presets.cfg` | Configurações de exportação para Windows e Linux |

## Equipe

| Pessoa | Contribuição |
| --- | --- |
| **Miguel Julidori** | Programação em Godot e level design |
| **Yan Gabardo** | Pixel art, interface e animações |
| **Iury Gonçalves** | Áudio (SFX/BGM) e game design |

Desenvolvido em **36 horas** para o **Coding, Pizza & Glory (CDG) 2026**.

## Direitos de uso

**Todos os direitos reservados.** A publicação do projeto permite estudar sua implementação, mas não concede autorização para reutilizar, modificar ou redistribuir seu código e seus recursos fora das funcionalidades permitidas pela plataforma. Consulte o arquivo [LICENSE](LICENSE) e solicite permissão aos respectivos titulares antes de qualquer reutilização. Recursos de terceiros, se presentes, continuam sujeitos aos direitos de seus autores.
