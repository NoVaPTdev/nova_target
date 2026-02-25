# nova_target

Sistema de targeting por raycast do NOVA Framework. Menu de opções ao apontar a entidades (veículos, peds, objetos, jogadores) ou zonas (box, esfera, polígono). Compatível com **ox_target** e **qb-target** via `provide`.

## Dependências

Nenhuma (core standalone). Fornece `ox_target` e `qb-target`.

## Instalação

1. Coloca a pasta `nova_target` em `resources/[nova]/`.
2. No `server.cfg`:

```cfg
ensure nova_target
```

## Configuração

Em `config.lua`: tecla (ex.: LMENU), distância máxima, compat exports (ox_target/qb-target), debug.

## Exports principais (camelCase)

- Zonas: `addBoxZone`, `addSphereZone`, `addPolyZone`, `removeZone`
- Entidades: `addEntity`, `addLocalEntity`, `addModel`
- Globais: `addGlobalPlayer`, `addGlobalVehicle`, etc.
- Utilidade: `disableTargeting`, `isActive`

PascalCase (qb-target) também disponível.

## Estrutura

- `client/` — registry, zones, raycast, resolver, main, compat
- `config.lua`
- `html/index.html` — UI do menu

## Documentação

[NOVA Framework Docs](https://github.com/NoVaPTdev) — guia Target.

## Licença

Parte do ecossistema NOVA Framework.
