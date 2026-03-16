//Bibliotecas
#Include "Totvs.ch"
#Include "RESTFul.ch"
#Include "TopConn.ch"

/*/{Protheus.doc} WSRESTFUL zWsCliente
WebService completo de Cadastro de Clientes com opção de páginação 
@author Bruno Domingos
@since 13/12/2025
@version 2.1
@type wsrestful
/*/

WSRESTFUL zWsCliente DESCRIPTION 'WebService de Cadastro de Clientes'
    //Atributos
    WSDATA id         AS STRING
    WSDATA updated_at AS STRING
    WSDATA limit      AS INTEGER
    WSDATA page       AS INTEGER
 
    //Métodos
    WSMETHOD GET    ID     DESCRIPTION 'Retorna o registro pesquisado' WSSYNTAX '/zWsCliente/get_id?{id}'                       PATH 'get_id'        PRODUCES APPLICATION_JSON
    WSMETHOD GET    ALL    DESCRIPTION 'Retorna todos os registros'    WSSYNTAX '/zWsCliente/get_all?{updated_at, limit, page}' PATH 'get_all'       PRODUCES APPLICATION_JSON
    WSMETHOD POST   NEW    DESCRIPTION 'Inclusão de registro'          WSSYNTAX '/zWsCliente/new'                               PATH 'new'           PRODUCES APPLICATION_JSON
    WSMETHOD PUT    UPDATE DESCRIPTION 'Atualização de registro'       WSSYNTAX '/zWsCliente/update'                            PATH 'update'        PRODUCES APPLICATION_JSON
    WSMETHOD DELETE ERASE  DESCRIPTION 'Exclusão de registro'          WSSYNTAX '/zWsCliente/erase'                             PATH 'erase'         PRODUCES APPLICATION_JSON
END WSRESTFUL

/*/{Protheus.doc} WSMETHOD GET ID
Busca registro via ID
/*/
WSMETHOD GET ID WSRECEIVE id WSSERVICE zWsCliente
    Local lRet       := .T.
    Local jResponse  := JsonObject():New()
    Local cAliasWS   := 'SA1'

    If Empty(::id)
        Self:setStatus(500) 
        jResponse['errorId']  := 'ID001'
        jResponse['error']    := 'ID vazio'
        jResponse['solution'] := 'Informe o ID'
    Else
        DbSelectArea(cAliasWS)
        (cAliasWS)->(DbSetOrder(1))
        If ! (cAliasWS)->(MsSeek(FWxFilial(cAliasWS) + ::id))
            Self:setStatus(500) 
            jResponse['errorId']  := 'ID002'
            jResponse['error']    := 'ID não encontrado'
            jResponse['solution'] := 'Código ID não encontrado na tabela ' + cAliasWS
        Else
            jResponse['cod']           := Alltrim((cAliasWS)->A1_COD )
            jResponse['loja']          := Alltrim((cAliasWS)->A1_LOJA )
            jResponse['nome']          := Alltrim((cAliasWS)->A1_NOME )
            jResponse['nome_reduzido'] := Alltrim((cAliasWS)->A1_NREDUZ )
            jResponse['tipo']          := Alltrim((cAliasWS)->A1_TIPO )
            jResponse['cgc']           := Alltrim((cAliasWS)->A1_CGC )
            jResponse['end']           := Alltrim((cAliasWS)->A1_END )
            jResponse['bairro']        := Alltrim((cAliasWS)->A1_BAIRRO )
            jResponse['mun']           := Alltrim((cAliasWS)->A1_MUN )
            jResponse['est']           := Alltrim((cAliasWS)->A1_EST )
            jResponse['ddd']           := Alltrim((cAliasWS)->A1_DDD )
            jResponse['tel']           := Alltrim((cAliasWS)->A1_TEL )
        EndIf
    EndIf

    Self:SetContentType('application/json')
    Self:SetResponse(EncodeUTF8(jResponse:toJSON()))
Return lRet

