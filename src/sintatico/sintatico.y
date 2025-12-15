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

    typedef enum { TipoPrograma, TipoListaDeclaracoes, TipoDeclaracao, TipoDeclaracaoVars, TipoEspecifico, TipoDeclaracaoFunc, TipoParametros, TipoListaParametros, TipoParametro, TipoEscopo, TipoDeclaracaoLocais, TipoListaEscopo, TipoCorpo, TipoDeclaracaoExpressao, TipoDeclaracaoSelecao, TipoDeclaracaoIteracao, TipoDeclaracaoRetorno, TipoExpressao, TipoVar, TipoExpressaoSimples, TipoRelacional, TipoExpressaoSoma, TipoSoma, TipoTermo, TipoMult, TipoFator, TipoChamadaFuncao, TipoArgumentos, TipoListaArgumentos, TipoID, TipoNum } TipoNo;

    typedef struct AST {
        TipoNo tipo;
        union {
            char* nome; // nome de funções ou variáveis
            char operador;
            int valor;
        } dado;
        struct AST* filhos[5];
    } AST;

    /* ================== PROTÓTIPOS DA ÁRVORE ================== */
    AST* criarNo(TipoNo tipo);
    AST* criarNoLista(AST* a, AST* b);
    int resultadoAST(AST* no);
    void liberaAST(AST* no);

    /* Protótipo para gerar arquivo .dot */
    void gerarDOT(AST* raiz);
    const char* nomeTipoNo(AST* no);
    void imprimirNoDOT(AST* no, FILE* file);

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
%}

%union {
    int                 ival;
    char                *id;
    struct AST*         no;
}

%error-verbose

/* TOKENS */
%token<id> T_IF             // KW 'if'
%token<id> T_ELSE           // KW 'else'
%token<id> T_WHILE          // KW 'while'
%token<id> T_INT            // KW 'int'
%token<id> T_VOID           // KW 'void'
%token<id> T_RETURN         // KW 'return'

%token<id>  T_ID        // identificador
%token<ival> T_NUM      // numero inteiro

%token<id> T_MAIS           // SIMBOLO '+'
%token<id> T_MENOS          // SIMBOLO '-'
%token<id> T_MULT           // SIMBOLO '*'
%token<id> T_DIV            // SIMBOLO '/'
%token<id> T_ATRIBUICAO     // SIMBOLO '='
%token<id> T_MAIOR          // SIMBOLO '>'
%token<id> T_MENOR          // SIMBOLO '<'
%token<id> T_IGUAL          // SIMBOLO '=='
%token<id> T_DIFERENTE      // SIMBOLO '!='
%token<id> T_MAIORIGUAL     // SIMBOLO '>='
%token<id> T_MENORIGUAL     // SIMBOLO '<='
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
%type <no> programa listaDeclaracoes declaracao declaracaoVariaveis tipoEspecificador
%type <no> declaracaoFuncao parametros listaParametros parametro escopo declaracoesLocais
%type <no> listaEscopo corpo declaracaoExpressao declaracaoSelecao declaracaoIteracao declaracaoRetorno expressao variavel expressaoSimples relacional expressaoSoma soma termo mult fator chamadaFuncao argumentos listaArgumentos

%start programa

