# Compilador `C-`

Compilador desenvolvido para a linguagem `C-`, conforme especificado por Louden (2004), como trabalho final da disciplina de Compiladores, em 2025-2.

## Requisitos

- **Flex** (Gerador de Analisador Léxico)
- **Bison/Yacc** (Gerador de Analisador Sintático)
- **GCC** (GNU Compiler Collection)
- **Graphviz** (Visualização da AST)
- **Make** (Ferramenta de Automação)

## Analisador Léxico

> Observação: Aqui levando em conta somente o uso do Windows

* Compilar
```powershell
make
```

*  Executar
```powershell
.\build\parser entrada\codigo.txt
```
> Observação: `codigo.txt` pode ser substituido por qualquer código teste

* Gerar arquivo .png da AST
```powershell
dot -Tpng .\build\arvore.dot -o .\build\arvore.png
```

* **[ALTERNATIVA]** Compilar + Exectar + Gerar AST
```powershell
make run
```

*  Limpar arquivos gerados
```powershell
make clean
```

## Referências

> LOUDEN, Kenneth C. Compiladores: princípios e práticas. São Paulo: Cengage Learning, 2004.