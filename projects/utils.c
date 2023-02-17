// Estrutura da Tabela de Simbolos
#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#define TAM_TAB 100
#define MAX_PAR 20
enum 
{
    INT, 
    LOG
};

struct elemTabSimbolos {
    char id[100];           // identificador
    int end;                // endereço (global) ou deslocalmento (local)
    int tip;                // INT, LOG
    char cat;               // categoria: 'f' = FUN, 'p' = PAR, 'v' = VAR (função, parâmetro ou variável)
    char esc;               // escopo: 'g' = GLOBAL, 'l' = LOCAL 
    int rot;                // rótulo (específico para função) (desviar a execução quando a rotina for chamada)
    int npa;                // número de parâmetros (para função)
    int par[MAX_PAR];       // lista com os tipos dos parâmetros (para função)
} tabSimb[TAM_TAB], elemTab;

int posTab = 0;

// int vetorVerifica[MAX_PAR];

// void insereVetorVerifica(int contaPar, int tipo) {
//     for (int i = 0; i < contaPar; i++) {
//         vetorVerifica[i] = tipo;
//     }

// }

void maiuscula (char *s) {
    for (int i = 0; s[i]; i++)
        s[i] = toupper(s[i]);
    
}

int buscaSimbolo (char *id) {
    int i;
    // maiuscula(id);        // para fazer diferenciação entre variáveis maiúsculas e minúsculas
    for (i = posTab - 1; strcmp(tabSimb[i].id, id) && i >= 0; i--)
        ;
    if (i == -1) {
        char msg[200];
        sprintf(msg, "Identificador [%s] não encontrado!", id);
        yyerror(msg);       // escreve a linha em que o erro foi encontrado e uma mensagem
    }
    return i;
}

void insereSimbolo (struct elemTabSimbolos elem) {
    int i;
    // maiuscula(elem.id);       // para fazer diferenciação entre variáveis maiúsculas e minúsculas
    if (posTab == TAM_TAB)
        yyerror("Tabela de Simbolos Cheia!");
    for (i = posTab - 1; strcmp(tabSimb[i].id, elem.id) && i >= 0; i--)     
        ;
    if (i != -1 && tabSimb[i].esc == elem.esc) {     // Se o ID das variáveis forem iguais e estiverem no mesmo escopo, então há identificador duplicado!
        char msg[200];
        sprintf(msg, "Identificador [%s] duplicado!", elem.id);
        yyerror(msg);
    }
    tabSimb[posTab++] = elem;

}

/* Função que exibe a lista de parâmetros */ 
void mostraListaPAR(int contaPar, int posicao) {

    printf("[ ");
    for (int i = 0; i < contaPar; i++) {
        printf("%s", tabSimb[posicao].par[i] == INT? "INT " : "LOG ");    // OBS: Tbm funciona com os valores: 0 para INT e 1 para LOG
    }
    printf("]"); 
}

void mostraTabela() {
    puts("\t\t\t\tTabela de Simbolos");     
    puts("\t\t-------------------------------------------------");
    printf("%20s  | %2s | %2s | %2s | %2s | %2s | %2s | %s \n", "ID", "END", "TIP", "CAT", "ESC", "ROT", "NPA", "PAR");    // acrescentar mais colunas
    printf("\t\t");
    for (int i = 0; i < 49; i++)
        printf("-");
    for (int i = 0; i < posTab; i++){
        printf("\n%20s  | %3d | %3s | %3c | %3c | %3c | %3c | ", tabSimb[i].id, tabSimb[i].end, tabSimb[i].tip == INT? "INT" : "LOG", tabSimb[i].cat, tabSimb[i].esc, tabSimb[i].rot > 0? (tabSimb[i].rot + '0') : ('-'), tabSimb[i].cat == 'F'? (tabSimb[i].npa + '0') : '-');
        tabSimb[i].cat == 'F'? mostraListaPAR(tabSimb[i].npa, i) : printf(" - ");
    }
    printf("\n");
    printf("\n");
}

/* Estrutura da Pilha Semântica usada para endereços, variáveis, rótulos */
#define TAM_PIL 100
struct {
    int valor;
    char tipo;  //'r' = rótulo, 'n' = numero de variaveis, 't' = tipo, 'p' = posição na tabela de simbolos
} pilha [TAM_PIL];
int topo = -1;

