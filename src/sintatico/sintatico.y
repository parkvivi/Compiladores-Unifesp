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
            int valor;
        } dado;
        struct AST* filhos[5];
    } AST;

    /* ================== PROTÓTIPOS DA ÁRVORE ================== */

    AST* criarNo(TipoNo tipo);
    void liberaAST(AST* no);

    /* Protótipo para gerar arquivo .dot */
    void gerarDOT(AST* raiz);
    const char* nomeTipoNo(AST* no);
    void imprimirNoDOT(AST* no, FILE* file);

    /* ================== TABELA DE SÍMBOLOS COM ESCOPO ================== */

    // Categoria do símbolo -> variável ou função
    typedef enum { Variavel, Funcao } CategoriaSimbolo;
    // Tipo da variável -> inteiro ou vetor
    typedef enum { TipoInteiro, TipoVetor } TipoVariavel;

    // Nó da tabela de símbolos
    typedef struct Simbolo {
        char *nome;
        CategoriaSimbolo categoria;
        struct Simbolo *prox;

        // categoria é Variavel
        TipoVariavel tipo;
        int tamanho;
        union {
            int inteiro;
            int *vetor;
        } valor;
    } Simbolo;

    typedef struct Escopo {
        Simbolo *simbolos;
        int linhaInicio;
        struct Escopo *prox;
    } Escopo;

    Escopo *topo_escopo = NULL;

    void entrarEscopo(int linhaInicio) { // push
        Escopo *e = (Escopo*) malloc(sizeof(Escopo));
        e->simbolos = NULL;
        e->linhaInicio = linhaInicio;
        e->prox = topo_escopo;
        topo_escopo = e;
    }

    void sairEscopo() { // pop
        if (topo_escopo == NULL) return;

        Simbolo *s = topo_escopo->simbolos;

        if (topo_escopo->prox == NULL && strcmp(topo_escopo->simbolos->nome, "main") != 0) {
            // main() não foi declarada como último elemento do escopo global 
            fprintf(stderr, "ERRO SEMANTICO: funcao \"main\" nao declarada ou declarada incorretamente");
            return;
        }

        if (s) {
            printf("ESCOPO: LINHAS %d a %d\n", topo_escopo->linhaInicio, linha_atual);
        }

        while (s) {
            Simbolo *tmp = s;
            if (s->categoria == Variavel) {
                if (s->tipo == TipoInteiro) {
                    printf("\t-> [variavel//inteiro]");
                } else if (s->tipo == TipoVetor) {
                    printf("\t-> [variavel//vetor]");
                }
            } else if (s->categoria == Funcao) {
                printf("\t-> [funcao]");
            }
            printf(" %s\n", tmp->nome);
            s = s->prox;
            // Libera nome do símbolo
            free(tmp->nome);
            // Libera vetor caso seja variável e vetor
            if (tmp->categoria == Variavel && tmp->tipo == TipoVetor) {
                free(tmp->valor.vetor);
            }
            free(tmp);
        }

        Escopo *tmpE = topo_escopo;
        topo_escopo = topo_escopo->prox;
        free(tmpE);
    }

    Simbolo* buscarSimboloEscopoAtual(const char *nome) {
        if (!topo_escopo) return NULL;
        Simbolo *s = topo_escopo->simbolos;
        while (s) {
            if (strcmp(s->nome, nome) == 0) return s;
            s = s->prox;
        }
        return NULL;
    }

    Simbolo* buscarSimboloTodosEscopos(const char *nome) {
        Escopo *e = topo_escopo;
        while (e) {
            Simbolo *s = e->simbolos;
            while (s) {
                if (strcmp(s->nome, nome) == 0) return s;
                s = s->prox;
            }
            e = e->prox;
        }
        return NULL;
    }

    void declararSimbolo(const char *nome, CategoriaSimbolo categoria, TipoVariavel tipo, int tamanhoVetor) {
        if (!topo_escopo) {
            fprintf(stderr, "ERRO INTERNO: nenhum escopo ativo ao declarar '%s'.\n", nome);
            return;
        }
        if (buscarSimboloEscopoAtual(nome) != NULL) {
            // Erro de variavel duplicada no escopo
            fprintf(stderr, "ERRO SEMANTICO: identificador \"%s\" - LINHA: %d\n", nome, linha_atual);
            return;
        }
        Simbolo *s = (Simbolo*) malloc(sizeof(Simbolo));
        s->nome = strdup(nome);
        s->categoria = categoria;
        s->prox = topo_escopo->simbolos;
        topo_escopo->simbolos = s;

        if (s->categoria != Variavel) {
            return;
        }
        
        // Continua somente se simbolo for variavel
        s->tipo = tipo;

        // Inicialização e Alocação
        if (tipo == TipoInteiro) {
            s->tamanho = 1;
            s->valor.inteiro = 0; 
        } else if (tipo == TipoVetor) {
            s->tamanho = tamanhoVetor;
            s->valor.vetor = (int*) calloc(tamanhoVetor, sizeof(int));
        }
    }

    void atribuirValorAVariavel(const char *nome, int valorAtribuido, int indiceVetor) {
        Simbolo *s = buscarSimboloTodosEscopos(nome);
        if (!s) {
            // Erro de variavel nao declarada
            fprintf(stderr, "ERRO SEMANTICO: identificador \"%s\" - LINHA: %d\n", nome, linha_atual);
            return;
        }

        if (s->categoria != Variavel) {
            // Erro de tentativa de atribuição a algo que não é variável
            fprintf(stderr, "ERRO SEMANTICO: identificador \"%s\" - LINHA: %d\n", nome, linha_atual);
            return;
        }

        // Se é vetor...
        if (s->tipo == TipoVetor) {
            if (indiceVetor >= s->tamanho || indiceVetor < 0) {
                // Erro de tentativa de acesso do vetor em campo não existente
                fprintf(stderr, "ERRO SEMANTICO: identificador \"%s\" - LINHA: %d\n", nome, linha_atual);
                return;
            }
            s->valor.vetor[indiceVetor] = valorAtribuido;
            return;
        }

        // Se é inteiro simples...
        s->valor.inteiro = valorAtribuido;
    }

    int buscarValorDeVariavel(const char *nome, int indiceVetor) {
        Simbolo *s = buscarSimboloTodosEscopos(nome);
        if (!s) {
            // Erro de variavel nao declarada
            fprintf(stderr, "ERRO SEMANTICO: identificador \"%s\" - LINHA: %d\n", nome, linha_atual);
            return 0;
        }

        if (s->categoria != Variavel) {
            // Erro de tentativa de acesso a algo que não é variável
            fprintf(stderr, "ERRO SEMANTICO: identificador \"%s\" - LINHA: %d\n", nome, linha_atual);
            return 0;
        }

        // Se é vetor...
        if (s->tipo == TipoVetor) {
            if (indiceVetor >= s->tamanho) {
                // Erro de tentativa de acesso do vetor em campo não existente
                fprintf(stderr, "ERRO SEMANTICO: identificador \"%s\" - LINHA: %d\n", nome, linha_atual);
                return 0;
            }
            return s->valor.vetor[indiceVetor];
        }

        // Se é inteiro simples...
        return s->valor.inteiro;
    }