%%
    /* gramatica */
    programa: listaDeclaracoes  {
                                    $$ = criarNo(TipoPrograma);
                                    $$->filhos[0] = $1;
                                    gerarDOT($$);
                                    // gerar quadruplas
                                    liberaAST($$);
                                }

    listaDeclaracoes:   listaDeclaracoes declaracao {
                                                        $$ = criarNo(TipoListaDeclaracoes);
                                                        $$->filhos[0] = $1;
                                                        $$->filhos[1] = $2;
                                                    }
                        | declaracao    {
                                            $$ = criarNo(TipoListaDeclaracoes);
                                            $$->filhos[0] = $1;
                                        }
                        ;

    declaracao: declaracaoVariaveis {
                                        $$ = criarNo(TipoDeclaracao);
                                        $$->filhos[0] = $1;
                                    }
                | declaracaoFuncao  {
                                        $$ = criarNo(TipoDeclaracao);
                                        $$->filhos[0] = $1;  
                                    }
                ;

    declaracaoVariaveis:    tipoEspecificador T_ID T_PONTOEVIRGULA  { 
                                                                        declararVariavel($2, TipoInteiro, 1);

                                                                        $$ = criarNo(TipoDeclaracaoVars);
                                                                        $$->filhos[0] = $1;

                                                                        AST* var = criarNo(TipoID);
                                                                        var->dado.nome = strdup($2);

                                                                        $$->filhos[1] = var;

                                                                        free($2);
                                                                    }
                            | tipoEspecificador T_ID T_ACOLCHETE T_NUM T_FCOLCHETE T_PONTOEVIRGULA  {
                                                                                                        declararVariavel($2, TipoVetor, $4);

                                                                                                        $$ = criarNo(TipoDeclaracaoVars);
                                                                                                        $$->filhos[0] = $1;

                                                                                                        AST* var = criarNo(TipoID);
                                                                                                        var->dado.nome = strdup($2);

                                                                                                        AST* tamanho = criarNo(TipoNum);
                                                                                                        tamanho->dado.valor = $4;

                                                                                                        $$->filhos[1] = var;
                                                                                                        $$->filhos[2] = tamanho;

                                                                                                        free($2); 
                                                                                                    }
                            ;

    tipoEspecificador:  T_INT { $$ = criarNo(TipoEspecifico); $$->dado.nome = strdup($1); free($1);  }
                        | T_VOID { $$ = criarNo(TipoEspecifico);  $$->dado.nome = strdup($1); free($1);  }
                        ;

    declaracaoFuncao:   tipoEspecificador T_ID T_APAR parametros T_FPAR escopo  {
                                                                                    $$ = criarNo(TipoDeclaracaoFunc);
                                                                                    $$->filhos[0] = $1;

                                                                                    AST* nomeFunc = criarNo(TipoID);
                                                                                    nomeFunc->dado.nome = strdup($2);
                                                                                    $$->filhos[1] = nomeFunc;

                                                                                    $$->filhos[2] = $4;
                                                                                    $$->filhos[3] = $6;

                                                                                    free($2);
                                                                                }
                        ;

    parametros: listaParametros { $$ = criarNo(TipoParametros); $$->filhos[0] = $1; }
                | T_VOID { $$ = criarNo(TipoParametros); AST* no = criarNo(TipoEspecifico); no->dado.nome = strdup($1); $$->filhos[0] = no;  }
                ;

    listaParametros:    listaParametros T_VIRGULA parametro { $$ = criarNo(TipoListaParametros); $$->filhos[0] = $1; $$->filhos[1] = $3; }
                        | parametro { $$ = criarNo(TipoListaParametros); $$->filhos[0] = $1; }
                        ;

    parametro:  tipoEspecificador T_ID  {
                                            $$ = criarNo(TipoParametro);
                                            $$->filhos[0] = $1;
                                            AST* no = criarNo(TipoID);
                                            no->dado.nome = strdup($2);
                                            $$->filhos[1] = no;
                                            free($2);
                                        }
                | tipoEspecificador T_ID T_ACOLCHETE T_FCOLCHETE    {
                                                                        $$ = criarNo(TipoParametro);
                                                                        $$->filhos[0] = $1;
                                                                        AST* no = criarNo(TipoID);
                                                                        no->dado.nome = strdup($2);
                                                                        $$->filhos[1] = no;
                                                                        free($2);
                                                                    }
                ;

    escopo: T_ACHAVE { entrarEscopo(); } declaracoesLocais listaEscopo T_FCHAVE {   sairEscopo();
                                                                                    $$ = criarNo(TipoEscopo);
                                                                                    $$->filhos[0] = $3;
                                                                                    $$->filhos[1] = $4;
                                                                                }
            ;

    declaracoesLocais:  declaracoesLocais declaracaoVariaveis { $$ = criarNo(TipoDeclaracaoLocais); $$->filhos[0] = $1; $$->filhos[1] = $2; }
                        |   { $$ = NULL; }
                        ;

    listaEscopo:    listaEscopo corpo   { 
                                            $$ = criarNo(TipoListaEscopo);
                                            $$->filhos[0] = $1;
                                            $$->filhos[1] = $2;
                                        }
                    |  { $$ = NULL; }
                    ;

    corpo:  declaracaoExpressao { $$ = criarNo(TipoCorpo); $$->filhos[0] = $1; }
            | escopo { $$ = criarNo(TipoCorpo); $$->filhos[0] = $1; }
            | declaracaoSelecao { $$ = criarNo(TipoCorpo); $$->filhos[0] = $1; }
            | declaracaoIteracao { $$ = criarNo(TipoCorpo); $$->filhos[0] = $1; }
            | declaracaoRetorno { $$ = criarNo(TipoCorpo); $$->filhos[0] = $1; }
            ;

    declaracaoExpressao:   expressao T_PONTOEVIRGULA { $$ = criarNo(TipoDeclaracaoExpressao); $$->filhos[0] = $1; }
                            | T_PONTOEVIRGULA { $$ = NULL; }
                            ;

    declaracaoSelecao: T_IF T_APAR expressao T_FPAR corpo   { // TipoDeclaracaoSelecao == IF
                                                                $$ = criarNo(TipoDeclaracaoSelecao);
                                                                $$->filhos[0] = $3;
                                                                $$->filhos[1] = $5;
                                                            }
                        | T_IF T_APAR expressao T_FPAR corpo T_ELSE corpo   {
                                                                                $$ = criarNo(TipoDeclaracaoSelecao);
                                                                                $$->filhos[0] = $3;
                                                                                $$->filhos[1] = $5;
                                                                                AST* no = criarNo(TipoID); // no para ELSE
                                                                                no->dado.nome = strdup($6);
                                                                                $$->filhos[2] = no;
                                                                                $$->filhos[3] = $7;
                                                                                free($6);
                                                                            }
                        ;

    declaracaoIteracao: T_WHILE T_APAR expressao T_FPAR corpo   { //DeclaracaoIteracao == WHILE
                                                                    $$ = criarNo(TipoDeclaracaoIteracao);
                                                                    $$->filhos[0] = $3;
                                                                    $$->filhos[1] = $5;
                                                                }

    declaracaoRetorno: T_RETURN T_PONTOEVIRGULA { // DeclaracaoRetorno == return
                                                    $$ = criarNo(TipoDeclaracaoRetorno);
                                                }
                        | T_RETURN expressao T_PONTOEVIRGULA    {
                                                                    $$ = criarNo(TipoDeclaracaoRetorno);
                                                                    $$->filhos[0] = $2;
                                                                }
                        ;

    expressao:  variavel T_ATRIBUICAO expressao {

                                                    /*int valor = resultadoAST($3);
                                                    if($1->tipo == TipoVar)
                                                        atribuirValorAVariavel($1->dado.nome, valor, -1);
                                                    else if($1->tipo == TipoAcessoVetor && $1->filhos) {
                                                        int indice = resultadoAST($1->filhos[0]);
                                                        atribuirValorAVariavel($1->dado.nome, valor, indice);
                                                    } */ // ARRUMAR DEPOIS
                                                    $$ = criarNo(TipoExpressao);
                                                    $$->filhos[0] = $1;
                                                    AST* no = criarNo(TipoID); // para igual
                                                    no->dado.nome = strdup($2);
                                                    $$->filhos[1] = no;
                                                    $$->filhos[2] = $3;
                                                    free($2);
                                                }
                | expressaoSimples { $$ = criarNo(TipoExpressao); $$->filhos[0] = $1; }
                ;

    variavel:   T_ID    {
                            $$ = criarNo(TipoVar);
                            AST* no = criarNo(TipoID);
                            no->dado.nome = strdup($1);
                            $$->filhos[0] = no;
                            free($1);
                        }
                | T_ID T_ACOLCHETE expressao T_FCOLCHETE    {
                                                                $$ = criarNo(TipoVar);
                                                                AST* no = criarNo(TipoID);
                                                                no->dado.nome = strdup($1);
                                                                $$->filhos[0] = no;
                                                                $$->filhos[1] = $3;
                                                                free($1);
                                                            }
                ;

    expressaoSimples:  expressaoSoma relacional expressaoSoma   {
                                                                    $$ = criarNo(TipoExpressaoSimples);
                                                                    $$->filhos[0] = $1;
                                                                    $$->filhos[1] = $2;
                                                                    $$->filhos[2] = $3;
                                                                }
                        | expressaoSoma { $$ = criarNo(TipoExpressaoSimples); $$->filhos[0] = $1; }
                        ;

    relacional: T_MENORIGUAL { $$ = criarNo(TipoRelacional); $$->dado.nome = strdup($1); free($1); } // TipoRelacional == dado.nome
                | T_MENOR { $$ = criarNo(TipoRelacional); $$->dado.nome = strdup($1); free($1); }
                | T_MAIOR { $$ = criarNo(TipoRelacional); $$->dado.nome = strdup($1); free($1); }
                | T_MAIORIGUAL { $$ = criarNo(TipoRelacional); $$->dado.nome = strdup($1); free($1); }
                | T_IGUAL { $$ = criarNo(TipoRelacional); $$->dado.nome = strdup($1); free($1); }
                | T_DIFERENTE { $$ = criarNo(TipoRelacional); $$->dado.nome = strdup($1); free($1); }
                ;

    expressaoSoma: expressaoSoma soma termo {
                                                $$ = criarNo(TipoExpressaoSoma);
                                                $$->filhos[0] = $1;
                                                $$->filhos[1] = $2;
                                                $$->filhos[2] = $3;
                                            }
                    | termo { $$ = criarNo(TipoExpressaoSoma); $$->filhos[0] = $1; }
                    ;

    soma:   T_MAIS { $$ = criarNo(TipoSoma); $$->dado.nome = strdup($1); free($1); } //TipoSoma == dado.nome
            | T_MENOS { $$ = criarNo(TipoSoma); $$->dado.nome = strdup($1); free($1); }
            ;

    termo:  termo mult fator    {
                                    $$ = criarNo(TipoTermo);
                                    $$->filhos[0] = $1;
                                    $$->filhos[1] = $2;
                                    $$->filhos[2] = $3;
                                }
            | fator { $$ = criarNo(TipoTermo); $$->filhos[0] = $1; }
            ;

    mult:   T_MULT { $$ = criarNo(TipoMult); $$->dado.nome = strdup($1); free($1); } //TipoMult == dado.nome
            | T_DIV { $$ = criarNo(TipoMult); $$->dado.nome = strdup($1); free($1);; }
            ;

    fator:  T_APAR expressao T_FPAR { $$ = criarNo(TipoFator); $$->filhos[0] = $2; }
            | variavel { $$ = criarNo(TipoFator); $$->filhos[0] = $1; }
            | chamadaFuncao { $$ = criarNo(TipoFator); $$->filhos[0] = $1; }
            | T_NUM { $$ = criarNo(TipoFator); AST* no = criarNo(TipoNum); no->dado.valor = $1; $$->filhos[0] = no; }
            ;

    chamadaFuncao:  T_ID T_APAR argumentos T_FPAR   {
                                                        $$ = criarNo(TipoChamadaFuncao);
                                                        AST* nomeFunc = criarNo(TipoID);
                                                        nomeFunc->dado.nome = strdup($1);

                                                        $$->filhos[0] = nomeFunc;
                                                        $$->filhos[1] = $3;
                                                        
                                                        free($1);
                                                    }
                    ;

    argumentos: listaArgumentos { $$ = criarNo(TipoArgumentos); $$->filhos[0] = $1; }
                |               { $$ = NULL; }
                ;

    listaArgumentos:    listaArgumentos T_VIRGULA expressao { $$ = criarNo(TipoListaArgumentos); $$->filhos[0] = $1; $$->filhos[1] = $3; }
                        | expressao { $$ = criarNo(TipoListaArgumentos); $$->filhos[0] = $1; }
                        ;
