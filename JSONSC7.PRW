#Include "TOTVS.ch"
#Include "Prtopdef.ch"
#Include "TopConn.ch"
#Include "PROTHEUS.ch"

//===================================================================
/*/{Protheus.doc} JSONSC7
Processa JSON de rateio e RECRIA os registros nas tabelas SCH e SDE.
Deleta os rateios existentes e insere novos baseados no JSON.
Busca a conta contabil oficial no Cadastro de Produtos (SB1).
Valida 100% POR ITEM.
Autor: Bruno Domingos 
/*/
//===================================================================

User Function JSONSC7()

    // Declaracao de Variaveis
    Local cPathBase  := "\rateios_json\"
    Local cPathProc  := cPathBase + "processados\"
    Local cPathErro  := cPathBase + "erro\"
    Local aFiles     := Directory(cPathBase + "*.json")
    Local cFile      := ""
    Local cJson      := ""
    Local oJson      := Nil
    Local lErro      := .F.
    Local cLogMsg    := ""
    
    // Variaveis de controle numerico
    Local nI         := 0
    Local nJ         := 0
    Local nK         := 0
    Local nUltPos    := 0
    Local nPerc      := 0
    Local nPercTot   := 0
    Local nSeq       := 0
    
    // Valores SCH e SDE
    Local nValor     := 0
    Local nTotal     := 0
    Local nValAcum   := 0
    Local nValorSDE  := 0
    Local nTotalSDE  := 0
    Local nValAcumSDE:= 0
    
    // Variaveis de dados do JSON/DB
    Local oCab       := Nil
    Local aItens     := Nil
    Local aRateio    := Nil
    Local cFil       := "" 
    Local cPedido    := ""
    Local cItem      := ""
    Local cCC        := ""
    Local cConta     := ""
    Local cItemCta   := ""
    Local cSeq       := ""
    Local aItensTot  := {}
    Local cProduto   := ""
    Local cContaCont := ""
    
    // Controle da Query da SDE
    Local cQuery     := ""
    Local cAliasSD1  := GetNextAlias()

    If Len(aFiles) == 0
        MsgInfo("Nenhum arquivo encontrado em: " + cPathBase, "JSONSC7")
        Return
    EndIf

    If !ExistDir(cPathProc)
        MakeDir(cPathProc)
    EndIf

    If !ExistDir(cPathErro)
        MakeDir(cPathErro)
    EndIf

    For nI := 1 To Len(aFiles)

        cFile   := aFiles[nI][1]
        lErro   := .F.
        cLogMsg := ""

      //  MsgInfo("Processando arquivo: " + cFile, "JSONSC7")

        cJson := MemoRead(cPathBase + cFile)
        oJson := JsonObject():New()
        
        // Valida estrutura inicial do JSON
        If ValType(oJson:FromJson(cJson)) != "U" 
            cLogMsg := "Falha na leitura ou formato do JSON."
            lErro := .T.
        EndIf

        If !lErro
            oCab    := oJson:GetJsonObject("cabecalho")
            aItens  := oJson:GetJsonObject("itens")
            aRateio := oJson:GetJsonObject("rateio")

            cFil    := oCab:GetJsonText("C7_FILENT")
            cPedido := oCab:GetJsonText("C7_NUM")

            // 1. Busca na SC7
            DbSelectArea("SC7")
            SC7->(DbSetOrder(1)) 
            If !SC7->(DbSeek(cFil + cPedido, .T.)) .Or. SC7->C7_FILIAL != cFil .Or. SC7->C7_NUM != cPedido
                cLogMsg := "Pedido nao existe ou filial divergente: " + cFil + " - " + cPedido
                lErro := .T.
            EndIf
        EndIf

        If !lErro
            // Guarda os totais de cada item
            aItensTot := {}
            For nJ := 1 To Len(aItens)
                AAdd(aItensTot, { aItens[nJ]:GetJsonText("C7_ITEM"), Val(aItens[nJ]:GetJsonText("C7_TOTAL")) })
            Next nJ

            // =========================================
            // Valida se a soma do JSON da 100% POR ITEM
            // =========================================
            For nK := 1 To Len(aItensTot)
                cItem := aItensTot[nK][1]
                nPercTot := 0

                For nJ := 1 To Len(aRateio)
                    If aRateio[nJ]:GetJsonText("CH_ITEMPD") == cItem
                        nPercTot += Val(aRateio[nJ]:GetJsonText("CH_PERC"))
                    EndIf
                Next nJ

                If Round(nPercTot, 2) <> 100
                    cLogMsg := "Percentual invalido no Item " + cItem + ". Total do rateio: " + cValToChar(nPercTot) + "%"
                    lErro := .T.
                    Exit // Sai do laco nK pois ja encontrou erro
                EndIf
            Next nK
        EndIf

        // =========================================
        // 2. EXCLUSAO E INCLUSAO NO BANCO (SCH e SDE)
        // =========================================
        If !lErro
            Begin Transaction
                
                // Itera sobre cada Item do Pedido
                For nK := 1 To Len(aItensTot)
                    cItem    := aItensTot[nK][1] // Este eh o item do pedido
                    nTotal   := aItensTot[nK][2]
                    nSeq     := 1
                    nValAcum := 0
                    cProduto   := ""
                    cContaCont := ""
                    
                    // Busca Produto e a Conta Contabil no SB1
                    DbSelectArea("SC7")
                    SC7->(DbSetOrder(1)) // C7_FILIAL + C7_NUM + C7_ITEM
                    If SC7->(DbSeek(cFil + cPedido + cItem))
                        cProduto := SC7->C7_PRODUTO
                    EndIf
                    
                    If !Empty(cProduto)
                        DbSelectArea("SB1")
                        SB1->(DbSetOrder(1)) // B1_FILIAL + B1_COD
                        If SB1->(DbSeek(xFilial("SB1") + cProduto))
                            cContaCont := SB1->B1_CONTA
                        EndIf
                    EndIf
                    
                    // Descobre a ultima posicao desse Item no JSON (para os centavos)
                    nUltPos := 0
                    For nJ := 1 To Len(aRateio)
                        If aRateio[nJ]:GetJsonText("CH_ITEMPD") == cItem
                            nUltPos := nJ
                        EndIf
                    Next nJ

                    // -------------------------------------
                    // A. RECRIA A TABELA SCH (Pedido)
                    // -------------------------------------
                    DbSelectArea("SCH")
                    SCH->(DbSetOrder(2)) // CH_FILIAL + CH_PEDIDO + CH_ITEMPD + CH_ITEM

                    // Exclui os rateios existentes
                    If SCH->(DbSeek(cFil + cPedido + cItem))
                        While !SCH->(Eof()) .And. SCH->CH_FILIAL == cFil .And. SCH->CH_PEDIDO == cPedido .And. SCH->CH_ITEMPD == cItem
                            RecLock("SCH", .F.) 
                            SCH->(DbDelete())
                            MsUnlock()
                            SCH->(DbSkip())
                        EndDo
                    EndIf

                    // Insere os novos rateios
                    For nJ := 1 To Len(aRateio)
                        If aRateio[nJ]:GetJsonText("CH_ITEMPD") == cItem
                            cCC      := aRateio[nJ]:GetJsonText("CH_CC")
                            // Prioriza a conta do SB1, senao faz fallback pro JSON (assumindo que no JSON vinha a conta no campo CH_ITEMCTA no seu layout antigo)
                            cConta   := Iif(!Empty(cContaCont), cContaCont, aRateio[nJ]:GetJsonText("CH_ITEMCTA"))
                            cItemCta := aRateio[nJ]:GetJsonText("CH_ITEMCTA") // Mantem o Item da Conta se for o caso
                            nPerc    := Val(aRateio[nJ]:GetJsonText("CH_PERC"))
                            
                            cSeq     := StrZero(nSeq, 2)

                            If nJ == nUltPos
                                nValor := Round(nTotal - nValAcum, 2)
                            Else
                                nValor := Round(nTotal * (nPerc / 100), 2)
                                nValAcum += nValor
                            EndIf

                            RecLock("SCH", .T.) 
                            SCH->CH_FILIAL  := cFil
                            SCH->CH_PEDIDO  := cPedido
                            SCH->CH_FORNECE := SC7->C7_FORNECE
                            SCH->CH_LOJA    := SC7->C7_LOJA
                            SCH->CH_ITEMPD  := cItem     // Item do Pedido
                            SCH->CH_ITEM    := cSeq      // Sequencial do Rateio (01, 02...)
                            SCH->CH_PERC    := nPerc
                            SCH->CH_CONTA   := cConta    // Conta Contabil Correta
                            SCH->CH_ITEMCTA := cItemCta  // Item da Conta
                            SCH->CH_CC      := cCC
                            SCH->CH_CUSTO1  := nValor
                            MsUnlock()

                            nSeq++
                        EndIf
                    Next nJ

                    // -------------------------------------
                    // B. RECRIA A TABELA SDE (Notas Fiscais)
                    // -------------------------------------
                    
                    // Como a ordem que busca pedido x item na SD1 (Ordem M) nem sempre esta disponivel ou configurada igual em todas as bases,
                    // uma Query SQL nativa (TCQUERY) eh mais estavel para encontrar quais as NFs vinculadas aquele C7_NUM / C7_ITEM
                    cQuery := "SELECT D1_FILIAL, D1_DOC, D1_SERIE, D1_FORNECE, D1_LOJA, D1_ITEM "
                    cQuery += "  FROM " + RetSqlName("SD1") + " SD1 "
                    cQuery += " WHERE SD1.D1_FILIAL = '" + cFil + "' "
                    cQuery += "   AND SD1.D1_PEDIDO = '" + cPedido + "' "
                    cQuery += "   AND SD1.D1_ITEMPC = '" + cItem + "' "
                    cQuery += "   AND SD1.D_E_L_E_T_ = ' ' "
                    
                    If Select(cAliasSD1) > 0
                        (cAliasSD1)->(DbCloseArea())
                    EndIf
                    
                    TcQuery cQuery New Alias (cAliasSD1)
                    
                    While !(cAliasSD1)->(Eof())
                        
                        nTotalSDE := 0
                        
                        DbSelectArea("SDE")
                        SDE->(DbSetOrder(1)) // DE_FILIAL+DE_DOC+DE_SERIE+DE_FORNECE+DE_LOJA+DE_ITEMNF+DE_ITEM
                        
                        // PASSO 1: Soma os valores originais da SDE para saber o total base exato da NF (Custo1)
                        // A busca para somar o total eh feita pelo D1_ITEM (Item da NF) amarrado no DE_ITEMNF
                        If SDE->(DbSeek((cAliasSD1)->D1_FILIAL + (cAliasSD1)->D1_DOC + (cAliasSD1)->D1_SERIE + (cAliasSD1)->D1_FORNECE + (cAliasSD1)->D1_LOJA + (cAliasSD1)->D1_ITEM))
                            While !SDE->(Eof()) .And. SDE->DE_FILIAL == (cAliasSD1)->D1_FILIAL .And. SDE->DE_DOC == (cAliasSD1)->D1_DOC .And. SDE->DE_SERIE == (cAliasSD1)->D1_SERIE .And. SDE->DE_FORNECE == (cAliasSD1)->D1_FORNECE .And. SDE->DE_LOJA == (cAliasSD1)->D1_LOJA .And. SDE->DE_ITEMNF == (cAliasSD1)->D1_ITEM
                                nTotalSDE += SDE->DE_CUSTO1
                                SDE->(DbSkip())
                            EndDo
                        EndIf

                        // PASSO 2: Exclui os rateios existentes vinculados aquela chave de nota fiscal
                        If SDE->(DbSeek((cAliasSD1)->D1_FILIAL + (cAliasSD1)->D1_DOC + (cAliasSD1)->D1_SERIE + (cAliasSD1)->D1_FORNECE + (cAliasSD1)->D1_LOJA + (cAliasSD1)->D1_ITEM))
                            While !SDE->(Eof()) .And. SDE->DE_FILIAL == (cAliasSD1)->D1_FILIAL .And. SDE->DE_DOC == (cAliasSD1)->D1_DOC .And. SDE->DE_SERIE == (cAliasSD1)->D1_SERIE .And. SDE->DE_FORNECE == (cAliasSD1)->D1_FORNECE .And. SDE->DE_LOJA == (cAliasSD1)->D1_LOJA .And. SDE->DE_ITEMNF == (cAliasSD1)->D1_ITEM
                                RecLock("SDE", .F.)
                                SDE->(DbDelete())
                                MsUnlock()
                                SDE->(DbSkip())
                            EndDo
                        EndIf

                        // PASSO 3: Insere o novo rateio na SDE baseado no JSON
                        nSeq := 1
                        nValAcumSDE := 0

                        For nJ := 1 To Len(aRateio)
                            If aRateio[nJ]:GetJsonText("CH_ITEMPD") == cItem
                                cCC      := aRateio[nJ]:GetJsonText("CH_CC")
                                cConta   := Iif(!Empty(cContaCont), cContaCont, aRateio[nJ]:GetJsonText("CH_ITEMCTA"))
                                cItemCta := aRateio[nJ]:GetJsonText("CH_ITEMCTA")
                                nPerc    := Val(aRateio[nJ]:GetJsonText("CH_PERC"))
                                
                                cSeq     := StrZero(nSeq, 2)

                                If nJ == nUltPos
                                    nValorSDE := Round(nTotalSDE - nValAcumSDE, 2)
                                Else
                                    nValorSDE := Round(nTotalSDE * (nPerc / 100), 2)
                                    nValAcumSDE += nValorSDE
                                EndIf

                                RecLock("SDE", .T.) 
                                SDE->DE_FILIAL  := (cAliasSD1)->D1_FILIAL
                                SDE->DE_DOC     := (cAliasSD1)->D1_DOC
                                SDE->DE_SERIE   := (cAliasSD1)->D1_SERIE
                                SDE->DE_FORNECE := (cAliasSD1)->D1_FORNECE
                                SDE->DE_LOJA    := (cAliasSD1)->D1_LOJA
                                SDE->DE_ITEMNF  := (cAliasSD1)->D1_ITEM  // Item da NF
                                SDE->DE_ITEM    := cSeq                  // Sequencial do Rateio (01, 02...)
                                SDE->DE_PERC    := nPerc
                                SDE->DE_CONTA   := cConta                // Conta Contabil
                                SDE->DE_ITEMCTA := cItemCta              // Item da Conta
                                SDE->DE_CC      := cCC
                                SDE->DE_CUSTO1  := nValorSDE
                                MsUnlock()

                                nSeq++
                            EndIf
                        Next nJ

                        (cAliasSD1)->(DbSkip())
                    EndDo
                    
                    (cAliasSD1)->(DbCloseArea())

                Next nK

            End Transaction

        Else
            // Desarma a transacao caso a variavel de erro tenha sido ativada durante alguma fase do processamento
            If InTransaction()
                DisarmTransaction()
            EndIf
        EndIf

        // Limpa objeto JSON da memoria
        If oJson != Nil
            FreeObj(oJson)
        EndIf

        //=========================================
        // Movimentacao de Arquivos e Logs
        //=========================================
        If lErro
            MsgInfo("ERRO ao processar " + cFile + ":" + CRLF + cLogMsg, "JSONSC7")
            __CopyFile(cPathBase + cFile, cPathErro + cFile)
        Else
           // MsgInfo("SUCESSO. Arquivo processado: " + cFile, "JSONSC7")
            __CopyFile(cPathBase + cFile, cPathProc + cFile)
        EndIf

        FErase(cPathBase + cFile)

    Next nI

    //MsgInfo("Processamento em lote finalizado.", "JSONSC7")

Return
