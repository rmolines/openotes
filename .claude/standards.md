# Standards — openotes

## Stack
- Runtime: Bun
- Language: TypeScript
- Framework: openserver (MCP server framework)
- Audio: sistema de captura de áudio local
- Transcrição: API de speech-to-text (ex: Whisper, Deepgram)

## Conventions
- Code em inglês, docs em português
- Módulos pequenos, single responsibility
- Dados armazenados localmente (filesystem via openserver)
- MCP-first: toda funcionalidade exposta como MCP tool

## Quality
- Testes com bun test
- Sem dependências desnecessárias
- Erros claros e acionáveis

## Architecture
- openserver define schemas → CRUD automático
- Pipeline: captura áudio → transcrição → armazenamento → MCP tools
- Sem cloud obrigatório — tudo local por padrão
