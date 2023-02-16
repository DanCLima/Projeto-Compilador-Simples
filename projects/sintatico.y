%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "lexico.c"
#include "utils.c"
int contaVar;       // conta o número de variáveis globais
int rotulo = 0;     // marcar lugares no código
int tipo;
int contaPar = 0;
char escopo;
%}

%token T_PROGRAMA
%token T_INICIO
%token T_FIM
%token T_LEIA
%token T_ESCREVA
%token T_SE
%token T_ENTAO
%token T_SENAO
%token T_FIMSE
%token T_ENQUANTO
%token T_FACA
%token T_FIMENQUANTO
%token T_INTEIRO
%token T_LOGICO
%token T_MAIS
%token T_MENOS
%token T_VEZES
%token T_DIV
%token T_MAIOR
%token T_MENOR
%token T_IGUAL
%token T_E 
%token T_OU 
%token T_NAO
%token T_ABRE
%token T_FECHA
%token T_ATRIBUICAO
%token T_V 
%token T_F 
%token T_IDENTIFICADOR
%token T_NUMERO

%token T_RETORNE
%token T_FUNC
%token T_FIMFUNC

%start programa
%expect 1

%left T_E T_OU
%left T_IGUAL
%left T_MAIOR T_MENOR
%left T_MAIS T_MENOS
%left T_VEZES T_DIV

%%

programa 
    : cabecalho 
        { 
            contaVar = 0;
            escopo = 'G'; 
        }
    variaveis 
        {
            //mostraTabela();
            empilha(contaVar, 'n'); 
            if (contaVar) 
                fprintf(yyout,"\tAMEM\t%d\n", contaVar); 
        }

    rotinas
    T_INICIO lista_comandos T_FIM
        { 
            int conta = desempilha('n');
            if (conta)
                fprintf(yyout, "\tDMEM\t%d\n", conta); 
            fprintf(yyout, "\tFIMP\n");
        }
    ;

cabecalho
    : T_PROGRAMA T_IDENTIFICADOR
        { fprintf(yyout,"\tINPP\n"); }
    ;

variaveis
    : /* vazio */
    | declaracao_variaveis
    ;

declaracao_variaveis
    : tipo lista_variaveis declaracao_variaveis
    | tipo lista_variaveis
    ;

//REGRA "tipo"
tipo        
    : T_LOGICO
        { tipo = LOG; }     // Variável "tipo"
    | T_INTEIRO
        { tipo = INT; }
    ;

lista_variaveis
    : lista_variaveis T_IDENTIFICADOR 
        {  
            strcpy(elemTab.id, atomo);
            elemTab.rot = -1;   //Tratando o rótulo em variáveis
            elemTab.end = contaVar;
            elemTab.cat = 'V';
            elemTab.tip = tipo;
            elemTab.esc = escopo; // FUNC -> LOCAL, FIMFUNC -> GLOBAL
            insereSimbolo(elemTab); 
            contaVar++;     
        }
    | T_IDENTIFICADOR
        { 
            strcpy(elemTab.id, atomo);
            elemTab.rot = -1;
            elemTab.cat = 'V';
            elemTab.end = contaVar;
            elemTab.tip = tipo;
            elemTab.esc = escopo; 
            insereSimbolo(elemTab);
            contaVar++;            
        }
    ;

rotinas
    : /* Não tem funções */
    | 
        { fprintf(yyout, "\tDSVS\tL0\n"); }
    funcoes 
        { fprintf(yyout, "L0\tNADA\n"); }
    ;

// ------------------------------------------------------
// Regras para as funções (slide extensões do compilador)
// ------------------------------------------------------
funcoes
    : funcao
    | funcao funcoes 
    ;

