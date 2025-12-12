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

    typedef enum { TipoProgram, TipoDeclaracaoVar, TipoDeclaracaoFunc, TipoLista, TipoParam, TipoBloco, TipoIf, TipoWhile, TipoReturn, TipoAtrib, TipoOperador, TipoVar, TipoNum, TipoChamada, TipoAcessoVetor } TipoNo;

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
    AST* criarNo(TipoNo tipo, int num_filhos);
    AST* criarNoLista(AST* a, AST* b);
    int resultadoAST(AST* no);
    void liberaAST(AST* no);

    /* Protótipo para gerar arquivo .dot */
    void gerarDOT(AST* raiz);
    const char* nomeTipoNo(TipoNo tipo);
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
%type <no> variavel
%type <no> expressao expressaoSimples expressaoSoma termo fator
%type <ival> soma mult relacional
%type <no> listaDeclaracoes declaracaoSelecao declaracao corpo declaracaoIteracao declaracaoRetorno chamadaFuncao declaracaoExpressao argumentos listaArgumentos
%type <no> declaracaoFuncao parametros escopo parametro listaParametros declaracoesLocais listaEscopo declaracaoVariaveis
%type <no> tipoEspecificador

%start programa

%%
    /* gramatica */
    programa: listaDeclaracoes { gerarDOT($1); }

    listaDeclaracoes:   listaDeclaracoes declaracao { 
                                                        if($1 == NULL) {
                                                            $$ = criarNo(TipoProgram, 1);
                                                            $$->filhos[0] = $2;
                                                        } else {
                                                            int n = $1->num_filhos;
                                                            $1->num_filhos++;
                                                            $1->filhos = realloc($1->filhos, $1->num_filhos * sizeof(AST*));
                                                            $1->filhos[n] = $2;
                                                            $$ = $1;
                                                        }
                                                    }
                        | declaracao { $$ = criarNo(TipoProgram, 1); $$->filhos[0] = $1; }
                        ;

    declaracao: declaracaoVariaveis
                | declaracaoFuncao
                ;

    declaracaoVariaveis:    tipoEspecificador T_ID T_PONTOEVIRGULA  { 
                                                                        declararVariavel($2, TipoInteiro, 1);

                                                                        AST* no = criarNo(TipoDeclaracaoVar, 1);
                                                                        AST* var = criarNo(TipoVar, 0);
                                                                        var->dado.nome = strdup($2);

                                                                        no->filhos[0] = var;

                                                                        $$ = no;
                                                                        free($2); 
                                                                    }
                            | tipoEspecificador T_ID T_ACOLCHETE T_NUM T_FCOLCHETE  {
                                                                                        declararVariavel($2, TipoVetor, $4);

                                                                                        AST* no = criarNo(TipoDeclaracaoVar, 0);
                                                                                        AST* var = criarNo(TipoVar, 0);
                                                                                        var->dado.nome = strdup($2);

                                                                                        AST* tamanho = criarNo(TipoNum, 0);
                                                                                        tamanho->dado.valor = $4;

                                                                                        no->filhos[0] = var;
                                                                                        no->filhos[1] = tamanho;

                                                                                        $$ = no;
                                                                                        free($2); 
                                                                                    }
                            ;

    tipoEspecificador:  T_INT
                        | T_VOID
                        ;

    declaracaoFuncao:   tipoEspecificador T_ID T_APAR parametros T_FPAR escopo  {
                                                                                    AST* nomeFunc = criarNo(TipoVar, 0);
                                                                                    nomeFunc->dado.nome = strdup($2);

                                                                                    AST* no = criarNo(TipoDeclaracaoFunc, 3);
                                                                                    no->filhos[0] = nomeFunc;
                                                                                    no->filhos[1] = $4;
                                                                                    no->filhos[2] = $6;
                                                                                    $$ = no;
                                                                                    free($2);
                                                                                }
                        ;

    parametros: listaParametros { $$ = $1; }
                | T_VOID { $$ = NULL; }
                ;

    listaParametros:    listaParametros T_VIRGULA parametro { $$ = criarNoLista($1, $3); }
                        | parametro { $$ = $1; }
                        ;

    parametro:  tipoEspecificador T_ID  {
                                            AST* no = criarNo(TipoParam, 0);
                                            no->dado.nome = strdup($2);
                                            $$ = no;
                                            free($2);
                                        }
                | tipoEspecificador T_ID T_ACOLCHETE T_FCOLCHETE    {
                                                                        AST* no = criarNo(TipoParam, 0);
                                                                        no->dado.nome = strdup($2);
                                                                        $$ = no;
                                                                        free($2);
                                                                    }
                ;

    escopo: T_ACHAVE { entrarEscopo(); } declaracoesLocais listaEscopo T_FCHAVE {   sairEscopo(); 
                                                                                    AST* lista = criarNoLista($3, $4);
                                                                                    AST* no = criarNo(TipoBloco, 1);
                                                                                    no->filhos[0] = lista;
                                                                                    $$ = no;
                                                                                }
            ;

    declaracoesLocais:  declaracoesLocais declaracaoVariaveis { $$ = criarNoLista($1, $2); }
                        |  /* vazio */ { $$ = NULL; }
                        ;

    listaEscopo:    listaEscopo corpo   { 
                                            $$ = criarNoLista($1, $2);
                                        }
                    | /* vazio */ { $$ = NULL; }
                    ;

    corpo:  declaracaoExpressao { $$ = $1; }
            | escopo { $$ = $1; }
            | declaracaoSelecao { $$ = $1; }
            | declaracaoIteracao { $$ = $1; }
            | declaracaoRetorno { $$ = $1; }
            ;

    declaracaoExpressao:   expressao T_PONTOEVIRGULA { $$ = $1; }
                            | T_PONTOEVIRGULA { $$ = NULL; }
                            ;

    declaracaoSelecao: T_IF T_APAR expressao T_FPAR corpo   {
                                                                AST* no = criarNo(TipoIf, 2);
                                                                no->filhos[0] = $3;
                                                                no->filhos[1] = $5;
                                                                $$ = no;
                                                            }
                        | T_IF T_APAR expressao T_FPAR corpo T_ELSE corpo   {
                                                                                AST* no = criarNo(TipoIf, 3);
                                                                                no->filhos[0] = $3;
                                                                                no->filhos[1] = $5;
                                                                                no->filhos[2] = $7;
                                                                                $$ = no;
                                                                            }
                        ;

    declaracaoIteracao: T_WHILE T_APAR expressao T_FPAR corpo   { 
                                                                    AST* no = criarNo(TipoWhile, 2);
                                                                    no->filhos[0] = $3;
                                                                    no->filhos[1] = $5;
                                                                    $$ = no;
                                                                }

    declaracaoRetorno: T_RETURN T_PONTOEVIRGULA {
                                                    AST* no = criarNo(TipoReturn, 0);
                                                    $$ = no;
                                                }
                        | T_RETURN expressao T_PONTOEVIRGULA    {
                                                                    AST* no = criarNo(TipoReturn, 1);
                                                                    no->filhos[0] = $2;
                                                                    $$ = no;
                                                                }
                        ;

    expressao:  variavel T_ATRIBUICAO expressao {
                                                    int valor = resultadoAST($3);
                                                    if($1->tipo == TipoVar)
                                                        atribuirValorAVariavel($1->dado.nome, valor, -1);
                                                    else if($1->tipo == TipoAcessoVetor && $1->filhos) {
                                                        int indice = resultadoAST($1->filhos[0]);
                                                        atribuirValorAVariavel($1->dado.nome, valor, indice);
                                                    }
                                                    AST* no = criarNo(TipoAtrib, 2);
                                                    no->filhos[0] = $1;
                                                    no->filhos[1] = $3;
                                                    $$ = no;
                                                }
                | expressaoSimples { $$ = $1; }
                ;

    variavel:   T_ID    {
                            AST* no = criarNo(TipoVar, 0);
                            no->dado.nome = strdup($1);
                            $$ = no;
                        }
                | T_ID T_ACOLCHETE expressao T_FCOLCHETE    {
                                                                AST* no = criarNo(TipoAcessoVetor, 1);
                                                                no->dado.nome = strdup($1);
                                                                no->filhos[0] = $3; // Indice do vetor vai como filho
                                                                $$ = no;
                                                            }
                ;

    expressaoSimples:  expressaoSoma relacional expressaoSoma   {
                                                                    char op;
                                                                    switch($2) {
                                                                        case 1: op = '<'; break; // '<=' arrumar depois
                                                                        case 2: op = '<'; break;
                                                                        case 3: op = '>'; break;
                                                                        case 4: op = '>'; break; // '>=' arrumar dps
                                                                        case 5: op = '='; break; // '=' arrumar dps
                                                                        case 6: op = '!'; break; // '!=' arrumar dps
                                                                        default: op = ' ';
                                                                    }
                                                                    AST* no = criarNo(TipoOperador, 2);
                                                                    no->dado.operador = op;
                                                                    no->filhos[0] = $1;
                                                                    no->filhos[1] = $3;
                                                                    $$ = no;
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
                                                char op = ($2 == 1 ? '+' : '-');
                                                AST* no = criarNo(TipoOperador, 2);
                                                no->dado.operador = op;
                                                no->filhos[0] = $1;
                                                no->filhos[1] = $3;
                                                $$ = no;
                                            }
                    | termo { $$ = $1; }
                    ;

    soma:   T_MAIS { $$ = 1 }
            | T_MENOS { $$ = 2 }
            ;

    termo:  termo mult fator    {
                                    char op = ($2 == 1 ? '*' : '/');
                                    AST* no = criarNo(TipoOperador, 2);
                                    no->dado.operador = op;
                                    no->filhos[0] = $1;
                                    no->filhos[1] = $3;
                                    $$ = no;
                                }
            | fator { $$ = $1; }
            ;

    mult:   T_MULT { $$ = 1; }
            | T_DIV { $$ = 2; }
            ;

    fator:  T_APAR expressao T_FPAR { $$ = $2; }
            | variavel { $$ = $1; }
            | chamadaFuncao { $$ = $1; }
            | T_NUM { AST* no = criarNo(TipoNum, 0); no->dado.valor = $1; $$ = no; }
            ;

    chamadaFuncao:  T_ID T_APAR argumentos T_FPAR   {
                                                        AST* nomeFunc = criarNo(TipoVar, 0);
                                                        nomeFunc->dado.nome = strdup($1);

                                                        AST* no = criarNo(TipoChamada, 2);
                                                        no->filhos[0] = nomeFunc;
                                                        no->filhos[1] = $3;
                                                        $$ = no;
                                                        free($1);
                                                    }
                    ;

    argumentos: listaArgumentos { $$ = $1; }
                |               { $$ = NULL; }
                ;

    listaArgumentos:    listaArgumentos T_VIRGULA expressao { $$ = criarNoLista($1, $3); }
                        | expressao { $$ = $1; }
                        ;