/*/{Protheus.doc} WSMETHOD GET ALL
Busca todos os registros através de paginação
/*/
WSMETHOD GET ALL WSRECEIVE updated_at, limit, page WSSERVICE zWsCliente
    Local lRet       := .T.
    Local jResponse  := JsonObject():New()
    Local cQueryTab  := ''
    Local nTamanho   := 10
    Local nTotal     := 0
    Local nPags      := 0
    Local nPagina    := 0
    Local nAtual     := 0
    Local oRegistro
    Local cAliasWS   := 'SA1'

    cQueryTab := " SELECT TAB.R_E_C_N_O_ AS TABREC FROM " + RetSQLName(cAliasWS) + " TAB WHERE TAB.D_E_L_E_T_ = '' "
    If ! Empty(::updated_at)
        cQueryTab += " AND ((CASE WHEN SUBSTRING(A1_USERLGA, 03, 1) != ' ' THEN " + CRLF
        cQueryTab += " CONVERT(VARCHAR,DATEADD(DAY,((ASCII(SUBSTRING(A1_USERLGA,12,1)) - 50) * 100 + (ASCII(SUBSTRING(A1_USERLGA,16,1)) - 50)),'19960101'),112) ELSE '' END) >= '" + StrTran(::updated_at, '-', '') + "') "
    EndIf
    cQueryTab += " ORDER BY TABREC"
    TCQuery cQueryTab New Alias 'QRY_TAB'

    If QRY_TAB->(EoF())
        Self:setStatus(500)
        jResponse['errorId']  := 'ALL003'
        jResponse['error']    := 'Registro(s) não encontrado(s)'
        jResponse['solution'] := 'A consulta de registros não retornou nenhuma informação'
    Else
        jResponse['objects'] := {}
        Count To nTotal
        QRY_TAB->(DbGoTop())

        If ! Empty(::limit)
            nTamanho := ::limit
        EndIf

        nPags := NoRound(nTotal / nTamanho, 0)
        nPags += Iif(nTotal % nTamanho != 0, 1, 0)

        If ! Empty(::page)
            nPagina := ::page
        EndIf

        If nPagina <= 0 .Or. nPagina > nPags
            nPagina := 1
        EndIf

        If nPagina != 1
            QRY_TAB->(DbSkip((nPagina-1) * nTamanho))
        EndIf

        jJsonMeta := JsonObject():New()
        jJsonMeta['total']         := nTotal
        jJsonMeta['current_page']  := nPagina
        jJsonMeta['total_page']    := nPags
        jJsonMeta['total_items']   := nTamanho
        jResponse['meta'] := jJsonMeta

        While ! QRY_TAB->(EoF())
            nAtual++
            If nAtual > nTamanho
                Exit
            EndIf

            DbSelectArea(cAliasWS)
            (cAliasWS)->(DbGoTo(QRY_TAB->TABREC))

            oRegistro := JsonObject():New()
            oRegistro['cod']           := AllTrim((cAliasWS)->A1_COD )
            oRegistro['loja']          := AllTrim((cAliasWS)->A1_LOJA)
            oRegistro['nome']          := AllTrim((cAliasWS)->A1_NOME)
            oRegistro['nome_reduzido'] := AllTrim((cAliasWS)->A1_NREDUZ)
            oRegistro['tipo']          := AllTrim((cAliasWS)->A1_TIPO)
            oRegistro['cgc']           := AllTrim((cAliasWS)->A1_CGC )
            oRegistro['end']           := AllTrim((cAliasWS)->A1_END )
            oRegistro['bairro']        := AllTrim((cAliasWS)->A1_BAIRRO)
            oRegistro['mun']           := AllTrim((cAliasWS)->A1_MUN )
            oRegistro['est']           := AllTrim((cAliasWS)->A1_EST )
            oRegistro['ddd']           := AllTrim((cAliasWS)->A1_DDD )
            oRegistro['tel']           := AllTrim((cAliasWS)->A1_TEL )
            aAdd(jResponse['objects'], oRegistro)

            QRY_TAB->(DbSkip())
        EndDo
    EndIf
    QRY_TAB->(DbCloseArea())

    Self:SetContentType('application/json')
    Self:SetResponse(EncodeUTF8(jResponse:toJSON()))
Return lRet

