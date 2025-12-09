%{
    #include<stdio.h>
    #include<stdlib.h>

    extern int yylex();
    extern int yyparse();
    extern FILE* yyin;

    void yyerror(const char* s);

    typedef struct Variavel {
        char *nome;
        int   valor;
        struct Variavel *prox;
    } Variavel;

    typedef struct Escopo {
        Variavel *variaveis;    /* lista encadeada de variáveis deste escopo */
        struct Escopo *prox;    /* escopo imediatamente externo */
    } Escopo;

    Escopo *topo_escopo = NULL;

    void entrar_escopo() {
        Escopo *e = (Escopo*) malloc(sizeof(Escopo));
        e->variaveis = NULL;
        e->prox = topo_escopo;
        topo_escopo = e;
    }

    void sair_escopo() {
        if (topo_escopo == NULL) return;

        /* libera as variáveis deste escopo */
        Variavel *v = topo_escopo->variaveis;
        while (v) {
            Variavel *tmp = v;
            v = v->prox;
            free(tmp->nome);
            free(tmp);
        }
        Escopo *tmpE = topo_escopo;
        topo_escopo = topo_escopo->prox;
        free(tmpE);
    }
%}

%union {
    int     ival;
    char    *id;
}

/* TOKENS */
%token T_IF             // KW 'if'
%token T_ELSE           // KW 'else'
%token T_WHILE          // KW 'while'
%token T_INT            // KW 'int'
%token T_VOID           // KW 'void'
%token T_RETURN         // KW 'return'

%token<id>  T_ID        // identificador
%token<ival> T_NUM      // numero inteiro

%token T_MAIS           // SIMBOLO '+'
%token T_MENOS          // SIMBOLO '-'
%token T_MULT           // SIMBOLO '*'
%token T_DIV            // SIMBOLO '/'
%token T_ATRIBUICAO     // SIMBOLO '='
%token T_MAIOR          // SIMBOLO '>'
%token T_MENOR          // SIMBOLO '<'
%token T_IGUAL          // SIMBOLO '=='
%token T_DIF            // SIMBOLO '!='
%token T_MAIORIGUAL     // SIMBOLO '>='
%token T_MENORIGUAL     // SIMBOLO '<='
%token T_VIRGULA        // SIMBOLO ','
%token T_PONTOEVIRGULA  // SIMBOLO ';'

%token T_APAR           // SIMBOLO '('
%token T_FPAR           // SIMBOLO ')'
%token T_ACOLCHETE      // SIMBOLO '['
%token T_FCOLCHETE      // SIMBOLO ']'
%token T_ACHAVE         // SIMBOLO '{'
%token T_FCHAVE         // SIMBOLO '}'

%%
    /* gramatica */
    programa: lista-declaracoes

    lista-declaracoes:  lista-declaracoes declaracao
                        | declaracao
                        ;

    declaracao: declaracao-variaveis
                | declaracao-funcao
                ;

    declaracao-variaveis:   tipo-especificador T_ID T_PONTOEVIRGULA
                            | tipo-especificador T_ID T_ACOLCHETE T_NUM T_FCOLCHETE
                            ;

    tipo-especificador: T_INT
                        | T_VOID
                        ;

    declaracao-funcao:  tipo-especificador T_ID T_APAR parametros T_FPAR escopo
                        ;

    parametros: lista-parametros
                | T_VOID
                ;

    lista-parametros:   lista-parametros T_VIRGULA parametro
                        | parametro
                        ;

    parametro:  tipo-especificador T_ID
                | tipo-especificador T_ID T_ACOLCHETE T_FCOLCHETE
                ;

    escopo: T_ACHAVE declaracoes-locais lista-escopo T_FCHAVE
            ;

    declaracoes-locais: declaracoes-locais declaracao-variaveis
                        | 
                        ;

    lista-escopo:   lista-escopo corpo
                    |
                    ;

    corpo:  declaracao-expressao
            | escopo
            | declaracao-selecao
            | declaracao-iteracao
            | declaracao-retorno
            ;

    declaracao-expressao:   expressao T_PONTOEVIRGULA
                            | T_PONTOEVIRGULA
                            ;

    declaracao-selecao: T_IF T_APAR expressao T_FPAR corpo
                        | T_IF T_APAR expressao T_FPAR corpo T_ELSE corpo
                        ;

    declaracao-iteracao: T_WHILE T_APAR expressao T_FPAR corpo

    declaracao-retorno: T_RETURN T_PONTOEVIRGULA
                        | T_RETURN expressao T_PONTOEVIRGULA
                        ;

    expressao: variavel = expressao | expressao-simples

    variavel:   T_ID
                | T_ID T_ACOLCHETE expressao T_FCOLCHETE
                ;

    expressao-simples: expressao-soma relacional expressao-soma | expressao-soma

    relacional: T_MENORIGUAL
                | T_MENOR
                | T_MAIOR
                | T_MAIORIGUAL
                | T_IGUAL
                | T_DIFERENTE
                ;

    expressao-soma: expressao-soma soma termo
                    | termo
                    ;

    soma:   T_MAIS
            | T_MENOS
            ;

    termo:  termo mult fator
            | fator
            ;

    mult:   T_MULT
            | T_DIV
            ;

    fator:  T_APAR expressao T_FPAR
            | variavel
            | chamada-funcao
            | T_NUM
            ;

    chamada-funcao: T_ID T_APAR argumentos T_FPAR ;

    argumentos: lista-argumentos
                |
                ;

    lista-argumentos:   lista-argumentos T_VIRGULA expressao
                        | expressao
                        ;
%%

int main(int argc, char **argv){
    if(argc > 1){
        yyin = fopen(argv[1], "r");
        if(yyin == NULL){
            fprintf(stderr, "Problema na leitura do arquivo!");
            exit(1);
        }
    }
    else{
        yyin = fopen("flex/entrada.txt", "r");        
        if(yyin == NULL){
            fprintf(stderr, "Problema na leitura do arquivo!");
            exit(1);
        }
    }

    do{
        yyparse();
    }
    while(!feof(yyin));

    fclose(yyin);

    return 0; // Deu tudo certo

}

void yyerror(const char* s) {
	fprintf(stderr, "Parse error: %s\n", s);
	exit(1);
}