void empilha (int valor, char tipo) {
    if (topo == TAM_PIL)
        yyerror ("Pilha semântica cheia!");
    pilha[++topo].valor = valor;
    pilha[topo].tipo = tipo;
}

int desempilha(char tipo) {
    if (topo == -1) 
        yyerror("Pilha semântica vazia!");
    if (pilha[topo].tipo != tipo) {
        char msg[100];
        sprintf(msg,"Desempilha esperado[%c], encontrado[%c]", tipo, pilha[topo].tipo);
        yyerror(msg);
    }
    return pilha[topo--].valor;
}

void testaTipo(int tipo1, int tipo2, int ret) {
    int t1 = desempilha('t');
    int t2 = desempilha('t');
    if (t1 != tipo1 || t2 != tipo2)
        yyerror("Incompatibilidade de tipo!");
    empilha(ret, 't');
}

void mostraPilha() {
    int i = topo;
    printf("Pilha = [");
    while (i >= 0 ){
        printf("(%d, %c)", pilha[i].valor, pilha[i].tipo);
        i--;
    }
    printf("]\n");
}

/* Procedimento para testar se é uma função e, só assim, atribuir rótulo */
void colocaRotulo (int a) {
    if (elemTab.cat == 'F')
        elemTab.rot = a;
}

/* Insere quantidade de parâmetros na função */
void insereNPA (int contaPar) {        //RETIRAR O PARAMETRO ELEM, PQ NAO FOI USADO
    int i = posTab;     
    i--;

    // printf("Qtd de ID: %d \n", i);
    // printf("Nmro par: %d\n", contaPar);

    tabSimb[i-contaPar].npa = contaPar;
} 

/* Função para inserir os parâmetros na lista de parâmetros */
void inserePAR (int tipoPar, int contaPar, int indice) {        // tipoPar recebe 0 para INT e 1 para LOG
    int i = posTab;
    i--;
    indice--;   // Indice = quantidade de parâmetros-1, pra usar a posição 0 do vetor lista de parâmetros

    tabSimb[i-contaPar].par[indice] = tipoPar;              //Verificar se não vai ser preciso somar o contaPar + contaVar (variaveis locais)
    // printf("\nInserindo o tipo %s no indice %d\n", tipoPar == INT? "INT" : "LOG", indice);
}

/* Função para mostrar o vetor de parâmetros (PARA DEPURAÇÃO) */
void mostraVetorPAR (int contaPar, int contaVar) {
    int j = posTab;
    j--;

    printf("\nVetor de parâmetros: [");
    for (int i = 0; i < contaPar+contaVar; i++)
    {
        printf(" %d ", tabSimb[j-contaPar+contaVar].par[i]);
    }
    printf("]\n");
}

/* Rotina que ajusta o endereço da função e dos parâmetros  */
void ajustaParametros(int contaPar) {
    int i = posTab;     // Posição atual da tabela

    int end = -3;       // Iniciando a posição do último parâmetro com -3
    i--;

    for (int j = 0; j < contaPar + 1; j++, i--, end--) {
        tabSimb[i].end = end;
    }
}

void removeLocais (int contaVar) {
    int i;

    // printf("A posTab eh: %d\n", posTab);
    for (i = (posTab-1); i > 0 && tabSimb[i].cat != 'F' ; i--) {
        ;
    }
    posTab = i + 1;     //Incrementar 1, porque a nova posição tem que ser um valor abaixo
    // printf("A func eh: %s\n", tabSimb[i].id);
}

int localizaFunc () {
    int i = posTab;
    i--;

    for (; i > 0 && tabSimb[i].cat != 'F'; i--){
        ;
    }
    printf("A posicao da func eh: %d\n", i);
    return i;
}

/* Acessa a pilha e conta quantos tipos existem na pilha de acordo com o tipo do parametro passado*/
int contaTipoPilha (char tipo) {
    int topoP = topo;
    int contaTipo = 0;
    printf("O topo da pilha eh: %d\n", topoP);

    for (int i = topoP; pilha[i].tipo == tipo && i > 0; i--) {
        contaTipo++;
    }
    
    printf("Existem %d tipos no topo da pilha\n", contaTipo);
    return contaTipo;
}