%%

AST* criarNo(TipoNo tipo) {
    AST* no = malloc(sizeof(AST));
    no->tipo = tipo;
    for(int i=0; i<5; i++)
        no->filhos[i] = NULL;
    return no;
}

const char* nomeTipoNo(AST* no) {
    switch (no->tipo) {
        case TipoPrograma:           return "programa";
        case TipoListaDeclaracoes:  return "listaDeclaracoes";
        case TipoDeclaracao:        return "declaracao";
        case TipoDeclaracaoVars:    return "declaracaoVariaveis";
        case TipoEspecifico:        return no->dado.nome;
        case TipoDeclaracaoFunc:    return "declaracaoFuncao";
        case TipoID:                return no->dado.nome;
        case TipoParametros:        return "parametros";
        case TipoListaParametros:   return "listaParametros";
        case TipoParametro:         return "parametro";
        case TipoEscopo:            return "escopo";
        case TipoDeclaracaoLocais:  return "declaracoesLocais";
        case TipoListaEscopo:       return "listaEscopo";
        case TipoDeclaracaoExpressao: return "declaracaoExpressao";
        case TipoDeclaracaoSelecao:     return "if";
        case TipoDeclaracaoIteracao:    return "while";
        case TipoDeclaracaoRetorno:     return "return";
        case TipoExpressao:             return "expressao";
        case TipoVar:               return "variavel";
        case TipoExpressaoSimples:  return "expressaoSimples";
        case TipoRelacional:        return no->dado.nome;
        case TipoExpressaoSoma:     return "expressaoSoma";
        case TipoSoma:              return no->dado.nome;
        case TipoTermo:             return "termo";
        case TipoMult:              return no->dado.nome;
        case TipoFator:             return "fator";
        case TipoChamadaFuncao:     return "chamadaFuncao";
        case TipoArgumentos:        return "argumentos";
        case TipoListaArgumentos:   return "listaArgumentos";

        default:                    return "???";
    }
}