funcao 
    : T_FUNC 
    
    tipo T_IDENTIFICADOR 
        {   
            strcpy (elemTab.id, atomo);
            elemTab.tip = tipo;
            elemTab.cat = 'F';           
            elemTab.esc = escopo;
            elemTab.rot = ++rotulo;
            insereSimbolo(elemTab);
            fprintf(yyout, "L%d \tENSP \n", rotulo);
            contaVar = 0;         // Quando entrar na função, a quantidade de variáveis precisa ser zerada, para a contagem das variáveis locais
            escopo = 'L';         // Como a função deve ter escopo global, deve-se mudar o escopo para local somente depois de atribuir o escopo da função
            //printf("\nO rótulo é: %d\n", rotulo);
        }
    
    T_ABRE parametros T_FECHA
        {
            insereNPA(contaPar);       // Inserindo a quantidade de parâmetros da função
            
            /* Desempilhando os tipos dos parâmetros para inseri-los na lista de parâmetros */
            for (int i = contaPar; i > 0; i--) {
                // printf("tipo eh: %d\n", desempilha('t')/* == INT? "INT" : "LOG"*/);
                inserePAR(desempilha('t'), contaPar, i);     // Desempilhando os valores 0 para INT e 1 para LOG
            }   

            // mostraVetorPAR(contaPar, contaVar);       // Teste para ver o vetor de parâmetros  

            /* Ajustando o endereço da função e dos seus parâmetros */
            ajustaParametros(contaPar);
        }
      variaveis 
        {
            //mostraTabela();
            if (contaVar) 
                fprintf(yyout,"\tAMEM\t%d\n", contaVar); 
        }
      
      T_INICIO lista_comandos T_FIMFUNC
        {
            // mostraPilha();
            escopo = 'G';

            // printf(" Variaveis locais que serao removidas: %d\n", contaVar);
            // Remover variaveis locais
            removeLocais(contaVar);

            // printf(" OLHA AQUI MLR: %d\n", contaPar);
            // for (int i = contaVar + contaPar; i > 0; i--)  // TESTE: desempilhando os tipo das variaveis
            //     desempilha('t'); 

            // mostraTabela();
            // mostraPilha();
            // printf("Qtd variaveis locais: %d\n", contaVar);
        }
    ;

parametros
    : /* vazio */
    | parametro parametros      // cadastrar na tabela de símbolos depois de chegar no último parâmetro 
    ;

parametro 
    : tipo 
        {
            /* Vamos empilhar o(s) tipo(s) do(s) parâmetro(s) para inseri-lo(s) na lista de parâmetros */
            // printf("\nO tipo eh: %s\n", tipo == INT? "INT" : "LOG");
            empilha(tipo, 't');     
        }

    T_IDENTIFICADOR
        {
//-------------------------------------
            strcpy(elemTab.id, atomo);
            elemTab.cat = 'P';
            elemTab.end = contaVar;
            elemTab.tip = tipo;
            elemTab.esc = escopo; 
            elemTab.rot = -1;       // Tratando os rótulos dos parâmetros
            insereSimbolo(elemTab);
            contaPar++; 
            //printf("\ncontaPar = %d\n", contaPar);    // Contando quantos parâmetros
            //printf("\nNao pode ter categoria: %d\n", elemTab.rot);
//----------------------------------------
            //cadastrar parametro
        }
    ;

lista_comandos
    : /* vazio */
    | comando lista_comandos
    ;

comando 
    : entrada_saida
    | repeticao
    | selecao
    | atribuicao 
    | retorno
    ;

// ---------------------------------------------------------------------------
/* só poderá existir no escopo local (dentro da função) DMEM, ARZL, RTSP */
retorno 
    : T_RETORNE 
        {
            // mostraPilha();
            // printf("ESCOPO AQUI: %c\n", escopo);
            if (escopo != 'L')                      //REALIZAR TESTE PARA VERIFICAR SE DEU CERTO!!!
                yyerror("Uso inadequado do retorne!");
            
        }
    expressao       //só pode ser usado num contexto local (utilizar o flag que diferencia se é global ou local) 
        {
            // mostraPilha();
            //verificar se está no escopo local 
            //verificar se o tipo da expressão é compatível
            int tip = desempilha('t');
            
            // mostraPilha();
            if (tip != tabSimb[posTab - ( 1 + contaPar + contaVar)].tip)
                yyerror ("Incompatibilidade de tipo");
            
            //ARZL armazenar no endereço que foi deixado pra função (AMEM 1)
            fprintf(yyout,"\tARZL\t%d\n", tabSimb[posTab - ( 1 + contaPar + contaVar)].end);

            // DMEM numero de variaveis locais
            if (contaVar)
                fprintf(yyout,"\tDMEM\t%d\n", contaVar);

            // RTSP numero de parametros
            fprintf(yyout,"\tRTSP\t%d\n", tabSimb[posTab - ( 1 + contaPar + contaVar)].npa);
        }
    ;