%%

AST* criarNo(TipoNo tipo, int num_filhos) {
    AST* no = malloc(sizeof(AST));
    no->tipo = tipo;
    no->num_filhos = num_filhos;

    if(num_filhos > 0) 
        no->filhos = calloc(num_filhos, sizeof(AST*));
    else
        no->filhos = NULL;
    
    return no;
}

AST* criarNoLista(AST* a, AST* b) {
    if(!a) {
        AST* no = criarNo(TipoLista, 1);
        no->filhos[0] = b;
        return no;
    }

    a->num_filhos++;
    a->filhos = realloc(a->filhos, a->num_filhos * sizeof(AST*));
    a->filhos[a->num_filhos - 1] = b;
    return a;
}

const char* nomeTipoNo(TipoNo tipo) {
    switch (tipo) {
        case TipoProgram:         return "Program";
        case TipoDeclaracaoVar:   return "int";
        case TipoDeclaracaoFunc:  return "DeclFunc";
        case TipoLista:           return "Lista";
        case TipoParam:           return "Parametro";
        case TipoBloco:           return "Bloco";
        case TipoIf:              return "If";
        case TipoWhile:           return "While";
        case TipoReturn:          return "Return";
        case TipoAtrib:           return "=";
        case TipoOperador:        return "Operador";
        case TipoVar:        return "Variavel";
        case TipoNum:             return "Numero";
        case TipoChamada:         return "ChamadaFuncao";
        default:                  return "???";
    }
}

