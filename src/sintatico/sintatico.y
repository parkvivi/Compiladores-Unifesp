%{
    #include<stdio.h>
    #include<stdlib.h>
    #include<string.h>

    extern int yylex();
    extern int yyparse();
    extern FILE* yyin;

    extern int linha_atual;

    void yyerror(const char* s);

    typedef enum { TipoInteiro, TipoVetor } TipoVariavel;

    /* Escopos e Variaveis */
    typedef struct Variavel {
        char *nome;
        TipoVariavel tipo;
        int tamanho;
        union {
            int inteiro;
            int *vetor;
        } valor;
        struct Variavel *prox;
    } Variavel;

    /* REVER ESCOPO :: TEM QUE SER PILHA */
    typedef struct Escopo {
        Variavel *variaveis;    /* lista encadeada de variaveis deste escopo */
        struct Escopo *prox;    /* escopo imediatamente externo */
    } Escopo;

    Escopo *topo_escopo = NULL;

    void entrarEscopo() { // push
        Escopo *e = (Escopo*) malloc(sizeof(Escopo));
        e->variaveis = NULL;
        e->prox = topo_escopo;
        topo_escopo = e;
    }

    void sairEscopo() { // pop
        if (topo_escopo == NULL) return;

        /* libera as variaveis deste escopo */
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

    Variavel* buscarVariavelEscopoAtual(const char *nome) {
        if (!topo_escopo) return NULL;
        Variavel *v = topo_escopo->variaveis;
        while (v) {
            if (strcmp(v->nome, nome) == 0) return v;
            v = v->prox;
        }
        return NULL;
    }

    Variavel* buscarVariavelTodosEscopos(const char *nome) {
        Escopo *e = topo_escopo;
        while (e) {
            Variavel *v = e->variaveis;
            while (v) {
                if (strcmp(v->nome, nome) == 0) return v;
                v = v->prox;
            }
            e = e->prox;
        }
        return NULL;
    }

    void declararVariavel(const char *nome, TipoVariavel tipo, int tamanhoVetor) {
        if (!topo_escopo) {
            // huh?
            fprintf(stderr, "ERRO INTERNO: nenhum escopo ativo ao declarar '%s'.\n", nome);
            return;
        }
        if (buscarVariavelEscopoAtual(nome) != NULL) {
            // Erro de variavel duplicada no escopo
            fprintf(stderr, "ERRO SEMANTICO: identificador \"%s\" - LINHA: %d\n", nome, linha_atual);
            return;
        }
        Variavel *v = (Variavel*) malloc(sizeof(Variavel));
        v->nome = strdup(nome);
        v->tipo = tipo;

        // Inicialização e Alocação
        if (tipo == TipoInteiro) {
            v->tamanho = 1;
            v->valor.inteiro = 0; 
        } else if (tipo == TipoVetor) {
            v->tamanho = tamanhoVetor;
            // Inicia todos os campos com 0
            v->valor.vetor = (int*) calloc(tamanhoVetor, sizeof(int));
        } else {
            /* Falta tipo adequado!!! */
        }

        v->prox = topo_escopo->variaveis;
        topo_escopo->variaveis = v;
    }

    void atribuirValorAVariavel(const char *nome, int valorAtribuido, int indiceVetor) {
        Variavel *v = buscarVariavelTodosEscopos(nome);
        if (!v) {
            // Erro de variavel nao declarada
            fprintf(stderr, "ERRO SEMANTICO: identificador \"%s\" - LINHA: %d\n", nome, linha_atual);
            // Sair do programa!!
            return;
        }

        // Se é vetor...
        if (v->tipo == TipoVetor) {
            if (indiceVetor >= v->tamanho) {
                // Erro de tentativa de acesso do vetor em campo não existente
                fprintf(stderr, "ERRO SEMANTICO: identificador \"%s\" - LINHA: %d\n", nome, linha_atual);
                // Sair do programa!!
                return;
            }
            v->valor.vetor[indiceVetor] = valorAtribuido;
            return;
        }

        // Se é inteiro simples...
        v->valor.inteiro = valorAtribuido;
    }

    int buscarValorDeVariavel(const char *nome, int indiceVetor) {
        Variavel *v = buscarVariavelTodosEscopos(nome);
        if (!v) {
            // Erro de variavel nao declarada
            fprintf(stderr, "ERRO SEMANTICO: identificador \"%s\" - LINHA: %d\n", nome, linha_atual);
            // Sair do programa!!
            return 0;
        }

        // Se é vetor...
        if (v->tipo == TipoVetor) {
            if (indiceVetor >= v->tamanho) {
                // Erro de tentativa de acesso do vetor em campo não existente
                fprintf(stderr, "ERRO SEMANTICO: identificador \"%s\" - LINHA: %d\n", nome, linha_atual);
                // Sair do programa!!
                return 0;
            }
            return v->valor.vetor[indiceVetor];
        }

        // Se é inteiro simples...
        return v->valor.inteiro;
    }
%}

%union {
    int     ival;
    char    *id;
}

%error-verbose

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
%token T_DIFERENTE      // SIMBOLO '!='
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

// %left T_MAIS T_MENOS
// %left T_MULT T_DIV

// %type<...> ...

%start programa

%%
    /* gramatica */
    programa: listaDeclaracoes

    listaDeclaracoes:  listaDeclaracoes declaracao
                        | declaracao
                        ;

    declaracao: declaracaoVariaveis
                | declaracaoFuncao
                ;

    declaracaoVariaveis:   tipoEspecificador T_ID T_PONTOEVIRGULA
                            | tipoEspecificador T_ID T_ACOLCHETE T_NUM T_FCOLCHETE
                            ;

    tipoEspecificador: T_INT
                        | T_VOID
                        ;

    declaracaoFuncao:  tipoEspecificador T_ID T_APAR parametros T_FPAR escopo
                        ;

    parametros: listaParametros
                | T_VOID
                ;

    listaParametros:   listaParametros T_VIRGULA parametro
                        | parametro
                        ;

    parametro:  tipoEspecificador T_ID
                | tipoEspecificador T_ID T_ACOLCHETE T_FCOLCHETE
                ;

    escopo: T_ACHAVE declaracoesLocais listaEscopo T_FCHAVE
            ;

    declaracoesLocais: declaracoesLocais declaracaoVariaveis
                        | 
                        ;

    listaEscopo:   listaEscopo corpo
                    |
                    ;

    corpo:  declaracaoExpressao
            | escopo
            | declaracaoSelecao
            | declaracaoIteracao
            | declaracaoRetorno
            ;

    declaracaoExpressao:   expressao T_PONTOEVIRGULA
                            | T_PONTOEVIRGULA
                            ;

    declaracaoSelecao: T_IF T_APAR expressao T_FPAR corpo
                        | T_IF T_APAR expressao T_FPAR corpo T_ELSE corpo
                        ;

    declaracaoIteracao: T_WHILE T_APAR expressao T_FPAR corpo

    declaracaoRetorno: T_RETURN T_PONTOEVIRGULA
                        | T_RETURN expressao T_PONTOEVIRGULA
                        ;

    expressao:  variavel T_ATRIBUICAO expressao
                | expressaoSimples
                ;

    variavel:   T_ID
                | T_ID T_ACOLCHETE expressao T_FCOLCHETE
                ;

    expressaoSimples:  expressaoSoma relacional expressaoSoma
                        | expressaoSoma
                        ;

    relacional: T_MENORIGUAL
                | T_MENOR
                | T_MAIOR
                | T_MAIORIGUAL
                | T_IGUAL
                | T_DIFERENTE
                ;

    expressaoSoma: expressaoSoma soma termo
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
            | chamadaFuncao
            | T_NUM
            ;

    chamadaFuncao: T_ID T_APAR argumentos T_FPAR ;

    argumentos: listaArgumentos
                |
                ;

    listaArgumentos:   listaArgumentos T_VIRGULA expressao
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

    return 0;
}

void yyerror(const char* msg) {
	fprintf(stderr, "ERRO SINTATICO: \"%s\" - LINHA: %d\n", msg, linha_atual);
	exit(1);
}