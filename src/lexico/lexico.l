%option noyywrap

%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>

    #define YY_DECL int yylex()

    // #include "compilador.tab.h"

    int linha_atual = 1;
    int inicio_comentario = 0;
%}

%x COMENTARIO

DIGITO [0-9]
LETRA [a-zA-Z]
ID {LETRA}+
NUM {DIGITO}+

%%

[ \t\r]+            {}

"if"                {
    printf("<IF> na linha %d\n", linha_atual);
    //return T_IF;
}

"else"              {
    printf("<ELSE> na linha %d\n", linha_atual);
    //return T_ELSE;
}

"while"             {
    printf("<WHILE> na linha %d\n", linha_atual);
    //return T_WHILE;
}

"int"               {
    printf("<INT> na linha %d\n", linha_atual);
    //return T_INT_TYPE;
}

"void"              {
    printf("<VOID> na linha %d\n", linha_atual);
    //return T_VOID_TYPE;
}

"return"            {
    printf("<RETURN> na linha %d\n", linha_atual);
    //return T_RETURN;
}

{ID}                {
    /* ... */
    printf("ID <%s> na linha %d\n", yytext, linha_atual);
}

{NUM}               {
    /* ... */
    printf("NUM <%s> na linha %d\n", yytext, linha_atual);
}

"+"                 {
    printf("<'+'> na linha %d\n", linha_atual);
    //return T_MAIS;
}

"-"                 {
    printf("<'-'> na linha %d\n", linha_atual);
    //return T_MENOS;
}



"/*"                {
    printf("Comentario iniciado na linha %d\n", linha_atual);
    inicio_comentario = linha_atual;
    BEGIN(COMENTARIO);
}

<COMENTARIO>"*/"    {
    printf("Comentario terminado na linha %d\n", linha_atual);
    BEGIN(INITIAL);
}

<COMENTARIO>\n      {
    linha_atual++;
    printf("### NOVA LINHA (%d) ###\n", linha_atual);
}

<COMENTARIO>.       {}

<COMENTARIO><<EOF>>      {
    fprintf(stderr, "ERRO LEXICO: Comentario nao fechado - ABERTO NA LINHA: %d\n", inicio_comentario);
    exit(1);
}

"*/"                {
    fprintf(stderr, "ERRO LEXICO: \"%s\" - LINHA: %d\n", yytext, linha_atual);
    exit(1);
}


"*"                 {
    printf("<'*'> na linha %d\n", linha_atual);
    //return T_MULT;
}

"/"                 {
    printf("<'/'> na linha %d\n", linha_atual);
    //return T_DIV;
}

">="                {
    printf("<'>='> na linha %d\n", linha_atual);
    //return T_MAIORIGUAL;
}

"<="                {
    printf("<'<='> na linha %d\n", linha_atual);
    //return T_MENORIGUAL;
}

"=="                {
    printf("<'=='> na linha %d\n", linha_atual);
    //return T_IGUAL;
}

"!="                {
    printf("<'!='> na linha %d\n", linha_atual);
    //return T_DIFERENTE;
}

">"                 {
    printf("<'>'> na linha %d\n", linha_atual);
    //return T_MAIOR;
}

"<"                 {
    printf("<'<'> na linha %d\n", linha_atual);
    //return T_MENOR;
}

"="                 {
    printf("<'='> na linha %d\n", linha_atual);
    //return T_ATRIB;
}

";"                 {
    printf("<';'> na linha %d\n", linha_atual);
    //return T_PONTOVIRGULA;
}

","                 {
    printf("<','> na linha %d\n", linha_atual);
    //return T_VIRGULA;
}

"("                 {
    printf("<'('> na linha %d\n", linha_atual);
    //return T_APAR;
}

")"                 {
    printf("<')'> na linha %d\n", linha_atual);
    //return T_FPAR;
}

"["                 {
    printf("<'['> na linha %d\n", linha_atual);
    //return T_ACOLCHETE;
}

"]"                 {
    printf("<']'> na linha %d\n", linha_atual);
    //return T_FCOLCHETE;
}

"{"                 {
    printf("<'{'> na linha %d\n", linha_atual);
    //return T_ACHAVE;
}

"}"                 {
    printf("<'}'> na linha %d\n", linha_atual);
    //return T_FCHAVE;
}

"\n"                {
    linha_atual++;
    printf("### NOVA LINHA (%d) ###\n", linha_atual);
}

.                   {
    fprintf(stderr, "ERRO LEXICO: \"%s\" - LINHA: %d\n", yytext, linha_atual);
    exit(1);
}

%%

int main(int argc, char **argv) {
    if (argc > 1) {
        FILE *file = fopen(argv[1], "r");
        if (!file) {
            perror("Erro ao abrir o arquivo");
            return EXIT_FAILURE;
        }
        yyin = file;
    }

    yylex();

    if (argc > 1) {
        fclose(yyin);
    }

    return 0;
}