entrada_saida
    : leitura
    | escrita
    ;

leitura 
    : T_LEIA T_IDENTIFICADOR
        { 
            int pos = buscaSimbolo(atomo);  
            if (tabSimb[pos].esc == 'G'){
                fprintf(yyout,"\tLEIA\n\tARZG\t%d\n", tabSimb[pos].end); 
            } else {
                fprintf(yyout,"\tLEIA\n\tARZL\t%d\n", tabSimb[pos].end);
            }
        }
    ;

escrita 
    : T_ESCREVA expressao
        { 
            desempilha('t');
            fprintf(yyout,"\tESCR\n"); 
        }
    ;

repeticao
    : T_ENQUANTO 
        { 
            fprintf(yyout,"L%d\tNADA\n", ++rotulo);     // L de label 
            empilha(rotulo, 'r');
        } 
    expressao T_FACA 
        { 
            int tip = desempilha('t');
            if (tip != LOG)
                yyerror ("Incompatibilidade de tipo");
            fprintf(yyout,"\tDSVF\tL%d\n", ++rotulo); 
            empilha(rotulo, 'r');
        }
    lista_comandos 
    T_FIMENQUANTO
        { 
            //mostraPilha();  //teste
            int rot1 = desempilha('r');
            int rot2 = desempilha('r');
            fprintf(yyout,"\tDSVS\tL%d\n", rot2); 
            fprintf(yyout,"L%d\tNADA\n", rot1); 
        }
    ;

selecao
    : T_SE expressao T_ENTAO 
        { 
            int tip = desempilha('t');
            if (tip != LOG)
                yyerror("Incompatibilidade de tipo!");
            fprintf(yyout,"\tDSVF\tL%d\n", ++rotulo); 
            empilha(rotulo, 'r');
        }
    lista_comandos T_SENAO
        { 
            int rot = desempilha('r');
            fprintf(yyout,"\tDSVS\tL%d\n", ++rotulo); 
            fprintf(yyout,"L%d\tNADA\n", rot); 
            empilha(rotulo, 'r');
        }
    lista_comandos T_FIMSE
        { 
            int rot = desempilha('r');
            fprintf(yyout,"L%d\tNADA\n", rot); 
        }
    ;

atribuicao
    : T_IDENTIFICADOR
        {
            int pos = buscaSimbolo(atomo);
            empilha(pos, 'p');
        }
    T_ATRIBUICAO expressao
        { 
            // puts("Isolando o erro 1");
            // mostraPilha();
            int tip = desempilha('t');
            int pos = desempilha('p');
            // puts("-------------------");

            if (tabSimb[pos].tip != tip)
                yyerror("Incompatibilidade de tipo!");
            if (tabSimb[pos].esc == 'G'){
                fprintf(yyout,"\tARZG\t%d\n", tabSimb[pos].end); 
            } else {
                fprintf(yyout,"\tARZL\t%d\n", tabSimb[pos].end);
            }
        }
    ;

expressao
    : expressao T_VEZES expressao
        { 
            testaTipo(INT, INT, INT);
            fprintf(yyout,"\tMULT\n"); 
        }
    | expressao T_DIV expressao
        { 
            testaTipo(INT, INT, INT);
            fprintf(yyout,"\tDIVI\n"); 
        }
    | expressao T_MAIS expressao
        { 
            testaTipo(INT, INT, INT);
            fprintf(yyout,"\tSOMA\n"); 
        }
    | expressao T_MENOS expressao
        { 
            testaTipo(INT, INT, INT);
            fprintf(yyout,"\tSUBT\n"); 
        }
    | expressao T_MAIOR expressao
        { 
            testaTipo(INT, INT, LOG);
            fprintf(yyout,"\tCMMA\n"); 
        }
    | expressao T_MENOR expressao
        { 
            testaTipo(INT, INT, LOG);
            fprintf(yyout,"\tCMME\n"); 
        }
    | expressao T_IGUAL expressao
        { 
            testaTipo(INT, INT, LOG);
            fprintf(yyout,"\tCMIG\n"); 
        }
    | expressao T_E expressao
        { 
            testaTipo(LOG, LOG, LOG);
            fprintf(yyout,"\tCONJ\n"); 
        }
    | expressao T_OU expressao
        { 
            testaTipo(LOG, LOG, LOG);
            fprintf(yyout,"\tDISJ\n"); 
        }
    | termo
    ;

