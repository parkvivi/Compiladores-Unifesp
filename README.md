# Compiladores-Unifesp
Trabalho desenvolvido na disciplina Compiladores em 2025-2.

# Compilador (Até agora...)

Compilador desenvolvido para a linguagem `C-`, conforme especificado por Louden (2004).

## Requisitos

- **Flex** (Gerador de Analisador Léxico)
- **GCC** (GNU Compiler Collection)
- **Make** (Ferramenta de Automação)

### Instalando `make` (Windows)

- Utilizando [Chocolatey](https://chocolatey.org/):

  ```powershell
  choco install winflexbison3 mingw make
  ```
- Ou utilize [MSYS2](https://www.msys2.org/) ou [MinGW-w64](https://www.mingw-w64.org/)

## Analisador Léxico

* Compilar
```powershell
make
```

*  Executar no Windows PowerShell:
```powershell
./build/scanner entrada/codigo.txt
```
> Observação: `codigo.txt` pode ser substituido por qualquer código teste

*  Limpar arquivos gerados
```powershell
make clean
```

## Referências

> LOUDEN, Kenneth C. Compiladores: princípios e práticas. São Paulo: Cengage Learning, 2004.