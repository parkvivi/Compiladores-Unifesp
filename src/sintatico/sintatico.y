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
        struct AST* filhos[4];
    } AST;

    AST *raizAST = NULL;
    char* origem = NULL;

    /* ================== PROTÓTIPOS DA ÁRVORE ================== */

    AST* criarNo(TipoNo tipo);
    void liberaAST(AST* no);

    /* Protótipo para gerar arquivo .dot */
    void gerarDOT(AST* raiz);
    const char* nomeTipoNo(AST* no);
    void imprimirNoDOT(AST* no, FILE* file);

    /* ================== Quádruplas (TAC) ================== */

    typedef struct {
        char *operacao;
        char *argumento1;
        char *argumento2;
        char *resultado;
    } Quadrupla;

    Quadrupla *quads = NULL;
    int quads_cont = 0;
    char *funcao_atual = NULL;

    int temp_cont = 0;
    char* novoTemp(){
        char* t = malloc(sizeof(char)*20);
        sprintf(t, "t%d", temp_cont++);
        return t;
    }

    int label_cont = 0;
    char* novoLabel(){
        char* l = malloc(sizeof(char)*20);
        sprintf(l, "L%d", label_cont++);
        return l;
    }

    // Emitir Quadruplas
    void emitir_quads(const char *op, const char *a1, const char *a2, const char *res){
        quads = realloc(quads, sizeof(Quadrupla)*(quads_cont + 1));

        quads[quads_cont].operacao = strdup(op);
        quads[quads_cont].argumento1 = a1  ? strdup(a1) : NULL;
        quads[quads_cont].argumento2 = a2  ? strdup(a2) : NULL;
        quads[quads_cont].resultado  = res ? strdup(res) : NULL;

        quads_cont++;
    }

    // Limpa quadruplas e libera memória
    void limpa_quads(){
        for(int i=0;i<quads_cont;i++){
            free(quads[i].operacao);
            if(quads[i].argumento1) free(quads[i].argumento1);
            if(quads[i].argumento2) free(quads[i].argumento2);
            if(quads[i].resultado) free(quads[i].resultado);
        }

        free(quads);
        quads = NULL;
        quads_cont = 0;
        quads = malloc(sizeof(Quadrupla)*quads_cont);
        temp_cont = 0;
        label_cont = 0;
    }

    /* Gera quádruplas a partir da AST e retorna "place" (string) que contém o resultado */
    char* gerar_quads(AST* no){
        if(!no) return NULL;

        if((no->tipo == TipoDeclaracaoVars)) { // declaracao de variaveis
            char* tipo = no->filhos[0]->dado.nome; 
            char *nome = no->filhos[1]->dado.nome;

            emitir_quads("VAR", tipo, nome, funcao_atual);

            if(no->filhos[2]) { // vetores
                char buffer[32];
                sprintf(buffer, "%d", no->filhos[2]->dado.valor);
                emitir_quads("VETOR", nome, buffer, funcao_atual);
            }

            return NULL;
        }

        else if((no->tipo == TipoDeclaracaoFunc)) { // funcoes
            funcao_atual = no->filhos[1]->dado.nome;
            emitir_quads("FUNCAO", no->filhos[0]->dado.nome, no->filhos[1]->dado.nome, "-");
            gerar_quads(no->filhos[2]); // parametros
            gerar_quads(no->filhos[3]); // escopo
            return NULL;
        }

        else if(no->tipo == TipoExpressaoSimples) { // expressao simples
            if(no->filhos[1] == NULL) return gerar_quads(no->filhos[0]);

            char* op = no->filhos[1]->dado.nome;
            char* arg1 = gerar_quads(no->filhos[0]);
            char* arg2 = gerar_quads(no->filhos[2]);
            char* temp = novoTemp();
            emitir_quads(op, arg1, arg2, temp);
            return temp;
        }

        else if(no->tipo == TipoExpressao) { // expressao 
            if(no->filhos[1] == NULL) return gerar_quads(no->filhos[0]);

            char* arg1 = gerar_quads(no->filhos[2]);
            char* var = no->filhos[0]->filhos[0]->dado.nome;
            emitir_quads("=", arg1, "-", var);
            return var;
        }

        else if(no->tipo == TipoExpressaoSoma) { // expressaoSoma
            if(no->filhos[1] == NULL) return gerar_quads(no->filhos[0]);

            char* op = no->filhos[1]->dado.nome;
            char* arg1 = gerar_quads(no->filhos[0]);
            char* arg2 = gerar_quads(no->filhos[2]);
            char* temp = novoTemp();
            emitir_quads(op, arg1, arg2, temp);
            return temp;
        }

        else if(no->tipo == TipoTermo) { // termo
            if(no->filhos[1] == NULL) return gerar_quads(no->filhos[0]);

            char* op = no->filhos[1]->dado.nome;
            char* arg1 = gerar_quads(no->filhos[0]);
            char* arg2 = gerar_quads(no->filhos[2]);
            char* temp = novoTemp();
            emitir_quads(op, arg1, arg2, temp);
            return temp;
        }

        else if(no->tipo == TipoFator) { // fator
            return gerar_quads(no->filhos[0]);
        }

        else if(no->tipo == TipoVar) { // variavel
            if(no->filhos[1] == NULL) // inteiro
                return no->filhos[0]->dado.nome;
            
            char* indice = gerar_quads(no->filhos[1]);
            char* nome = no->filhos[0]->dado.nome;

            char* var = malloc(strlen(nome) + strlen(indice) + 3);
            sprintf(var, "%s[%s]", nome, indice);

            return var;
        }

        else if(no->tipo == TipoNum){ // numero
            char* buffer = malloc(sizeof(char)*64);
            sprintf(buffer, "%d", no->dado.valor);
            return buffer;
        }

        else if(no->tipo == TipoID) { //id
            return no->dado.nome;
        }

        else if(no->tipo == TipoListaArgumentos) {
            return gerar_quads(no->filhos[0]);
        }

        else if(no->tipo == TipoChamadaFuncao) {
            int args_cont = 0;
            if(no->filhos[1]) { // se houver argumentos (pode ser NULL)
                AST *args = no->filhos[1]->filhos[0]; // pega a lista de argumentos
                while(args) {
                    char *arg = gerar_quads(args->filhos[0]); // gera cada argumento
                    emitir_quads("ARG", arg, "-", "-");
                    args_cont++;
                    args = args->filhos[1]; // próximo argumento da lista
                }
            }

            char *tmp = novoTemp();
            char* contador = malloc(sizeof(char)*64);
            sprintf(contador, "%d", args_cont);

            emitir_quads("CALL", no->filhos[0]->dado.nome, contador, tmp);
            return tmp;
        }

        else if((no->tipo == TipoDeclaracaoSelecao)) { // if, else
            char *cond = gerar_quads(no->filhos[0]);

            char *L_else = novoLabel();
            char *L_end  = novoLabel();
            
            emitir_quads("IF_FALSE", cond, "-", L_else);
            gerar_quads(no->filhos[1]); // then
    
            if(no->filhos[3]) { // else
                emitir_quads("GOTO", "-", "-", L_end);
                emitir_quads("LABEL", "-", "-", L_else);
                gerar_quads(no->filhos[3]); // else
                emitir_quads("LABEL", "-", "-", L_end);
            } else {
                emitir_quads("LABEL", "-", "-", L_else);
            }
            return NULL;
        }

        else if((no->tipo == TipoDeclaracaoIteracao)) { //while
            char *L_ini = novoLabel();
            char *L_end = novoLabel();

            emitir_quads("LABEL", "-", "-", L_ini);

            char *cond = gerar_quads(no->filhos[0]);
            emitir_quads("IF_FALSE", cond, "-", L_end);

            gerar_quads(no->filhos[1]);

            emitir_quads("GOTO", "-", "-", L_ini);
            emitir_quads("LABEL", "-", "-", L_end);

            return NULL;
        }

        else if(no->tipo == TipoParametros) {
            gerar_quads(no->filhos[0]);
            return NULL;
        }

        else if(no->tipo == TipoListaParametros) {
            gerar_quads(no->filhos[0]);
            gerar_quads(no->filhos[1]);
            return NULL;
        }

        else if(no->tipo == TipoParametro) {
            char *tipo = no->filhos[0]->dado.nome;
            char *nome = no->filhos[1]->dado.nome;

            emitir_quads("PARAM", tipo, nome, funcao_atual);
            if(no->filhos[2]) {
                emitir_quads("VETOR", nome, "-", funcao_atual);
            }

            return NULL;
        }

        else if(no->tipo == TipoDeclaracaoRetorno) {
            if(no->filhos[0]) {
                char *val = gerar_quads(no->filhos[0]);
                emitir_quads("RETURN", val, "-", "-");
            } else {
                emitir_quads("RETURN", "-", "-", "-");
            }
            return NULL;
        }

        else if(no->tipo == TipoEscopo || no->tipo == TipoListaEscopo || no->tipo == TipoDeclaracaoLocais) {
            gerar_quads(no->filhos[0]);
            gerar_quads(no->filhos[1]);
            return NULL;
        }

        else if (no->tipo == TipoCorpo) {
            gerar_quads(no->filhos[0]);
            return NULL;
        }

        for(int i=0;i<4 && no->filhos[i] != NULL;i++) 
            gerar_quads(no->filhos[i]);
        
        return NULL;
    }

    void print_quads(FILE *out){
        for(int i=0;i<quads_cont;i++){
            Quadrupla *q = &quads[i];
            fprintf(out, "%3d: (%s, %s, %s, %s)\n",
                    i,
                    q->operacao ? q->operacao : "-",
                    q->argumento1 ? q->argumento1 : "-",
                    q->argumento2 ? q->argumento2 : "-",
                    q->resultado  ? q->resultado  : "-");
        }
    }
    /* geração de código intermediário */
    int temp_count = 0;
    int label_count = 0;
    typedef enum { IR_ADD, IR_MUL, IR_SUB, IR_DIV, IR_ASSIGN, IR_LT, IR_GT, IR_LE, IR_GE, IR_EQ, IR_NEQ, IR_IF, IR_GOTO, IR_LABEL } IROp;

    /* ================== TABELA DE SÍMBOLOS COM ESCOPO ================== */

    // Categoria do símbolo -> variável ou função
    typedef enum { Variavel, Funcao } CategoriaSimbolo;
    // Tipo do símbolo -> void ou int
    typedef enum { TipoVoid, TipoInt } TipoSimbolo;
    // Tipo da variável -> inteiro ou vetor
    typedef enum { TipoInteiro, TipoVetor } TipoVariavel;

    // Nó da tabela de símbolos
    typedef struct Simbolo {
        char *nome;
        CategoriaSimbolo categoria;
        struct Simbolo *prox;
        TipoSimbolo tipoSimbolo;

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
            char *categoria = (s->categoria == Variavel) ? "variavel" : "funcao";
            char *tipoSimbolo = (s->tipoSimbolo == TipoInt) ? "int" : "void";
            char *tipoVariavel = (s->categoria == Variavel) ? (s->tipo == TipoInteiro ? "//inteiro" : "//vetor") : "";
            printf("\t-> %s\t\t[%s//%s%s]\n", s->nome, categoria, tipoSimbolo, tipoVariavel);
            
            Simbolo *tmp = s;
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

    Simbolo* buscarSimboloEscopoAtual(const char *nome, CategoriaSimbolo categoria, int verificarTipos) {
        if (!topo_escopo) return NULL;
        Simbolo *s = topo_escopo->simbolos;
        while (s) {
            if (strcmp(s->nome, nome) == 0) {
                if (verificarTipos == 1 && s->categoria != categoria) {
                    s = s->prox;
                    continue;
                }
                return s;
            }
            s = s->prox;
        }
        return NULL;
    }

    Simbolo* buscarSimboloTodosEscopos(const char *nome, CategoriaSimbolo categoria, int verificarTipos) {
        Escopo *e = topo_escopo;
        while (e) {
            Simbolo *s = e->simbolos;
            while (s) {
                if (strcmp(s->nome, nome) == 0) {
                    if (verificarTipos == 1 && s->categoria != categoria) {
                        s = s->prox;
                        continue;
                    }
                    return s;
                }
                s = s->prox;
            }
            e = e->prox;
        }
        return NULL;
    }

    void declararSimbolo(const char *nome, CategoriaSimbolo categoria, TipoSimbolo tipoSimbolo, TipoVariavel tipo, int tamanhoVetor) {
        if (!topo_escopo) {
            fprintf(stderr, "ERRO INTERNO: nenhum escopo ativo ao declarar '%s'.\n", nome);
            return;
        }
        if (buscarSimboloEscopoAtual(nome, categoria, 1) != NULL) {
            // Erro de simbolo duplicada no escopo
            fprintf(stderr, "ERRO SEMANTICO: identificador \"%s\" em uso - LINHA: %d\n", nome, linha_atual);
            return;
        }
        Simbolo *s = (Simbolo*) malloc(sizeof(Simbolo));
        s->nome = strdup(nome);
        s->categoria = categoria;
        s->tipoSimbolo = tipoSimbolo;
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
        Simbolo *s = buscarSimboloTodosEscopos(nome, Variavel, 1);
        if (!s) {
            // Erro de variavel nao declarada
            fprintf(stderr, "ERRO SEMANTICO: variavel \"%s\" nao declarada - LINHA: %d\n", nome, linha_atual);
            return;
        }

        if (s->categoria != Variavel) {
            // Erro de tentativa de atribuição a algo que não é variável
            fprintf(stderr, "ERRO SEMANTICO: identificador \"%s\" nao eh variavel - LINHA: %d\n", nome, linha_atual);
            return;
        }

        // Se é vetor...
        if (s->tipo == TipoVetor) {
            if (indiceVetor >= s->tamanho || indiceVetor < 0) {
                // Erro de tentativa de acesso do vetor em campo não existente
                fprintf(stderr, "ERRO SEMANTICO: variavel \"%s\", índice de acesso fora do intervalo - LINHA: %d\n", nome, linha_atual);
                return;
            }
            s->valor.vetor[indiceVetor] = valorAtribuido;
            return;
        }

        // Se é inteiro simples...
        s->valor.inteiro = valorAtribuido;
    }

    int buscarValorDeVariavel(const char *nome, int indiceVetor) {
        Simbolo *s = buscarSimboloTodosEscopos(nome, Variavel, 1);
        if (!s) {
            // Erro de variavel nao declarada
            fprintf(stderr, "ERRO SEMANTICO: variavel \"%s\" nao declarada - LINHA: %d\n", nome, linha_atual);
            return 0;
        }

        if (s->categoria != Variavel) {
            // Erro de tentativa de acesso a algo que não é variável
            fprintf(stderr, "ERRO SEMANTICO: identificador \"%s\" nao eh variavel - LINHA: %d\n", nome, linha_atual);
            return 0;
        }

        // Se é vetor...
        if (s->tipo == TipoVetor) {
            if (indiceVetor >= s->tamanho) {
                // Erro de tentativa de acesso do vetor em campo não existente
                fprintf(stderr, "ERRO SEMANTICO: variavel \"%s\", índice de acesso fora do intervalo - LINHA: %d\n", nome, linha_atual);
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

%type <no> programa listaDeclaracoes declaracao declaracaoVariaveis tipoEspecificador
%type <no> declaracaoFuncao parametros listaParametros parametro escopo declaracoesLocais
%type <no> listaEscopo corpo declaracaoExpressao declaracaoSelecao declaracaoIteracao declaracaoRetorno expressao variavel expressaoSimples relacional expressaoSoma soma termo mult fator chamadaFuncao argumentos listaArgumentos

%start programa

%%
    /* gramatica */
    programa: listaDeclaracoes  {
                                    $$ = criarNo(TipoPrograma);
                                    $$->filhos[0] = $1;
                                    raizAST = $$;
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
                                                                        if (strcmp($1->dado.nome, "void") == 0) {
                                                                            // Erro: tipo void não pode ser usado em variáveis
                                                                            fprintf(stderr, "ERRO SEMANTICO: tipo \"void\" nao permitido para variaveis - LINHA: %d\n", linha_atual);
                                                                        }

                                                                        declararSimbolo($2, Variavel, TipoInt, TipoInteiro, 1);

                                                                        $$ = criarNo(TipoDeclaracaoVars);
                                                                        $$->filhos[0] = $1;

                                                                        AST* var = criarNo(TipoID);
                                                                        var->dado.nome = strdup($2);

                                                                        $$->filhos[1] = var;

                                                                        free($2);
                                                                    }
                            | tipoEspecificador T_ID T_ACOLCHETE T_NUM T_FCOLCHETE T_PONTOEVIRGULA  {
                                                                                                        if (strcmp($1->dado.nome, "void") == 0) {
                                                                                                            // Erro: tipo void não pode ser usado em variáveis
                                                                                                            fprintf(stderr, "ERRO SEMANTICO: tipo \"void\" nao permitido para variaveis - LINHA: %d\n", linha_atual);
                                                                                                        }  

                                                                                                        declararSimbolo($2, Variavel, TipoInt, TipoVetor, $4);

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
                                                                                    TipoSimbolo tipoSimbolo = strcmp($1->dado.nome, "int") == 0 ? TipoInt : TipoVoid;

                                                                                    declararSimbolo($2, Funcao, tipoSimbolo, TipoInteiro, 0); // TipoVariavel e tamanhoVetor não são relevantes para funções

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
                                                                        AST* vetor = criarNo(TipoID);
                                                                        vetor->dado.nome = malloc(strlen("[]")+1);
                                                                        strcpy(vetor->dado.nome, "[]");
                                                                        $$->filhos[2] = vetor;
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
                            Simbolo* s = buscarSimboloTodosEscopos($1, Variavel, 1);
                            if (!s) {
                                fprintf(stderr, "ERRO SEMANTICO: variavel \"%s\" nao declarada - LINHA: %d\n", $1, linha_atual);
                            }
                            $$ = criarNo(TipoVar);
                            AST* no = criarNo(TipoID);
                            no->dado.nome = strdup($1);
                            $$->filhos[0] = no;
                            free($1);
                        }
                | T_ID T_ACOLCHETE expressao T_FCOLCHETE    {
                                                                Simbolo* s = buscarSimboloTodosEscopos($1, Variavel, 1);
                                                                if (!s) {
                                                                    fprintf(stderr, "ERRO SEMANTICO: variavel \"%s\" nao declarada - LINHA: %d\n", $1, linha_atual);
                                                                }
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
    for(int i=0; i<4; i++)
        no->filhos[i] = NULL;
    return no;
}

const char* nomeTipoNo(AST* no) {
    static char buffer[50];
    switch (no->tipo) {
        case TipoPrograma:              return "programa";
        case TipoListaDeclaracoes:      return "listaDeclaracoes";
        case TipoDeclaracao:            return "declaracao";
        case TipoDeclaracaoVars:        return "declaracaoVariaveis";
        case TipoEspecifico:            return no->dado.nome;
        case TipoDeclaracaoFunc:        return "declaracaoFuncao";
        case TipoID:                    return no->dado.nome;
        case TipoParametros:            return "parametros";
        case TipoListaParametros:       return "listaParametros";
        case TipoParametro:             return "parametro";
        case TipoEscopo:                return "escopo";
        case TipoDeclaracaoLocais:      return "declaracoesLocais";
        case TipoListaEscopo:           return "listaEscopo";
        case TipoDeclaracaoExpressao:   return "declaracaoExpressao";
        case TipoDeclaracaoSelecao:     return "if";
        case TipoDeclaracaoIteracao:    return "while";
        case TipoDeclaracaoRetorno:     return "return";
        case TipoExpressao:             return "expressao";
        case TipoVar:                   return "variavel";
        case TipoExpressaoSimples:      return "expressaoSimples";
        case TipoRelacional:            return no->dado.nome;
        case TipoExpressaoSoma:         return "expressaoSoma";
        case TipoSoma:                  return no->dado.nome;
        case TipoTermo:                 return "termo";
        case TipoMult:                  return no->dado.nome;
        case TipoFator:                 return "fator";
        case TipoChamadaFuncao:         return "chamadaFuncao";
        case TipoArgumentos:            return "argumentos";
        case TipoListaArgumentos:       return "listaArgumentos";
        case TipoCorpo:                 return "corpo";
        case TipoNum:                   sprintf(buffer, "%d", no->dado.valor); return buffer;
        default:                        return "???";
    }
}

void imprimirNoDOT(AST* no, FILE* file) {
    if (!no) return;

    char nomeDoNo[30];

    strcpy(nomeDoNo, nomeTipoNo(no));

    for(int i=0; i<4; i++) {
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
}

/* GERACAO DE CODIGO INTERMEDIARIO */
char* criaVariavelTemporaria() {
    char *temp = (char*)malloc(16);
    if (!temp) return NULL;
    sprintf(temp, "t%d", temp_count++);
    return temp;
}

char* criaLabel() {
    char *label = (char*)malloc(16);
    if (!label) return NULL;
    sprintf(label, "L%d", label_count++);
    return label;
}

char* op_to_str(IROp op) {
    switch (op) {
        case IR_ADD:    return "+";
        case IR_MUL:    return "*";
        case IR_SUB:    return "-";
        case IR_DIV:    return "/";
        case IR_ASSIGN: return "=";
        case IR_LT:     return "<";
        case IR_GT:     return ">";
        case IR_LE:     return "<=";
        case IR_GE:     return ">=";
        case IR_EQ:     return "==";
        case IR_NEQ:    return "!=";
        default:        return "???";
    }
}

void emit(IROp op, char* arg1, char* arg2, char* result, FILE *file) {
    if (op == IR_IF) {
        fprintf(file, "ifFalse %s goto %s\n", arg1, arg2);
        return;
    }

    if (op == IR_GOTO) {
        fprintf(file, "goto %s\n", arg1 ? arg1 : "origem");
        return;
    }

    char *op_str = (op == IR_ASSIGN) ? "" : op_to_str(op);
    fprintf(file, "%s = ", result);
    fprintf(file, "%s ", arg1);
    fprintf(file, "%s ", op_str);
    fprintf(file, "%s\n", arg2 ? arg2 : "");
}

char* gerarExpressao(AST* no, FILE *file) {
    if (!no) return NULL;

    switch (no->tipo) {

        case TipoNum: {
            char *buffer = (char*)malloc(50);
            sprintf(buffer, "%d", no->dado.valor);
            return buffer;
        }

        case TipoID:
        case TipoVar: {
            return strdup(no->dado.nome);
        }

        case TipoFator: {
            char* fator = gerarExpressao(no->filhos[0], file); 
            return fator;
        }

        case TipoTermo: {
            char *e1 = gerarExpressao(no->filhos[0], file);
            char *e2 = gerarExpressao(no->filhos[2], file);
            char *t = criaVariavelTemporaria();
            if (no->filhos[1]->tipo == TipoMult && strcmp(no->filhos[1]->dado.nome, "*") == 0) {
                emit(IR_MUL, e1, e2, t, file);
            } else if (no->filhos[1]->tipo == TipoMult && strcmp(no->filhos[1]->dado.nome, "/") == 0) {
                emit(IR_DIV, e1, e2, t, file);
            }
            return t;
        }

        case TipoExpressaoSoma: {
            char *e1 = gerarExpressao(no->filhos[0], file);
            char *e2 = gerarExpressao(no->filhos[2], file);
            char *t = criaVariavelTemporaria();
            if (no->filhos[1]->tipo == TipoSoma && strcmp(no->filhos[1]->dado.nome, "+") == 0) {
                emit(IR_ADD, e1, e2, t, file);
            } else if (no->filhos[1]->tipo == TipoMult && strcmp(no->filhos[1]->dado.nome, "-") == 0){
                emit(IR_SUB, e1, e2, t, file);
            }
            return t;
        }

        case TipoExpressao: {
            if (no->filhos[2]) {
                // Assignment: var = expr
                char* lhs = gerarExpressao(no->filhos[0], file);
                char* rhs = gerarExpressao(no->filhos[2], file);
                emit(IR_ASSIGN, rhs, NULL, lhs, file);
                free(rhs);
                return lhs;
            } else {
                // Simple expression (e.g., function call)
                return gerarExpressao(no->filhos[0], file);
            }
        }

        case TipoExpressaoSimples: {
            if (no->filhos[1]) {
                char *e1 = gerarExpressao(no->filhos[0], file);
                char *e2 = gerarExpressao(no->filhos[2], file);
                char *t = criaVariavelTemporaria();
                if (no->filhos[1]->tipo == TipoRelacional && strcmp(no->filhos[1]->dado.nome, "<") == 0) {
                    emit(IR_LT, e1, e2, t, file);
                } else if (no->filhos[1]->tipo == TipoRelacional && strcmp(no->filhos[1]->dado.nome, ">") == 0) {
                    emit(IR_GT, e1, e2, t, file);
                } else if (no->filhos[1]->tipo == TipoRelacional && strcmp(no->filhos[1]->dado.nome, "<=") == 0) {
                    emit(IR_LE, e1, e2, t, file);
                } else if (no->filhos[1]->tipo == TipoRelacional && strcmp(no->filhos[1]->dado.nome, ">=") == 0) {
                    emit(IR_GE, e1, e2, t, file);
                } else if (no->filhos[1]->tipo == TipoRelacional && strcmp(no->filhos[1]->dado.nome, "==") == 0) {
                    emit(IR_EQ, e1, e2, t, file);
                } else if (no->filhos[1]->tipo == TipoRelacional && strcmp(no->filhos[1]->dado.nome, "!=") == 0) {
                    emit(IR_NEQ, e1, e2, t, file);
                }
                return t;
            } else {
                return gerarExpressao(no->filhos[0], file);
            }
        }

        default:
            return NULL;
    }
}

void gerarDeclaracao(AST* no, FILE *file) {
    if (!no) return;

    switch (no->tipo) {

        case TipoExpressao: {
            gerarExpressao(no, file);
            break;
        }

        case TipoDeclaracaoIteracao: {
            char* inicioLabel = criaLabel();
            char* fimLabel = criaLabel();

            fprintf(file, "%s:\n", inicioLabel);
            char* cond = gerarExpressao(no->filhos[0], file);
            emit(IR_IF, cond, fimLabel, NULL, file);
            gerarDeclaracao(no->filhos[1], file);
            emit(IR_GOTO, inicioLabel, NULL, NULL, file);
            fprintf(file, "%s:\n", fimLabel);

            free(inicioLabel);
            free(fimLabel);
            free(cond);
            break;
        }

        case TipoDeclaracaoSelecao: {
            char* elseLabel = (no->filhos[2] == NULL) ? NULL : criaLabel();
            char* endLabel = criaLabel();

            char* cond = gerarExpressao(no->filhos[0], file);
            emit(IR_IF, cond, (no->filhos[2] == NULL) ? endLabel : elseLabel, NULL, file);
            free(cond);
            gerarDeclaracao(no->filhos[1], file);

            if (no->filhos[2]) {
                fprintf(file, "%s:\n", elseLabel);
                gerarDeclaracao(no->filhos[3], file);
                free(elseLabel);
            }

            fprintf(file, "%s:\n", endLabel);

            free(endLabel);
            break;
        }

        case TipoDeclaracaoFunc: {
            char* funcLabel = (char*)malloc(32);
            if (!funcLabel) return;
            sprintf(funcLabel, no->filhos[1]->dado.nome);
            char* endFuncLabel = criaLabel();

            fprintf(file, "%s:\n", funcLabel);
            gerarDeclaracao(no->filhos[3], file);
            emit(IR_GOTO, NULL, NULL, NULL, file);

            free(funcLabel);
            free(endFuncLabel);
            break;
        }

        default:
            for (int i = 0; i < 5; i++) {
                if (no->filhos[i]) {
                    gerarDeclaracao(no->filhos[i], file);
                }
            }
    }
}

void gerarCodigoIntermediario(AST* raiz) {
    if (!raiz) return;

    FILE *file;
    file = fopen("build/codigoIntermediario.txt", "w");
    if (file==NULL) {
        printf("Erro ao abrir arquivo para gerar codigo intermediario\n");
        return;
    }

    gerarDeclaracao(raiz, file);

    fclose(file);
}

AST* enxugaAST(AST* no) {
    int i;

    if (!no) return NULL;

    if (no->filhos[0] != NULL && no->filhos[1] == NULL && no->filhos[2] == NULL && no->filhos[3] == NULL) {
        AST* temp = no;
        no = enxugaAST(no->filhos[0]);
        free(temp);
    } else {
        for (i = 0; i < 4; i++) {
            no->filhos[i] = enxugaAST(no->filhos[i]);
        }
    }

    return no;
}

void liberaAST(AST* no) {
    if (!no) return;
    int i;
    for(i=0;i<4;i++)
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

    /* Geração de quádruplas a partir da AST */
    gerar_quads(raizAST);
    printf("\nQuadruplas geradas:\n");
    print_quads(stdout);
    printf("---------------------\n> ");
    limpa_quads();

    raizAST = enxugaAST(raizAST);

    gerarDOT(raizAST);

    gerarCodigoIntermediario(raizAST);

    liberaAST(raizAST);

    fclose(yyin);

    return 0;
}

void yyerror(const char* msg) {
	fprintf(stderr, "ERRO SINTATICO: \"%s\" - LINHA: %d\n", msg, linha_atual);
	exit(1);
}