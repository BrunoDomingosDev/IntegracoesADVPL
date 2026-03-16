//Bibliotecas
#Include "tlpp-core.th"
#Include "protheus.ch"
#Include "fwmvcdef.ch"

Namespace custom.api.consume

/*/{Protheus.doc} CAPI001
Consumir API e gravar Lançamento Contábil via ExecAuto
@author Bruno Domingos
@since 04/03/2026
@version 2.0
/*/
User Function CAPI001()
    Local aArea         := FWGetArea()
    Local oRestClient   := FWRest():New('https://site.com.br/ws') //Mude aqui
    Local aHeader       := {}
    Local cResult       := ""
    Local oJson         := JsonObject():New()
    
    // Variáveis do ExecAuto (CTBA102)
    Local aCab          := {}
    Local aItens        := {}
    Local aLinha        := {}
    Local nI            := 1
    Local aJsonItens    := {}
    Private lMsErroAuto := .F. // Variável obrigatória para controle de erro do ExecAuto

    // 1. CHAMA A API E TRAZ O JSON (Usando GET ou POST, dependendo da sua API)
    aAdd(aHeader, 'User-Agent: Mozilla/4.0 (compatible; Protheus 12.1.x)')
    aAdd(aHeader, 'Accept: application/json; charset=utf-8')
    
    oRestClient:setPath('/teste/envioABC') //mude aqui para o endpoint correto da sua API
    
    // Se a sua API exige enviar algo para devolver os LPs, mantenha o :Post(). 
    // Se for só buscar, mude para :Get()
    If oRestClient:Get(aHeader) 
        cResult := oRestClient:GetResult()
        
        // 2. DESEMPACOTA O JSON PARA OBJETO ADVPL
        oJson:FromJson(cResult)
        
        // 3. MONTA O CABEÇALHO DO EXECAUTO (aCab)
        // Convertendo a data "2026-03-16" para data do Protheus (CToD ou DtoS)
        aAdd(aCab, {"CT2_DATA" , sToD(StrTran(oJson['dataLancamento'], "-", "")), Nil})
        aAdd(aCab, {"CT2_LOTE" , "API001" , Nil}) // Defina um lote padrão ou dinâmico
        aAdd(aCab, {"CT2_SBLOTE", "01"    , Nil})
        aAdd(aCab, {"CT2_DOC"  , "000001" , Nil}) 
        
        // 4. MONTA OS ITENS DO EXECAUTO (aItens)
        aJsonItens := oJson['lancamentos'] // Pega o array de lançamentos do JSON
        
        For nI := 1 To Len(aJsonItens)
            aLinha := {}
            
            // Cada linha do array aItens é um array com os campos da CT2
            aAdd(aLinha, {"CT2_LINHA" , aJsonItens[nI]['linha']       , Nil})
            aAdd(aLinha, {"CT2_DEBITO", aJsonItens[nI]['contaDebito'] , Nil})
            aAdd(aLinha, {"CT2_CREDIT", aJsonItens[nI]['contaCredito'], Nil})
            aAdd(aLinha, {"CT2_VALOR" , aJsonItens[nI]['valor']       , Nil})
            aAdd(aLinha, {"CT2_CCD"   , aJsonItens[nI]['ccDebito']    , Nil})
            aAdd(aLinha, {"CT2_CCC"   , aJsonItens[nI]['ccCredito']   , Nil})
            aAdd(aLinha, {"CT2_HIST"  , aJsonItens[nI]['historico']   , Nil})
            
            aAdd(aItens, aLinha)
        Next nI
        
        // 5. CHAMA O EXECAUTO DA CTBA102 (3 = Inclusão)
        ConOut("Iniciando gravacao CTBA102 via ExecAuto...")
        MSExecAuto({|x,y,z| CTBA102(x,y,z)}, aCab, aItens, 3)
        
        If lMsErroAuto
            MsgInfo("Erro ao gravar Lancamento Contabil via ExecAuto!")
            MostraErro() // Exibe a tela/log padrão de erro do Protheus
        Else
            MsgInfo("Lancamento contabil gravado com sucesso no Protheus!")
        EndIf
        
    Else
        MsgInfo('Falha ao consumir a API: ' + oRestClient:GetLastError())
    EndIf
    
    FreeObj(oJson)
    FWRestArea(aArea)
Return Nil
