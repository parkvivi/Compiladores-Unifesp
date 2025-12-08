# Compiladores-Unifesp
Trabalhos desenvolvidos na disciplina Compiladores em 2025-2.

1.  [**Lista-Flex**](/Lista-Flex/): Exercícios utilizando flex
2.  [**Compilador**](/Compilador/): Compilador desenvolvido como trabalho final para a disciplina 

# Compilador

Compilador desenvolvido para a linguagem `C-`, conforme especificado por Louden (2004).

## Analisador Léxico

> _Observação: É necessário ter `Flex` e `GCC` instalados._ 

1. Gerando o código-fonte do analisador léxico com o flex
```
flex lexico.l
```

2. Compilando o arquivo gerado
```
gcc lex.yy.c -o lexico
```

3. Executando o analisador com um arquivo de entrada (`codigo.txt`)
```
./lexico codigo.txt
```

## Referências

> LOUDEN, Kenneth C. Compiladores: princípios e práticas. São Paulo: Cengage Learning, 2004.