identificador 
    : T_IDENTIFICADOR
        {
            int pos = buscaSimbolo(atomo);
            empilha(pos, 'p');
        }
    ;

// ---------------------------------------------------------------------------
// A função é chamada como um termo numa expressão
chamada 
    : // sem parênteses é uma variável
    {
        // puts("Isolando o erro 2");
        // mostraPilha();
        int pos = desempilha('p');
        // puts("-------------------");

        if (tabSimb[pos].esc == 'G')
            fprintf(yyout,"\tCRVG\t%d\n", tabSimb[pos].end); 
        else
            fprintf(yyout,"\tCRVL\t%d\n", tabSimb[pos].end);
            // printf("O ESCOPO AQUI EH: %c\n", tabSimb[pos].esc);
        empilha(tabSimb[pos].tip, 't');
    }
    | T_ABRE 
        { fprintf(yyout,"\tAMEM\t1\n"); }
      lista_argumentos  
      T_FECHA
        {
            puts("\nIsolando o erro 3");                          // TEM ALGUM ERRO AQUI
                                                                    
            for (int i = contaPar + contaVar; i > 0; i--) {     //DESEMPILHANDO OS TIPOS DOS PARÂMETROS E VARIÁVEIS
                // printf("O valor de i eh: %d\n", i);
                desempilha('t');
            }

            mostraPilha();
            int pos = desempilha('p');           // O ERRO ESTÁ AQUI
            puts("-------------------\n");

            fprintf(yyout,"\tSVCP\n"); 
            fprintf(yyout,"\tDSVS\tL%d\n", tabSimb[pos].rot);
            empilha(tabSimb[pos].tip, 't');
        }
    ;

lista_argumentos
    : /* vazio */
    | expressao lista_argumentos
    ;

termo
    : identificador chamada
    | T_NUMERO
        { 
            fprintf(yyout,"\tCRCT\t%s\n", atomo); 
            empilha(INT, 't');
        }
    | T_V
        { 
            fprintf(yyout,"\tCRCT\t1\n"); 
            empilha(LOG, 't');
        }
    | T_F
        { 
            fprintf(yyout,"\tCRCT\t0\n"); 
            empilha(LOG, 't');
        }
    | T_NAO termo
        { 
            int t = desempilha('t');
            if (t != LOG) yyerror ("Incompatibilidade de tipo!");       // Verificação se o termo é lógico
            fprintf(yyout,"\tNEGA\n"); 
            empilha(LOG, 't');
        }
    | T_ABRE expressao T_FECHA
    ;

%%

int main (int argc, char *argv[]) {
    char *p, nameIn[100], nameOut[100]; // Duas variáveis para guardar os nomes de saida e entrada
    argv++;
    if (argc < 2) {
        puts("\n Compilador Simples");
        puts("\n\tUso: ./simples <NOME>[.simples]\n\n");
        exit(10);
    }
    p = strstr(argv[0], ".simples"); // Função que procura uma string na string e posiciona no início
    if (p) *p = 0;
    strcpy(nameIn, argv[0]);
    strcat(nameIn, ".simples");
    strcpy(nameOut, argv[0]);
    strcat(nameOut, ".mvs");
    yyin = fopen (nameIn, "rt");
    if (!yyin) {
        puts("Programa fonte não encontrado!");
        exit(20);
    }
    yyout = fopen(nameOut, "wt");
    yyparse();
    puts ("Programa ok!");
    /* mostraTabela(); */
}