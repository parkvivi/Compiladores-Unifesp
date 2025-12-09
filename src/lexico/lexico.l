%option noyywrap

%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>

    #define YY_DECL int yylex()

    #include "sintatico.tab.h"

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
    printf("Linha %d -> PALAVRA RESERVADA '%s'\n", linha_atual, yytext);
    return T_IF;
}

"else"              {
    printf("Linha %d -> PALAVRA RESERVADA '%s'\n", linha_atual, yytext);
    return T_ELSE;
}

"while"             {
    printf("Linha %d -> PALAVRA RESERVADA '%s'\n", linha_atual, yytext);
    return T_WHILE;
}

"int"               {
    printf("Linha %d -> PALAVRA RESERVADA '%s'\n", linha_atual, yytext);
    return T_INT;
}

"void"              {
    printf("Linha %d -> PALAVRA RESERVADA '%s'\n", linha_atual, yytext);
    return T_VOID;
}

"return"            {
    printf("Linha %d -> PALAVRA RESERVADA '%s'\n", linha_atual, yytext);
    return T_RETURN;
}

{ID}                {
    printf("Linha %d -> IDENTIFICADOR '%s'\n", linha_atual, yytext);
    yylval.id = strdup(yytext);
    return T_ID;
}

{NUM}               {
    printf("Linha %d -> NUMERO '%s'\n", linha_atual, yytext);
    yylval.ival = atoi(yytext);
    return T_NUM;
}

"+"                 {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_MAIS;
}

"-"                 {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_MENOS;
}



"/*"                {
    printf("Linha %d -> INICIO DE COMENTARIO\n", linha_atual);
    inicio_comentario = linha_atual;
    BEGIN(COMENTARIO);
}

<COMENTARIO>"*/"    {
    printf("Linha %d -> FIM DE COMENTARIO\n", linha_atual);
    BEGIN(INITIAL);
}

<COMENTARIO>\n      {
    linha_atual++;
}

<COMENTARIO>.       {}

<COMENTARIO><<EOF>>      {
    fprintf(stderr, "ERRO LEXICO: Comentario nao fechado - ABERTO NA LINHA: %d\n", inicio_comentario);
    exit(1);
}

"*/"                {
    fprintf(stderr, "ERRO LEXICO: \"%s\" - LINHA: %d\n", yytext, linha_atual);  // Semantico?
    exit(1);
}


"*"                 {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_MULT;
}

"/"                 {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_DIV;
}

">="                {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_MAIORIGUAL;
}

"<="                {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_MENORIGUAL;
}

"=="                {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_IGUAL;
}

"!="                {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_DIFERENTE;
}

">"                 {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_MAIOR;
}

"<"                 {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_MENOR;
}

"="                 {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_ATRIBUICAO;
}

";"                 {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_PONTOEVIRGULA;
}

","                 {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_VIRGULA;
}

"("                 {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_APAR;
}

")"                 {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_FPAR;
}

"["                 {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_ACOLCHETE;
}

"]"                 {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_FCOLCHETE;
}

"{"                 {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_ACHAVE;
}

"}"                 {
    printf("Linha %d -> SIMBOLO '%s'\n", linha_atual, yytext);
    return T_FCHAVE;
}

"\n"                {
    linha_atual++;
}

.                   {
    fprintf(stderr, "ERRO LEXICO: \"%s\" - LINHA: %d\n", yytext, linha_atual);
    exit(1);
}

%%

#ifdef LEX_STANDALONE
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
#endif