void imprimirNoDOT(AST* no, FILE* file) {
    if (!no) return;

    char nomeDoNo[30];

    switch (no->tipo) {
        case TipoVar:
            strcpy(nomeDoNo, no->dado.nome);
            break;
        case TipoNum:
            snprintf(nomeDoNo, 30, "%d", no->dado.valor);
            break;
        case TipoOperador:
            nomeDoNo[0] = no->dado.operador;
            nomeDoNo[1] = '\0';
            break;
        default:
            strcpy(nomeDoNo, nomeTipoNo(no->tipo));
            break;
    }

    for(int i=0; i<no->num_filhos; i++) {
        if(no->filhos) {
            AST* filho = no->filhos[i];
            if(filho) {
                char nomeFilho[50];
                switch (filho->tipo) {
                    case TipoVar: case TipoAcessoVetor:
                        strcpy(nomeFilho, filho->dado.nome); break;
                    case TipoNum:
                        snprintf(nomeFilho, 50, "%d", filho->dado.valor); break;
                    case TipoOperador:
                        nomeFilho[0] = filho->dado.operador; nomeFilho[1] = '\0'; break;
                    default:
                        strcpy(nomeFilho, nomeTipoNo(filho->tipo));
                }
                fprintf(file, "  node%p[label=\"%s\"];\n", (void*)no, nomeDoNo);
                fprintf(file, "  node%p[label=\"%s\"];\n", (void*)filho, nomeFilho);
                fprintf(file, "  node%p -> node%p;\n", (void*)no, (void*)filho);
                imprimirNoDOT(filho, file);
            }
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

int resultadoAST(AST* no) {
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
}

void liberaAST(AST* no) {
    if (!no) return;
    int i;
    for(i=0;i<no->num_filhos;i++)
        liberaAST(no->filhos[i]);
    free(no->filhos);
    if (no->tipo == TipoVar || no->tipo == TipoAcessoVetor || no->tipo == TipoParam) free(no->dado.nome);
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