/*/{Protheus.doc} WSMETHOD POST NEW
Inclusão de registro (JSON inclui nome_reduzido)
/*/
WSMETHOD POST NEW WSRECEIVE WSSERVICE zWsCliente
    Local lRet      := .T.
    Local aDados    := {}
    Local jJson     := Nil
    Local cJson     := Self:GetContent()
    Local jResponse := JsonObject():New()
    Local cAliasWS  := 'SA1'
    Private lMsErroAuto := .F.

    Self:SetContentType('application/json')
    jJson  := JsonObject():New()
    If ! Empty(jJson:FromJson(cJson))
        Self:setStatus(500)
        jResponse['errorId']  := 'NEW004'
        jResponse['error']    := 'Parse do JSON'
        jResponse['solution'] := 'Erro ao fazer o Parse do JSON'
    Else
        DbSelectArea(cAliasWS)

        aAdd(aDados, {'A1_COD',          jJson:GetJsonObject('cod'),          Nil})
        aAdd(aDados, {'A1_LOJA',         jJson:GetJsonObject('loja'),         Nil})
        aAdd(aDados, {'A1_NOME',         jJson:GetJsonObject('nome'),         Nil})
        aAdd(aDados, {'A1_NREDUZ',         jJson:GetJsonObject('nome_reduzido'),Nil})
        aAdd(aDados, {'A1_TIPO',         jJson:GetJsonObject('tipo'),         Nil})
        aAdd(aDados, {'A1_CGC',          jJson:GetJsonObject('cgc'),          Nil})
        aAdd(aDados, {'A1_END',          jJson:GetJsonObject('end'),          Nil})
        aAdd(aDados, {'A1_BAIRRO',       jJson:GetJsonObject('bairro'),       Nil})
        aAdd(aDados, {'A1_MUN',          jJson:GetJsonObject('mun'),          Nil})
        aAdd(aDados, {'A1_EST',          jJson:GetJsonObject('est'),          Nil})
        aAdd(aDados, {'A1_DDD',          jJson:GetJsonObject('ddd'),          Nil})
        aAdd(aDados, {'A1_TEL',          jJson:GetJsonObject('tel'),          Nil})

        For nCampo := 1 To Len(aDados)
            If GetSX3Cache(aDados[nCampo][1], 'X3_TIPO') == 'D'
                aDados[nCampo][2] := StrTran(aDados[nCampo][2], '-', '')
                aDados[nCampo][2] := sToD(aDados[nCampo][2])
            EndIf
        Next

        MsExecAuto({|x,y| CRMA980(x,y)}, aDados, 3)
        If lMsErroAuto
            jResponse['errorId']  := 'NEW005'
            jResponse['error']    := 'Erro na inclusão'
            jResponse['solution'] := 'Verifique logs'
            lRet := .F.
        Else
            jResponse['note'] := 'Registro incluido com sucesso'
        EndIf
    EndIf

    Self:SetResponse(EncodeUTF8(jResponse:toJSON()))
Return lRet

/*/{Protheus.doc} WSMETHOD PUT UPDATE
Atualização de registro (JSON inclui nome_reduzido)
/*/
WSMETHOD PUT UPDATE WSRECEIVE id WSSERVICE zWsCliente
    Local lRet      := .T.
    Local aDados    := {}
    Local jJson     := Nil
    Local cJson     := Self:GetContent()
    Local jResponse := JsonObject():New()
    Local cAliasWS  := 'SA1'
    Private lMsErroAuto := .F.

    If Empty(::id)
        Self:setStatus(500)
        jResponse['errorId']  := 'UPD006'
        jResponse['error']    := 'ID vazio'
        jResponse['solution'] := 'Informe o ID'
    Else
        DbSelectArea(cAliasWS)
        (cAliasWS)->(DbSetOrder(1))
        If ! (cAliasWS)->(MsSeek(FWxFilial(cAliasWS) + ::id))
            Self:setStatus(500)
            jResponse['errorId']  := 'UPD007'
            jResponse['error']    := 'ID não encontrado'
            jResponse['solution'] := 'Código ID não encontrado na tabela ' + cAliasWS
        Else
            jJson := JsonObject():New()
            jJson:FromJson(cJson)

            aAdd(aDados, {'A1_COD',          jJson:GetJsonObject('cod'),          Nil})
            aAdd(aDados, {'A1_LOJA',         jJson:GetJsonObject('loja'),         Nil})
            aAdd(aDados, {'A1_NOME',         jJson:GetJsonObject('nome'),         Nil})
            aAdd(aDados, {'A1_NREDUZ',         jJson:GetJsonObject('nome_reduzido'),Nil})
            aAdd(aDados, {'A1_TIPO',         jJson:GetJsonObject('tipo'),         Nil})
            aAdd(aDados, {'A1_CGC',          jJson:GetJsonObject('cgc'),          Nil})
            aAdd(aDados, {'A1_END',          jJson:GetJsonObject('end'),          Nil})
            aAdd(aDados, {'A1_BAIRRO',       jJson:GetJsonObject('bairro'),       Nil})
            aAdd(aDados, {'A1_MUN',          jJson:GetJsonObject('mun'),          Nil})
            aAdd(aDados, {'A1_EST',          jJson:GetJsonObject('est'),          Nil})
            aAdd(aDados, {'A1_DDD',          jJson:GetJsonObject('ddd'),          Nil})
            aAdd(aDados, {'A1_TEL',          jJson:GetJsonObject('tel'),          Nil})

            For nCampo := 1 To Len(aDados)
                If GetSX3Cache(aDados[nCampo][1], 'X3_TIPO') == 'D'
                    aDados[nCampo][2] := StrTran(aDados[nCampo][2], '-', '')
                    aDados[nCampo][2] := sToD(aDados[nCampo][2])
                EndIf
            Next

            MsExecAuto({|x,y| CRMA980(x,y)}, aDados, 4)
            If lMsErroAuto
                jResponse['errorId']  := 'UPD009'
                jResponse['error']    := 'Erro na atualização'
                jResponse['solution'] := 'Verifique logs'
                lRet := .F.
            Else
                jResponse['note'] := 'Registro atualizado com sucesso'
            EndIf
        EndIf
    EndIf

    Self:SetResponse(EncodeUTF8(jResponse:toJSON()))
