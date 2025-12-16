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
    return T_IF;
}

"else"              {
    return T_ELSE;
}

"while"             {
    return T_WHILE;
}

"int"               {
    return T_INT;
}

"void"              {
    return T_VOID;
}

"return"            {
    return T_RETURN;
}

{ID}                {
    yylval.id = strdup(yytext);
    return T_ID;
}

{NUM}               {
    yylval.ival = atoi(yytext);
    return T_NUM;
}

"+"                 {
    return T_MAIS;
}

"-"                 {
    return T_MENOS;
}



"/*"                {
    inicio_comentario = linha_atual;
    BEGIN(COMENTARIO);
}

<COMENTARIO>"*/"    {
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
    fprintf(stderr, "ERRO LEXICO: \"%s\" - LINHA: %d\n", yytext, linha_atual);
    exit(1);
}


"*"                 {
    return T_MULT;
}

"/"                 {
    return T_DIV;
}

">="                {
    return T_MAIORIGUAL;
}

"<="                {
    return T_MENORIGUAL;
}

"=="                {
    return T_IGUAL;
}

"!="                {
    return T_DIFERENTE;
}

">"                 {
    return T_MAIOR;
}

"<"                 {
    return T_MENOR;
}

"="                 {
    return T_ATRIBUICAO;
}

";"                 {
    return T_PONTOEVIRGULA;
}

","                 {
    return T_VIRGULA;
}

"("                 {
    return T_APAR;
}

")"                 {
    return T_FPAR;
}

"["                 {
    return T_ACOLCHETE;
}

"]"                 {
    return T_FCOLCHETE;
}

"{"                 {
    return T_ACHAVE;
}

"}"                 {
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