void imprimirNoDOT(AST* no, FILE* file) {
    if (!no) return;

    char nomeDoNo[30];

    strcpy(nomeDoNo, nomeTipoNo(no));

    for(int i=0; i<5; i++) {
        AST* filho = no->filhos[i];
        if(filho) {
            char nomeFilho[50];
            strcpy(nomeFilho, nomeTipoNo(filho));
            fprintf(file, "  node%p[label=\"%s\"];\n", (void*)no, nomeDoNo);
            fprintf(file, "  node%p[label=\"%s\"];\n", (void*)filho, nomeFilho);
            fprintf(file, "  node%p -> node%p;\n", (void*)no, (void*)filho);
            imprimirNoDOT(filho, file);
        }
    }
}

void gerarDOT(AST* raiz) {
    FILE *file;
    file = fopen("arvore.dot", "w");
    if(file==NULL) {
        printf("Erro ao abrir arquivo para gerar arquivo.dot\n");
        return;
    }
    
    fprintf(file, "digraph AST {\n");

    imprimirNoDOT(raiz, file);

    fprintf(file, "}\n");
    fclose(file);

    printf("Arquivo arvore.dot gerado com sucesso!\n");
}

/*int resultadoAST(AST* no) {
    if (!no) return 0;

    if (no->tipo == TipoNum) return no->dado.valor;
    if (no->tipo == TipoVar) return buscarValorDeVariavel(no->dado.nome, -1);
    if (no->tipo == TipoAcessoVetor) return buscarValorDeVariavel(no->dado.nome, resultadoAST(no->filhos[0])); // ESSE resultadoAST FAZ SENTIDO????
    
    if(no->num_filhos == 0) return 0;

    if(no->tipo == TipoOperador) {
        int left = resultadoAST(no->filhos[0]);
        int right = resultadoAST(no->filhos[1]);
        switch (no->dado.operador) {
            case '+': return left + right;
            case '-': return left - right;
            case '*': return left * right;
            case '/': return (right != 0) ? left / right : 0;
        }
    }

    return 0;
}*/

void liberaAST(AST* no) {
    if (!no) return;
    int i;
    for(i=0;i<5;i++)
        liberaAST(no->filhos[i]);
    //liberar nomes de variaveis/funcoes
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

    /* cria escopo global */
    entrarEscopo();

    yyparse();

    /* sai do escopo global e libera memória */
    sairEscopo();

    fclose(yyin);

    return 0;
}

void yyerror(const char* msg) {
	fprintf(stderr, "ERRO SINTATICO: \"%s\" - LINHA: %d\n", msg, linha_atual);
	exit(1);
}