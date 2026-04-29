# Deer Isle Endgame Quest

## Loot Flow

This [flowchart](deer-isle-endgame-loot-flow.mmd) presents a tactical breakdown of the Deer Isle
Endgame loot progression. It outlines the loot items required to complete the Endgame quest,
describes their dependencies, and shows the overall progression leading up to the Endgame quest.

DayZ Survivors can use this flowchart to plan and navigate through the quest efficiently.

> _WARNING_: The diagram contains spoilers. Do not view it if you want to experience the quest
> without prior knowledge of the loot progression.

_(Open image in a new tab to view full size.)_

[![Deer Isle Endgame Loot Flow](docs/generated/deer-isle-endgame-loot-flow.svg)](docs/generated/deer-isle-endgame-loot-flow.svg)

## How to Contribute

If you have suggestions for improvements or want to contribute, feel free to create an
[issue](https://github.com/deer-isle-quest/issues) or fork this repository and submit a pull request
with your changes.

The flowchart is created using [Mermaid](https://mermaid-js.github.io/mermaid/#/) syntax. You can
edit the `.mmd` file using any text editor, then preview it using a Mermaid-compatible viewer such
as
[Mermaid Charts for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=MermaidChart.vscode-mermaid-chart).

Please avoid making large structural changes to the flowchart or repo without discussing them first,
as it may result in your PR being delayed or rejected.

### Generating Diagram Images

The PNG and SVG images associated with the Mermaid diagram are **auto-generated** when a diagram
change is pushed to a GitHub PR. You can manually generate the images by executing:

```powershell
./build.ps1 build
```

It is recommended to use the Docker-based Mermaid CLI for consistent results across different
environments. You can force the use of Docker, even if you have a local installation of Mermaid CLI
available, by adding the `-UseDocker` flag: `./build.ps1 build -UseDocker`

## Acknowledgements

The Deer Isle map was created by [John McLane](https://x.com/JohnMcLane666). Special thanks to him,
the DayZ developers, and [Holly Rex](https://www.twitch.tv/hollyrex) who explored the game world
extensively.
