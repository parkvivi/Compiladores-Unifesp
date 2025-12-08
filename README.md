# Compilador `C-`

Compilador desenvolvido para a linguagem `C-`, conforme especificado por Louden (2004), como trabalho final da disciplina de Compiladores, em 2025-2.

## Requisitos

- **Flex** (Gerador de Analisador Léxico)
- **GCC** (GNU Compiler Collection)
- **Make** (Ferramenta de Automação)

## Analisador Léxico

* Compilar
```powershell
make
```

*  Executar no Windows PowerShell:
```powershell
.\build\scanner entrada\codigo.txt
```
> Observação: `codigo.txt` pode ser substituido por qualquer código teste

*  Limpar arquivos gerados
```powershell
make clean
```

## Referências

> LOUDEN, Kenneth C. Compiladores: princípios e práticas. São Paulo: Cengage Learning, 2004.