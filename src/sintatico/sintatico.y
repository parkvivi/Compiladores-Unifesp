%{
    #include<stdio.h>
    #include<stdlib.h>
    #include<string.h>

    extern int yylex();
    extern int yyparse();
    extern FILE* yyin;

    extern int linha_atual;

    void yyerror(const char* s);

    /* ================== ESTRUTURAS DA ÁRVORE ================== */

    typedef enum { TipoProgram, TipoDeclaracaoVar, TipoDeclaracaoFunc, TipoLista, TipoParam, TipoBloco, TipoIf, TipoWhile, TipoReturn, TipoAtrib, TipoOperador, TipoVariavel, TipoNum, TipoChamada } TipoNo;

    typedef struct AST {
        TipoNo tipo;
        union {
            char* nome; // nome de funções ou variáveis
            char operador;
            int valor;
        } dado;
        struct AST** filhos;
        int num_filhos;
    } AST;

    /* ================== PROTÓTIPOS DA ÁRVORE ================== */
    AST* criarNoOperador(char operador, AST* esq, AST* dir);
    AST* criarNoNum(int valor);
    AST* criarNoVariavel(char* nome);
    int percorreAST(AST* no);
    void liberaAST(AST* no);

    /* ================== TABELA DE SÍMBOLOS COM ESCOPO ================== */

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
            free(tmp->nome); /* verificar se eh vetor para liberar tambem! */
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

    /* Declaração de variável no escopo atual (que está em topo_escopo) */
    void declararVariavel(const char *nome, TipoVariavel tipo, int tamanhoVetor) {
        if (!topo_escopo) {
            // Topo_escopo é NULL
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
            v->tamanho = tamanhoVetor; // pq salvar tamanho do vetor?
            // Inicia todos os campos com 0
            v->valor.vetor = (int*) calloc(tamanhoVetor, sizeof(int));
        } else {
            /* Falta tipo adequado!!! (como assim?) */
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
            if (indiceVetor >= v->tamanho || indiceVetor < 0) { // Sai do programa se indice for negativo!
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

    typedef struct {
        char* nome;
        int indice;
    } VariavelAcesso;
%}

%union {
    int                 ival;
    char                *id;
    VariavelAcesso*     varAcesso;
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

%left T_MAIS T_MENOS
%left T_MULT T_DIV

// %type<...> ...
%type <varAcesso> variavel
%type <ival> expressao expressaoSimples expressaoSoma termo fator
%type <ival> relacional soma mult

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

    declaracaoVariaveis:    tipoEspecificador T_ID T_PONTOEVIRGULA { declararVariavel($2, TipoInteiro, 1); /*DEBUG: printf("Declaracao de %s\n", $2);*/ free($2); }
                            | tipoEspecificador T_ID T_ACOLCHETE T_NUM T_FCOLCHETE { declararVariavel($2, TipoVetor, $4); /*DEBUG: printf("Declaracao de %s\n", $2);*/ free($2); }
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

    escopo: T_ACHAVE { entrarEscopo(); } declaracoesLocais listaEscopo T_FCHAVE { sairEscopo(); }
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

    expressao:  variavel T_ATRIBUICAO expressao { atribuirValorAVariavel($1->nome, $3, $1->indice); $$ = $3; }
                | expressaoSimples { $$ = $1; }
                ;

    variavel:   T_ID    { 
                            VariavelAcesso* v = malloc(sizeof(VariavelAcesso));
                            v->nome = $1;
                            v->indice = -1; // Não é vetor
                            $$ = v;
                        }
                | T_ID T_ACOLCHETE expressao T_FCOLCHETE    {
                                                                VariavelAcesso* v = malloc(sizeof(VariavelAcesso));
                                                                v->nome = $1;
                                                                v->indice = $3; // Indice do vetor
                                                                $$ = v;
                                                            }
                ;

    expressaoSimples:  expressaoSoma relacional expressaoSoma   { 
                                                                    switch($2) {
                                                                        case 1: $$ = ($1 <= $3); break; //ver se retorna 0 ou 1
                                                                        case 2: $$ = ($1 < $3); break;
                                                                        case 3: $$ = ($1 > $3); break;
                                                                        case 4: $$ = ($1 >= $3); break;
                                                                        case 5: $$ = ($1 == $3); break;
                                                                        case 6: $$ = ($1 != $3); break;
                                                                    }
                                                                }
                        | expressaoSoma { $$ = $1; }
                        ;

    relacional: T_MENORIGUAL { $$ = 1; }
                | T_MENOR { $$ = 2; }
                | T_MAIOR { $$ = 3; }
                | T_MAIORIGUAL { $$ = 4; }
                | T_IGUAL { $$ = 5; }
                | T_DIFERENTE { $$ = 6; }
                ;

    expressaoSoma: expressaoSoma soma termo {
                                                switch($2) {
                                                    case 1: $$ = $1 + $3; break;
                                                    case 2: $$ = $1 - $3; break;
                                                }
                                            }
                    | termo { $$ = $1; }
                    ;

    soma:   T_MAIS { $$ = 1 }
            | T_MENOS { $$ = 2 }
            ;

    termo:  termo mult fator    { 
                                    switch($2) {
                                        case 1: $$ = ($1 * $3); break;
                                        case 2:   if($3 == 0) {
                                                        fprintf(stderr, "Erro semantico: divisao por 0. Assumindo resultado igual a 0.\n");
                                                        $$ = 0;
                                                    } else
                                                        $$ = ($1 / $3);
                                                    break;
                                    }
                                }
            | fator { $$ = $1; }
            ;

    mult:   T_MULT { $$ = 1; }
            | T_DIV { $$ = 2; }
            ;

    fator:  T_APAR expressao T_FPAR { $$ = $2; }
            | variavel { $$ = buscarValorDeVariavel($1->nome, $1->indice); }
            | chamadaFuncao
            | T_NUM { $$ = $1; }
            ;

    chamadaFuncao: T_ID T_APAR argumentos T_FPAR ;

    argumentos: listaArgumentos
                |
                ;

    listaArgumentos:   listaArgumentos T_VIRGULA expressao
                        | expressao
                        ;
%%

AST* criarNoOperador(char operador, AST** filhos, int num_filhos) {
    AST* no = (AST*) malloc(sizeof(AST));
    no->tipo = TipoOperador;
    no->dado.operador = operador;
    no->filhos = filhos;
    no->num_filhos = num_filhos;
    return no;
}

AST* criarNoValor(int valor) {
    AST* no = (AST*) malloc(sizeof(AST));
    no->tipo = TipoValor;
    no->dado.valor = valor;
    no->filhos = NULL;
    no->num_filhos = 0;
    return no;
}

AST* criarNoID(char* nome) {
    AST* no = (AST*) malloc(sizeof(AST));
    no->tipo = TipoID;
    strcpy(no->dado.nome, nome); //talvez malloc para dado.nome antes?
    no->filhos = NULL;
    no->num_filhos = 0;
    return no;
}

int percorreAST(AST* no) {
    if (!no) return 0;
    if (no->tipo == TipoValor) return no->dado.valor;
    
    if(no->num_filhos == 0) return 0;

    int resultado = percorreAST(no->filhos[0]);
    int i;
    for(i=1;i<no->num_filhos;i++) {
        int val = percorreAST(no->filhos[i]);
        switch (no->dado.operador) {
            case '+': return resultado + val;
            case '-': return resultado - val;
            case '*': return resultado * val;
            case '/': return (val != 0) ? resultado / val : 0;
        }
    }

    return 0;
}

void liberaAST(AST* no) {
    if (!no) return;
    int i;
    for(i=0;i<no->num_filhos;i++)
        liberaAST(no->filhos[i]);
    free(no->filhos);
    // talvez liberar dado.nome se for ID?
    free(no);
}

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