%}

%union {
    int                 ival;
    char                *id;
    struct AST*         no;
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
                                                                        declararSimbolo($2, Variavel, TipoInteiro, 1);

                                                                        $$ = criarNo(TipoDeclaracaoVars);
                                                                        $$->filhos[0] = $1;

                                                                        AST* var = criarNo(TipoID);
                                                                        var->dado.nome = strdup($2);

                                                                        $$->filhos[1] = var;

                                                                        free($2);
                                                                    }
                            | tipoEspecificador T_ID T_ACOLCHETE T_NUM T_FCOLCHETE T_PONTOEVIRGULA  {
                                                                                                        declararSimbolo($2, Variavel, TipoVetor, $4);

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

    tipoEspecificador:  T_INT { $$ = criarNo(TipoEspecifico); $$->dado.nome = malloc(strlen("int") + 1); strcpy($$->dado.nome, "int");  }
                        | T_VOID { $$ = criarNo(TipoEspecifico); $$->dado.nome = malloc(strlen("void") + 1); strcpy($$->dado.nome, "void");  }
                        ;

    declaracaoFuncao:   tipoEspecificador T_ID T_APAR parametros T_FPAR escopo  {
                                                                                    declararSimbolo($2, Funcao, TipoInteiro, 0); // TipoVariavel e tamanhoVetor não são relevantes para funções

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
                | T_VOID { $$ = criarNo(TipoParametros); AST* no = criarNo(TipoEspecifico); no->dado.nome = malloc(strlen("void") + 1); strcpy(no->dado.nome, "void"); $$->filhos[0] = no;  }
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

    escopo: T_ACHAVE { entrarEscopo(linha_atual); } declaracoesLocais listaEscopo T_FCHAVE {   sairEscopo();
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
                                                                                no->dado.nome = malloc(strlen("else") + 1);
                                                                                strcpy(no->dado.nome, "else");
                                                                                $$->filhos[2] = no;
                                                                                $$->filhos[3] = $7;
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

                                                    // ARRUMAR ATRIBUIR VALOR A VARIAVEIS DEPOIS (tem q percorrer arvore para resultado da expressao?).

                                                    $$ = criarNo(TipoExpressao);
                                                    $$->filhos[0] = $1;
                                                    AST* no = criarNo(TipoID); // para igual
                                                    no->dado.nome = malloc(strlen("=") + 1);
                                                    strcpy(no->dado.nome, "=");
                                                    $$->filhos[1] = no;
                                                    $$->filhos[2] = $3;
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

    relacional: T_MENORIGUAL { $$ = criarNo(TipoRelacional); $$->dado.nome = malloc(strlen("<=") + 1); strcpy($$->dado.nome, "<="); } // TipoRelacional == dado.nome
                | T_MENOR { $$ = criarNo(TipoRelacional); $$->dado.nome = malloc(strlen("<") + 1); strcpy($$->dado.nome, "<"); }
                | T_MAIOR { $$ = criarNo(TipoRelacional); $$->dado.nome = malloc(strlen(">") + 1); strcpy($$->dado.nome, ">"); }
                | T_MAIORIGUAL { $$ = criarNo(TipoRelacional); $$->dado.nome = malloc(strlen(">=") + 1); strcpy($$->dado.nome, ">="); }
                | T_IGUAL { $$ = criarNo(TipoRelacional); $$->dado.nome = malloc(strlen("==") + 1); strcpy($$->dado.nome, "=="); }
                | T_DIFERENTE { $$ = criarNo(TipoRelacional); $$->dado.nome = malloc(strlen("!=") + 1); strcpy($$->dado.nome, "!="); }
                ;

    expressaoSoma: expressaoSoma soma termo {
                                                $$ = criarNo(TipoExpressaoSoma);
                                                $$->filhos[0] = $1;
                                                $$->filhos[1] = $2;
                                                $$->filhos[2] = $3;
                                            }
                    | termo { $$ = criarNo(TipoExpressaoSoma); $$->filhos[0] = $1; }
                    ;

    soma:   T_MAIS { $$ = criarNo(TipoSoma); $$->dado.nome = malloc(strlen("+") + 1); strcpy($$->dado.nome, "+"); } //TipoSoma == dado.nome
            | T_MENOS { $$ = criarNo(TipoSoma); $$->dado.nome = malloc(strlen("-") + 1); strcpy($$->dado.nome, "-"); }
            ;

    termo:  termo mult fator    {
                                    $$ = criarNo(TipoTermo);
                                    $$->filhos[0] = $1;
                                    $$->filhos[1] = $2;
                                    $$->filhos[2] = $3;
                                }
            | fator { $$ = criarNo(TipoTermo); $$->filhos[0] = $1; }
            ;

    mult:   T_MULT { $$ = criarNo(TipoMult); $$->dado.nome = malloc(strlen("*") + 1); strcpy($$->dado.nome, "*"); } //TipoMult == dado.nome
            | T_DIV { $$ = criarNo(TipoMult); $$->dado.nome = malloc(strlen("/") + 1); strcpy($$->dado.nome, "/"); }
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
    static char buffer[50];
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
        case TipoCorpo:             return "corpo";
        case TipoNum:               sprintf(buffer, "%d", no->dado.valor); return buffer;

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
    file = fopen("build/arvore.dot", "w");
    if(file==NULL) {
        printf("Erro ao abrir arquivo para gerar arquivo.dot\n");
        return;
    }
    
    fprintf(file, "digraph AST {\n");

    imprimirNoDOT(raiz, file);

    fprintf(file, "}\n");
    fclose(file);

    //printf("Arquivo arvore.dot gerado com sucesso!\n");
}

void liberaAST(AST* no) {
    if (!no) return;
    int i;
    for(i=0;i<5;i++)
        liberaAST(no->filhos[i]);
    if(no->tipo == TipoID || no->tipo == TipoEspecifico || no->tipo == TipoRelacional || no->tipo == TipoSoma || no->tipo == TipoMult) free(no->dado.nome);
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
    entrarEscopo(linha_atual);

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