Return lRet

/*/{Protheus.doc} WSMETHOD DELETE ERASE
Exclusão de registro (JSON inclui nome_reduzido)
/*/
WSMETHOD DELETE ERASE WSRECEIVE id WSSERVICE zWsCliente
    Local lRet      := .T.
    Local aDados    := {}
    Local jJson     := Nil
    Local cJson     := Self:GetContent()
    Local jResponse := JsonObject():New()
    Local cAliasWS  := 'SA1'
    Private lMsErroAuto := .F.

    If Empty(::id)
        Self:setStatus(500)
        jResponse['errorId']  := 'DEL010'
        jResponse['error']    := 'ID vazio'
        jResponse['solution'] := 'Informe o ID'
    Else
        DbSelectArea(cAliasWS)
        (cAliasWS)->(DbSetOrder(1))
        If ! (cAliasWS)->(MsSeek(FWxFilial(cAliasWS) + ::id))
            Self:setStatus(500)
            jResponse['errorId']  := 'DEL011'
            jResponse['error']    := 'ID não encontrado'
            jResponse['solution'] := 'Código ID não encontrado na tabela ' + cAliasWS
        Else
            jJson := JsonObject():New()
            jJson:FromJson(cJson)

            aAdd(aDados, {'A1_COD',          jJson:GetJsonObject('cod'),          Nil})
            aAdd(aDados, {'A1_LOJA',         jJson:GetJsonObject('loja'),         Nil})
            aAdd(aDados, {'A1_NOME',         jJson:GetJsonObject('nome'),         Nil})
            aAdd(aDados, {'A1_NREDUZ',         jJson:GetJsonObject('nome_reduzido'),Nil})
            aAdd(aDados, {'A1_TIPO',         jJson:GetJsonObject('tipo'),         Nil})
            aAdd(aDados, {'A1_CGC',          jJson:GetJsonObject('cgc'),          Nil})
            aAdd(aDados, {'A1_END',          jJson:GetJsonObject('end'),          Nil})
            aAdd(aDados, {'A1_BAIRRO',       jJson:GetJsonObject('bairro'),       Nil})
            aAdd(aDados, {'A1_MUN',          jJson:GetJsonObject('mun'),          Nil})
            aAdd(aDados, {'A1_EST',          jJson:GetJsonObject('est'),          Nil})
            aAdd(aDados, {'A1_DDD',          jJson:GetJsonObject('ddd'),          Nil})
            aAdd(aDados, {'A1_TEL',          jJson:GetJsonObject('tel'),          Nil})

            For nCampo := 1 To Len(aDados)
                If GetSX3Cache(aDados[nCampo][1], 'X3_TIPO') == 'D'
                    aDados[nCampo][2] := StrTran(aDados[nCampo][2], '-', '')
                    aDados[nCampo][2] := sToD(aDados[nCampo][2])
                EndIf
            Next

            MsExecAuto({|x,y| CRMA980(x,y)}, aDados, 5)
            If lMsErroAuto
                jResponse['errorId']  := 'DEL013'
                jResponse['error']    := 'Erro na exclusão'
                jResponse['solution'] := 'Verifique logs'
                lRet := .F.
            Else
                jResponse['note'] := 'Registro excluído com sucesso'
            EndIf
        EndIf
    EndIf

    Self:SetResponse(EncodeUTF8(jResponse:toJSON()))
Return lRet
